import SwiftUI

/// 倒计时放这里，是为了避开 Swift 6 的并发检查：
/// Timer 的闭包是非隔离的，直接改 View 的 @State 会被判成 data race。
@MainActor
final class Countdown: ObservableObject {
    @Published var value = 0
    private var timer: Timer?

    func start(seconds: Int) {
        value = seconds
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                if self.value > 1 { self.value -= 1 } else { self.stop() }
            }
        }
    }

    func stop() { timer?.invalidate(); timer = nil; value = 0 }
}

// MARK: - 外壳：只负责在「登录」和「注册」之间切换

struct AuthView: View {
    @EnvironmentObject var state: AppState
    @State private var isRegister = false

    var body: some View {
        ZStack {
            AppBackground()
            ScrollView {
                VStack(spacing: 20) {
                    brand

                    Picker("", selection: $isRegister) {
                        Text("登录").tag(false)
                        Text("注册").tag(true)
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal, 4)

                    // 两个 pane 各自持有状态，一切换旧的就被销毁，不会串味
                    if isRegister { RegisterPane() } else { LoginPane() }

                    if let b = state.banner {
                        Text(b)
                            .font(.footnote)
                            .foregroundStyle(.red)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 8)
                    }
                }
                .padding(.horizontal, 22)
                .padding(.top, 64)
                .padding(.bottom, 40)
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .ignoresSafeArea()
        .onChange(of: isRegister) { _, _ in state.banner = nil }
    }

    private var brand: some View {
        VStack(spacing: 6) {
            Text("Lumina")
                .font(.system(size: 40, weight: .bold, design: .rounded))
                .foregroundStyle(LinearGradient(colors: [.indigo, .purple],
                                                startPoint: .leading, endPoint: .trailing))
            Text(isRegister ? "创建一个新账号" : "欢迎回来")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - 登录（老用户：邮箱 → 验证码 → 进入）

struct LoginPane: View {
    @EnvironmentObject var state: AppState
    @State private var email = ""
    @State private var code = ""
    @State private var vid: String?
    @StateObject private var ticker = Countdown()

    var body: some View {
        AuthCard {
            Text("用邮箱验证码登录")
                .font(.system(size: 15, weight: .semibold))
                .frame(maxWidth: .infinity, alignment: .leading)

            GlassField(title: "邮箱", text: $email, keyboard: .emailAddress)
                .disabled(vid != nil)
                .opacity(vid != nil ? 0.55 : 1)

            if vid != nil {
                GlassField(title: "6 位验证码", text: $code, keyboard: .numberPad)
            }

            if state.working {
                ProgressView().controlSize(.large).frame(height: 52)
            } else {
                AuthButton(title: vid == nil ? "发送验证码" : "登录", enabled: canGo, action: mainAction)
            }

            if vid != nil {
                Button(ticker.value > 0 ? "\(ticker.value) 秒后重发" : "重新发送验证码") { send() }
                    .font(.footnote)
                    .disabled(ticker.value > 0)
            }
        }
    }

    private var canGo: Bool {
        guard email.contains("@") else { return false }
        return vid == nil ? true : code.count >= 4
    }

    private func mainAction() {
        if vid == nil { send() } else { verify() }
    }

    private func send() {
        Task {
            if let v = await state.loginSendCode(email: email) {
                vid = v
                code = ""
                ticker.start(seconds: 60)
            }
        }
    }

    private func verify() {
        guard let v = vid else { return }
        Task {
            let ok = await state.loginVerify(email: email, vid: v, code: code)
            if ok { ticker.stop() } else { code = "" }
        }
    }
}

// MARK: - 注册（新用户：邮箱 + 邀请码 → 验证码 + 密码 → 建号）

struct RegisterPane: View {
    @EnvironmentObject var state: AppState
    @State private var email = ""
    @State private var invite = ""
    @State private var code = ""
    @State private var password = ""
    @State private var vid: String?
    @StateObject private var ticker = Countdown()

    var body: some View {
        AuthCard {
            Text("创建 Lumina 账号")
                .font(.system(size: 15, weight: .semibold))
                .frame(maxWidth: .infinity, alignment: .leading)

            GlassField(title: "邮箱", text: $email, keyboard: .emailAddress)
                .disabled(vid != nil)
                .opacity(vid != nil ? 0.55 : 1)

            if vid == nil {
                GlassField(title: "邀请码", text: $invite)
            } else {
                GlassField(title: "6 位验证码", text: $code, keyboard: .numberPad)
                GlassField(title: "设置密码（至少 6 位）", text: $password, secure: true)
            }

            if state.working {
                ProgressView().controlSize(.large).frame(height: 52)
            } else {
                AuthButton(title: vid == nil ? "发送验证码" : "创建账号",
                           enabled: canGo, action: mainAction)
            }

            if vid != nil {
                Button(ticker.value > 0 ? "\(ticker.value) 秒后重发" : "重新发送验证码") { send() }
                    .font(.footnote)
                    .disabled(ticker.value > 0)
            }
        }
    }

    private var canGo: Bool {
        guard email.contains("@") else { return false }
        if vid == nil { return invite.uppercased() == Cloud.inviteCode }
        return code.count >= 4 && password.count >= 6
    }

    private func mainAction() {
        if vid == nil { send() } else { create() }
    }

    private func send() {
        Task {
            if let v = await state.registerSendCode(email: email) {
                vid = v
                code = ""
                ticker.start(seconds: 60)
            }
        }
    }

    private func create() {
        guard let v = vid else { return }
        Task {
            let ok = await state.registerVerify(email: email, vid: v,
                                                code: code, password: password)
            if ok { ticker.stop() } else { code = "" }
        }
    }
}

// MARK: - 共用零件

struct AuthCard<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        VStack(spacing: 15) { content }
            .padding(20)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 26, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 26, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.35), lineWidth: 1)
            )
    }
}

struct AuthButton: View {
    var title: String
    var enabled: Bool
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 16, weight: .semibold))
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .foregroundStyle(.white)
                .background(LinearGradient(colors: [.indigo, .purple],
                                           startPoint: .leading, endPoint: .trailing))
                .clipShape(RoundedRectangle(cornerRadius: 15, style: .continuous))
        }
        .disabled(!enabled)
        .opacity(enabled ? 1 : 0.5)
    }
}

/// 毛玻璃输入框
struct GlassField: View {
    var title: String
    @Binding var text: String
    var secure: Bool = false
    var keyboard: UIKeyboardType = .default

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.caption).foregroundStyle(.secondary)
            Group {
                if secure { SecureField("", text: $text) }
                else { TextField("", text: $text) }
            }
            .keyboardType(keyboard)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
            .padding(.horizontal, 14)
            .frame(height: 46)
            .background(Color(.secondarySystemBackground),
                        in: RoundedRectangle(cornerRadius: 13, style: .continuous))
        }
    }
}
