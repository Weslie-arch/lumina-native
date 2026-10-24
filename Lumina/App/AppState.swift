import Foundation
import SwiftUI
import ActivityKit

/// Activity 不是 Sendable，直接跨 actor 传会触发 Swift 6 的 data race 检查。
/// 用一个盒子把它关起来，主 App 只跟盒子打交道。
final class ActivityBox: @unchecked Sendable {
    private var activity: Activity<LuminaAttributes>?

    func start() {
        guard activity == nil else { return }
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        let st = LuminaAttributes.ContentState(status: "待命", detail: "打开 Lumina 看消息",
                                               unread: 0, pending: 0, updatedAt: Date())
        activity = try? Activity<LuminaAttributes>.request(
            attributes: LuminaAttributes(),
            content: ActivityContent(state: st, staleDate: nil),
            pushType: nil)
    }

    func update(_ st: LuminaAttributes.ContentState) async {
        await activity?.update(ActivityContent(state: st, staleDate: Date().addingTimeInterval(900)))
    }

    func stop() async {
        await activity?.end(nil, dismissalPolicy: .immediate)
        activity = nil
    }
}

@MainActor
final class AppState: ObservableObject {

    @Published var signedIn = false
    @Published var booting = true
    @Published var email = ""
    @Published var conversations: [Conversation] = []
    @Published var messages: [ChatMessage] = []
    @Published var device: Device?
    @Published var bindCode = "------"
    @Published var profile = Profile()
    @Published var commands: [Command] = []
    @Published var banner: String?
    @Published var working = false
    @Published var liveActivityOn: Bool {
        didSet { UserDefaults.standard.set(liveActivityOn, forKey: "lumina_live") }
    }

    private var session: CloudSession?
    private let box = ActivityBox()
    private var poll: Timer?
    /// 上次发验证码时，服务端回的「是不是老用户」——
    /// 校验时不能再发一次（一分钟只能发一条，会触发限流）
    private var otpIsUser = false

    init() {
        liveActivityOn = UserDefaults.standard.object(forKey: "lumina_live") as? Bool ?? true
    }

    // MARK: - 凭据（Keychain）

    private func persist(_ s: CloudSession) {
        Keychain.save(s.accessToken, account: "access_token")
        Keychain.save(s.refreshToken, account: "refresh_token")
        Keychain.save(String(s.expiresAt.timeIntervalSince1970), account: "expires_at")
        Keychain.save(s.email, account: "email")
    }

    private func adopt(_ s: CloudSession) {
        session = s
        persist(s)
        email = s.email
        signedIn = true
    }

    private func wipe() {
        ["access_token", "refresh_token", "expires_at", "email"].forEach { Keychain.delete(account: $0) }
        session = nil
        signedIn = false
        stopPolling()
        Task { await stopActivity() }
    }

    /// 冷启动：从 Keychain 把登录状态捡回来。这是不掉登录的关键。
    func restore() async {
        defer { booting = false }
        guard let at = Keychain.read("access_token"),
              let rt = Keychain.read("refresh_token"),
              !at.isEmpty, !rt.isEmpty else { return }

        let exp = Double(Keychain.read("expires_at") ?? "") ?? 0
        var s = CloudSession(accessToken: at, refreshToken: rt,
                             expiresAt: Date(timeIntervalSince1970: exp),
                             email: Keychain.read("email") ?? "")
        session = s
        email = s.email
        signedIn = true

        // 令牌快过期就先续一次，续不动才掉登录
        if s.isStale {
            do {
                let n = try await Cloud.refresh(rt: rt)
                adopt(n)
            } catch {
                // 续期失败：只要 access token 还能用就先不踢出去
                if let em = try? await Cloud.me(token: at) {
                    s.email = em
                    email = em
                } else {
                    wipe()
                    return
                }
            }
        }
        startPolling()
        await refreshAll()
    }

    private func validToken() async throws -> String {
        guard let s = session else { throw CloudError(message: "还没有登录") }
        if s.isStale {
            let n = try await Cloud.refresh(rt: s.refreshToken)
            adopt(n)
            return n.accessToken
        }
        return s.accessToken
    }

    // MARK: - 登录 / 注册

    func signIn(email: String, password: String) async {
        working = true; banner = nil
        do {
            var s = try await Cloud.signIn(email: email, password: password)
            if s.email.isEmpty {
                s.email = (try? await Cloud.me(token: s.accessToken)) ?? email
            }
            adopt(s)
            startPolling()
            await refreshAll()
        } catch {
            banner = error.localizedDescription
        }
        working = false
    }

