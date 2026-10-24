import SwiftUI

struct AuthView: View {
    @EnvironmentObject var state: AppState
    @State private var mode = 0            // 0 验证码 / 1 密码
    @State private var email = ""
    @State private var password = ""
    @State private var code = ""
    @State private var invite = ""
    @State private var vid: String?
    @State private var countdown = 0
    @State private var timer: Timer?

    var body: some View {
        ZStack {
            AppBackground()
            ScrollView {
                VStack(spacing: 22) {
                    brand
                    card
                    if let b = state.banner {
                        Text(b).font(.footnote).foregroundStyle(.red)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                }
                .padding(.horizontal, 22)
                .padding(.top, 70)
                .padding(.bottom, 40)
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .ignoresSafeArea()
    }

    private var brand: some View {
        VStack(spacing: 6) {
            Text("Lumina")
                .font(.system(size: 40, weight: .bold, design: .rounded))
                .foregroundStyle(LinearGradient(colors: [.indigo, .purple],
                                                startPoint: .leading, endPoint: .trailing))
            Text("只有聊天，没有别的")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    private var card: some View {
        VStack(spacing: 16) {
            Picker("", selection: $mode) {
                Text("验证码").tag(0)
                Text("密码").tag(1)
            }
            .pickerStyle(.segmented)
            .onChange(of: mode) { _, _ in resetFlow() }

            GlassField(title: "邮箱", text: $email, keyboard: .emailAddress)

            if mode == 1 {
                GlassField(title: "密码", text: $password, secure: true)
            }

            if mode == 0 && vid == nil {
                GlassField(title: "邀请码", text: $invite)
            }

            if mode == 0 && vid != nil {
                GlassField(title: "6 位验证码", text: $code, keyboard: .numberPad)
                if mode == 0 {
                    GlassField(title: "设置密码（可选）", text: $password, secure: true)
                }
            }

            if state.working {
                ProgressView().controlSize(.large).frame(height: 52)
            } else {
                Button(action: mainAction) {
                    Text(mainTitle)
                        .font(.system(size: 16, weight: .semibold))
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .foregroundStyle(.white)
                        .background(LinearGradient(colors: [.indigo, .purple],
                                                   startPoint: .leading, endPoint: .trailing))
                        .clipShape(RoundedRectangle(cornerRadius: 15, style: .continuous))
                }
                .disabled(!canGo)
                .opacity(canGo ? 1 : 0.5)
            }

            if mode == 0 && vid != nil {
                Button(countdown > 0 ? "\(countdown) 秒后重发" : "重新发送验证码") { sendCode() }
                    .font(.footnote)
                    .disabled(countdown > 0)
            }
        }
        .padding(20)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 26, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .strokeBorder(Color.white.opacity(0.35), lineWidth: 1)
        )
    }

    private var mainTitle: String {
        if mode == 1 { return "登录 / 注册" }
        return vid == nil ? "发送验证码" : "验证并进入"
    }

    private var canGo: Bool {
        let ok = email.contains("@")
        if mode == 1 { return ok && password.count >= 6 }
        if vid == nil { return ok && invite.uppercased() == Cloud.inviteCode }
        return code.count == 6
    }

    private func mainAction() {
        if mode == 1 {
            Task { await state.signIn(email: email, password: password) }
            return
        }
        if vid == nil { sendCode() } else {
            guard let v = vid else { return }
            Task {
                let ok = await state.verifyCode(email: email, vid: v, code: code, password: password)
                if ok { stopTimer() }
            }
        }
    }

    private func sendCode() {
        guard email.contains("@") else { return }
        Task {
            if let v = await state.sendCode(email: email) {
                vid = v
                code = ""
                startCountdown()
            }
        }
    }

    private func resetFlow() { vid = nil; code = ""; stopTimer() }

    private func startCountdown() {
        countdown = 60
        stopTimer()
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { t in
            Task { @MainActor in
                if countdown > 1 { countdown -= 1 } else { countdown = 0; t.invalidate() }
            }
        }
    }
    private func stopTimer() { timer?.invalidate(); timer = nil; countdown = 0 }
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
            .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 13, style: .continuous))
        }
    }
}
