import Foundation

struct CloudError: LocalizedError {
    var message: String
    var errorDescription: String? { message }
}

/// 直连云服务的 REST 接口（不依赖网页 SDK）。
/// auth:     {endpoint}/.cloud/auth/v1/*
/// database: {endpoint}/.cloud/database/rest/*  (PostgREST)
enum Cloud {
    static let endpoint = "https://pure-chat.app.workbuddy.host"
    static let host = "pure-chat.app.workbuddy.host"
    static let accessKey = "wbpk_GZUkcmIYUOHrSs1BhFAw2G_uCthzsGdVnB9HJgkkhQm7mA471l7RcY9"
    static let inviteCode = "LUMINA2026"
    static let userAgent =
        "Mozilla/5.0 (iPhone; CPU iPhone OS 26_0 like Mac OS X) AppleWebKit/605.1.15 "
        + "(KHTML, like Gecko) Version/26.0 Mobile/15E148 Safari/604.1"

    static func auth(_ p: String) -> URL { URL(string: endpoint + "/.cloud/auth" + p)! }
    static func db(_ p: String) -> URL { URL(string: endpoint + "/.cloud/database/rest/" + p)! }

    // MARK: - 底层

    private static func raw(_ url: URL, method: String, token: String?,
                            body: [String: Any]?, prefer: String?) async throws -> Any {
        var req = URLRequest(url: url)
        req.httpMethod = method
        req.timeoutInterval = 30
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue(accessKey, forHTTPHeaderField: "x-wb-webapp-access-key")
        req.setValue("application/json", forHTTPHeaderField: "Accept")

        // 服务端签发令牌时会校验「客户端上下文」，缺了这些浏览器自带的头
        // 就会回 401 the session is invalid, expired or issued for another client
        req.setValue("https://\(host)", forHTTPHeaderField: "Origin")
        req.setValue("https://\(host)/", forHTTPHeaderField: "Referer")
        req.setValue(Self.userAgent, forHTTPHeaderField: "User-Agent")
        req.setValue("zh-CN,zh;q=0.9", forHTTPHeaderField: "Accept-Language")
        req.setValue("same-origin", forHTTPHeaderField: "Sec-Fetch-Site")
        req.setValue("cors", forHTTPHeaderField: "Sec-Fetch-Mode")

        if let t = token, !t.isEmpty {
            req.setValue("Bearer \(t)", forHTTPHeaderField: "Authorization")
        }
        if let p = prefer { req.setValue(p, forHTTPHeaderField: "Prefer") }
        if let b = body { req.httpBody = try? JSONSerialization.data(withJSONObject: b) }

        let (data, resp) = try await URLSession.shared.data(for: req)
        let code = (resp as? HTTPURLResponse)?.statusCode ?? 0
        let text = String(data: data, encoding: .utf8) ?? ""
        let obj = try? JSONSerialization.jsonObject(with: data)

        if code >= 400 {
            var msg = "请求失败 (\(code))"
            if let d = obj as? [String: Any] {
                msg = (d["message"] as? String)
                    ?? (d["error_description"] as? String)
                    ?? (d["error"] as? String)
                    ?? (d["msg"] as? String)
                    ?? text
            } else if !text.isEmpty {
                msg = text
            }
            throw CloudError(message: String(msg.prefix(200)))
        }
        if obj == nil && !text.isEmpty { return text as Any }
        return obj ?? [String: Any]()
    }

    static func dict(_ url: URL, method: String = "GET", token: String? = nil,
                     body: [String: Any]? = nil, prefer: String? = nil) async throws -> [String: Any] {
        let r = try await raw(url, method: method, token: token, body: body, prefer: prefer)
        if let d = r as? [String: Any] { return d }
        return [:]
    }