    /// 走验证码：先发码，拿到 id 后校验，老用户直接登、新用户注册
    func sendCode(email: String) async -> String? {
        working = true; banner = nil
        defer { working = false }
        do {
            let (vid, isUser) = try await Cloud.sendOtp(email: email)
            otpIsUser = isUser
            return vid
        } catch {
            banner = error.localizedDescription
            return nil
        }
    }

    func verifyCode(email: String, vid: String, code: String, password: String) async -> Bool {
        working = true; banner = nil
        defer { working = false }
        do {
            let vt = try await Cloud.verifyOtp(vid: vid, code: code)
            var s: CloudSession
            if otpIsUser {
                s = try await Cloud.signInWithToken(email: email, vt: vt)
            } else {
                let pw = password.isEmpty ? defaultPassword(for: email) : password
                s = try await Cloud.signUp(email: email, password: pw, vt: vt)
            }
            if s.email.isEmpty { s.email = email }
            adopt(s)
            startPolling()
            await refreshAll()
            return true
        } catch {
            banner = error.localizedDescription
            return false
        }
    }

    private func defaultPassword(for email: String) -> String {
        "Lm#" + String(email.prefix(6)) + "2026"
    }

    func signOut() { wipe() }

    // MARK: - 数据

    func startPolling() {
        stopPolling()
        poll = Timer.scheduledTimer(withTimeInterval: 10, repeats: true) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in await self.refreshAll() }
        }
    }
    private func stopPolling() { poll?.invalidate(); poll = nil }

    func refreshAll() async {
        await ensureBindCode()
        await loadConversations()
        await loadDevice()
        await loadCommands()
        await loadProfile()
        await pushActivity()
    }

    func ensureBindCode() async {
        guard let t = try? await validToken() else { return }
        do {
            let rows = try await Cloud.array(Cloud.db("devices?select=*&order=id.desc&limit=10"), token: t)
            if let d = rows.compactMap({ try? decode(Device.self, $0) }).first(where: { !$0.code.isEmpty }) {
                bindCode = d.code
            } else {
                let code = Self.randomCode()
                _ = try? await Cloud.array(Cloud.db("devices"), method: "POST", token: t,
                    body: ["code": code, "name": "我的安卓手机", "status": "offline"],
                    prefer: "return=representation")
                bindCode = code
            }
        } catch {}
    }

    func loadConversations() async {
        guard let t = try? await validToken() else { return }
        do {
            let rows = try await Cloud.array(Cloud.db("conversations?select=*&order=id.desc&limit=200"), token: t)
            conversations = rows.compactMap { try? decode(Conversation.self, $0) }
        } catch {}
    }

    func loadDevice() async {
        guard let t = try? await validToken() else { return }
        do {
            let rows = try await Cloud.array(
                Cloud.db("devices?select=*&order=last_seen.desc.nullsfirst&limit=5"), token: t)
            device = rows.compactMap { try? decode(Device.self, $0) }.first
        } catch {}
    }

    func loadCommands() async {
        guard let t = try? await validToken() else { return }
        do {
            let rows = try await Cloud.array(Cloud.db("commands?select=*&order=id.desc&limit=8"), token: t)
            commands = rows.compactMap { try? decode(Command.self, $0) }
        } catch {}
    }

    func loadMessages(_ convID: Int) async {
        guard let t = try? await validToken() else { return }
        do {
            let rows = try await Cloud.array(
                Cloud.db("messages?select=*&conversation_id=eq.\(convID)&order=id.asc&limit=300"), token: t)
            messages = rows.compactMap { try? decode(ChatMessage.self, $0) }
        } catch {}
    }

    func send(_ text: String, to conv: Conversation) async {
        guard let t = try? await validToken() else { return }
        do {
            _ = try await Cloud.array(Cloud.db("messages"), method: "POST", token: t,
                body: ["conversation_id": conv.id, "sender": "me", "content": text, "msg_type": "text"],
                prefer: "return=representation")
            _ = try await Cloud.array(Cloud.db("commands"), method: "POST", token: t,
                body: ["cmd_type": "send",
                       "payload": ["conversation_id": conv.id, "name": conv.name, "text": text]],
                prefer: "return=representation")
            await loadMessages(conv.id)
            await loadCommands()
            await pushActivity()
        } catch {
            banner = error.localizedDescription
        }
    }

    func requestSync() async {
        guard let t = try? await validToken() else { return }
        working = true
        do {
            _ = try await Cloud.array(Cloud.db("commands"), method: "POST", token: t,
                body: ["cmd_type": "refresh", "payload": ["from": "ios"]],
                prefer: "return=representation")
            banner = "已下发同步指令"
        } catch {
            banner = error.localizedDescription
        }
        working = false
        await loadCommands()
        await pushActivity()
    }

    func loadProfile() async {
        guard let t = try? await validToken() else { return }
        do {
            let rows = try await Cloud.array(Cloud.db("profile?select=*&limit=5"), token: t)
            if let p = rows.compactMap({ try? decode(Profile.self, $0) }).first { profile = p }
        } catch {}
    }

    func saveProfile() async {
        guard let t = try? await validToken() else { banner = "没登录"; return }
        do {
            var body: [String: Any] = [
                "nickname": profile.nickname,
                "avatar_kind": profile.avatar_kind,
                "avatar_value": profile.avatar_value,
                "avatar_emoji": profile.avatar_emoji,
                "avatar_image": profile.avatar_image,
                "updated_at": ISO8601DateFormatter().string(from: Date())
            ]
            if let id = profile.id {
                _ = try await Cloud.array(Cloud.db("profile?id=eq.\(id)"), method: "PATCH", token: t,
                                          body: body, prefer: "return=representation")
            } else {
                let rows = try await Cloud.array(Cloud.db("profile?select=id&limit=5"), token: t)
                if let existing = rows.compactMap({ try? decode(Profile.self, $0) }).first, let eid = existing.id {
                    _ = try await Cloud.array(Cloud.db("profile?id=eq.\(eid)"), method: "PATCH", token: t,
                                              body: body, prefer: "return=representation")
                    profile.id = eid
                } else {
                    body["owner_id"] = ""
                    let made = try await Cloud.array(Cloud.db("profile"), method: "POST", token: t,
                                                     body: body, prefer: "return=representation")
                    if let p = made.compactMap({ try? decode(Profile.self, $0) }).first { profile.id = p.id }
                }
            }
            banner = "资料已保存"
        } catch {
            banner = error.localizedDescription
        }
    }

    func unbindDevice() async {
        guard let t = try? await validToken() else { return }
        _ = try? await Cloud.array(Cloud.db("devices?owner_id=is.null&code=eq.\(bindCode)"),
                                   method: "DELETE", token: t, prefer: "return=representation")
        device = nil
        banner = "已解绑"
    }

    // MARK: - 实时活动

    func startActivity() {
        guard liveActivityOn else { return }
        box.start()
    }

    func pushActivity() async {
        guard liveActivityOn else { await stopActivity(); return }
        box.start()
        let unread = conversations.reduce(0) { $0 + ($1.unread ?? 0) }
        let pending = commands.filter { ($0.status ?? "") == "pending" }.count
        let s = statusSummary()
        let st = LuminaAttributes.ContentState(status: s.0, detail: s.1, unread: unread,
                                               pending: pending, updatedAt: Date())
        await box.update(st)
    }

    func stopActivity() async {
        await box.stop()
    }

    private func statusSummary() -> (String, String) {
        let online = Self.isOnline(device?.last_seen)
        if working { return ("同步中", "正在让安卓机读快手私信") }
        if let e = device?.last_error, !e.isEmpty { return ("出错了", e) }
        if online { return ("在线", "安卓机已连上") }
        return ("离线", "安卓机还没接上")
    }

    static func isOnline(_ v: String?) -> Bool {
        guard let v, !v.isEmpty else { return false }
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        guard let d = f.date(from: v) ?? ISO8601DateFormatter().date(from: v) else { return false }
        return Date().timeIntervalSince(d) < 90
    }

    static func randomCode() -> String {
        let s = Array("ABCDEFGHJKLMNPQRSTUVWXYZ23456789")
        return String((0..<6).compactMap { _ in s.randomElement() })
    }
}

@MainActor
func decode<T: Decodable>(_: T.Type, _ d: [String: Any]) throws -> T {
    let data = try JSONSerialization.data(withJSONObject: d)
    return try JSONDecoder().decode(T.self, from: data)
}