    static func array(_ url: URL, method: String = "GET", token: String? = nil,
                      body: [String: Any]? = nil, prefer: String? = nil) async throws -> [[String: Any]] {
        let r = try await raw(url, method: method, token: token, body: body, prefer: prefer)
        if let a = r as? [[String: Any]] { return a }
        if let d = r as? [String: Any], let a = d["data"] as? [[String: Any]] { return a }
        return []
    }

    // MARK: - 会话（登录状态）

    /// 有些接口把内容包一层 data，这里统一展平
    private static func unwrap(_ d: [String: Any]) -> [String: Any] {
        if d["access_token"] == nil, let inner = d["data"] as? [String: Any] { return inner }
        return d
    }

    static func parseSession(_ d: [String: Any]) -> CloudSession? {
        let o = unwrap(d)
        guard let at = o["access_token"] as? String, !at.isEmpty else { return nil }
        let rt = (o["refresh_token"] as? String) ?? ""
        let exp = (o["expires_in"] as? Int) ?? (o["expires_in"] as? Double).map { Int($0) } ?? 3600
        let email = (o["email"] as? String)
            ?? ((o["user"] as? [String: Any])?["email"] as? String)
            ?? ""
        return CloudSession(accessToken: at, refreshToken: rt,
                            expiresAt: Date().addingTimeInterval(Double(exp)),
                            email: email)
    }

    /// 密码登录
    static func signIn(email: String, password: String) async throws -> CloudSession {
        let d = try await dict(auth("/v1/signin"), method: "POST",
                               body: ["username": email, "password": password])
        guard let s = parseSession(d) else { throw CloudError(message: "登录失败，邮箱或密码不对") }
        return s
    }

    /// 发送邮箱验证码 → 返回 verification_id 和是否老用户
    static func sendOtp(email: String) async throws -> (String, Bool) {
        let d = try await dict(auth("/v1/verification"), method: "POST",
                               body: ["email": email, "usage": "email"])
        let o = unwrap(d)
        guard let vid = o["verification_id"] as? String, !vid.isEmpty else {
            throw CloudError(message: "验证码没发出去，稍后再试")
        }
        return (vid, (o["is_user"] as? Bool) ?? false)
    }

    /// 校验验证码 → verification_token
    static func verifyOtp(vid: String, code: String) async throws -> String {
        let d = try await dict(auth("/v1/verification/verify"), method: "POST",
                               body: ["verification_id": vid, "verification_code": code])
        let o = unwrap(d)
        guard let vt = o["verification_token"] as? String, !vt.isEmpty else {
            throw CloudError(message: "验证码不对或已过期")
        }
        return vt
    }

    /// 老用户用验证码直接登录
    static func signInWithToken(email: String, vt: String) async throws -> CloudSession {
        let d = try await dict(auth("/v1/signin"), method: "POST",
                               body: ["username": email, "verification_token": vt])
        guard let s = parseSession(d) else { throw CloudError(message: "登录失败") }
        return s
    }

    /// 新用户注册
    static func signUp(email: String, password: String, vt: String) async throws -> CloudSession {
        let d = try await dict(auth("/v1/signup"), method: "POST",
                               body: ["email": email, "password": password, "verification_token": vt])
        guard let s = parseSession(d) else { throw CloudError(message: "注册失败") }
        return s
    }

    /// 用 refresh_token 续期
    static func refresh(rt: String) async throws -> CloudSession {
        let d = try await dict(auth("/v1/token"), method: "POST",
                               body: ["grant_type": "refresh_token", "refresh_token": rt])
        guard let s = parseSession(d) else { throw CloudError(message: "登录已过期，请重新登录") }
        return s
    }

    static func me(token: String) async throws -> String {
        let d = try await dict(auth("/v1/user/me"), token: token)
        let o = unwrap(d)
        return (o["email"] as? String) ?? ((o["user"] as? [String: Any])?["email"] as? String) ?? ""
    }
}

struct CloudSession {
    var accessToken: String
    var refreshToken: String
    var expiresAt: Date
    var email: String

    var isStale: Bool { Date().addingTimeInterval(60) > expiresAt }
}
