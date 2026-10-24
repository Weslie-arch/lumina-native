import SwiftUI
import PhotosUI

struct MeView: View {
    @EnvironmentObject var state: AppState
    @State private var editing = false

    var body: some View {
        ZStack {
            AppBackground()
            ScrollView {
                VStack(spacing: 14) {
                    profileCard
                    deviceCard
                    settingsCard
                    Button(role: .destructive) { state.signOut() } label: {
                        Text("退出登录")
                            .font(.system(size: 15, weight: .semibold))
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background(Color.red.opacity(0.12),
                                        in: RoundedRectangle(cornerRadius: 15, style: .continuous))
                    }
                    .padding(.top, 6)
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 30)
            }
        }
        .background(AppBackground())
        .sheet(isPresented: $editing) { ProfileEditor().environmentObject(state) }
    }

    private var profileCard: some View {
        GlassCard {
            Button { editing = true } label: {
                HStack(spacing: 14) {
                    AvatarView(profile: state.profile, fallback: state.email, size: 62)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(state.profile.nickname.isEmpty ? "点这里设置昵称" : state.profile.nickname)
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(state.profile.nickname.isEmpty ? .secondary : .primary)
                        Text(state.email.isEmpty ? "—" : state.email)
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Text("编辑 ›").font(.caption).foregroundStyle(.secondary)
                }
            }
            .buttonStyle(.plain)
        }
    }

    private var deviceCard: some View {
        GlassCard {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("安卓中转机").font(.system(size: 15, weight: .semibold))
                    Text(AppState.isOnline(state.device?.last_seen) ? "在线" : "未绑定")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 3) {
                    Text("绑定码").font(.caption2).foregroundStyle(.secondary)
                    Text(state.bindCode)
                        .font(.system(size: 16, weight: .bold, design: .monospaced))
                }
                Button { UIPasteboard.general.string = state.bindCode } label: {
                    Image(systemName: "doc.on.doc").font(.caption)
                }
                .buttonStyle(.bordered)
            }
            Button(role: .destructive) { Task { await state.unbindDevice() } } label: {
                Text("解绑这台手机").font(.caption)
            }
            .padding(.top, 8)
        }
    }

    private var settingsCard: some View {
        GlassCard {
            Toggle(isOn: Binding(get: { state.liveActivityOn }, set: { v in
                state.liveActivityOn = v
                Task { v ? await state.pushActivity() : await state.stopActivity() }
            })) {
                Text("锁屏实时活动")
            }
            .tint(.indigo)
            Divider().padding(.vertical, 8)
            HStack {
                Text("数据隔离").font(.system(size: 15))
                Spacer()
                Text("仅本人可见").font(.caption).foregroundStyle(.secondary)
            }
            Divider().padding(.vertical, 8)
            HStack {
                Text("登录状态").font(.system(size: 15))
                Spacer()
                Text("钥匙串 · 长期保持").font(.caption).foregroundStyle(.secondary)
            }
        }
    }
}

struct ProfileEditor: View {
    @EnvironmentObject var state: AppState
    @Environment(\.dismiss) private var dismiss

    @State private var nick = ""
    @State private var kind = "letter"
    @State private var colorHex = ""
    @State private var emoji = ""
    @State private var imageB64 = ""
    @State private var pickerItem: PhotosPickerItem?

    private let colors = ["#6366f1", "#a855f7", "#48b884", "#e8833a",
                          "#2fb3c4", "#e8637e", "#5b8def", "#d4a017"]
    private let emojis = ["😀", "😎", "🌸", "🐱", "🦊", "🌙", "⭐", "🔥",
                          "🍀", "🎧", "🚀", "💎", "🐼", "🌊", "🍭", "🦄"]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    preview
                    nicknameField
                    colorPicker
                    emojiPicker
                }
                .padding(18)
            }
            .background(AppBackground())
            .navigationTitle("编辑资料")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") { save() }
                }
            }
            .onAppear {
                nick = state.profile.nickname
                kind = state.profile.avatar_kind
                colorHex = state.profile.avatar_value.isEmpty ? colors[0] : state.profile.avatar_value
                emoji = state.profile.avatar_emoji
                imageB64 = state.profile.avatar_image
            }
        }
    }

    private var preview: some View {
        VStack(spacing: 12) {
            AvatarView(profile: draft, fallback: state.email, size: 92)
            PhotosPicker(selection: $pickerItem, matching: .images) {
                Text("上传图片").font(.subheadline)
                    .padding(.horizontal, 16).padding(.vertical, 8)
                    .background(Color(.secondarySystemBackground),
                                in: Capsule())
            }
            .onChange(of: pickerItem) { _, item in
                guard let item else { return }
                Task {
                    if let d = try? await item.loadTransferable(type: Data.self),
                       let img = UIImage(data: d),
                       let b64 = img.avatarJPEG() {
                        imageB64 = b64
                        kind = "image"
                    }
                }
            }
            if kind == "image" {
                Button("改用字母头像") { kind = "letter"; imageB64 = ""; emoji = "" }
                    .font(.footnote)
            }
        }
    }

    private var draft: Profile {
        var p = Profile()
        p.nickname = nick
        p.avatar_kind = kind
        p.avatar_value = colorHex
        p.avatar_emoji = emoji
        p.avatar_image = imageB64
        return p
    }

    private var nicknameField: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("昵称").font(.caption).foregroundStyle(.secondary)
            TextField("给自己起个名字", text: $nick)
                .padding(.horizontal, 14)
                .frame(height: 48)
                .background(Color(.secondarySystemBackground),
                            in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
    }

    private var colorPicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("头像颜色").font(.caption).foregroundStyle(.secondary)
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 8), spacing: 8) {
                ForEach(colors, id: \.self) { c in
                    Circle()
                        .fill(Color(hex: c) ?? .indigo)
                        .frame(height: 32)
                        .overlay(Circle().stroke(colorHex == c ? Color.primary : .clear, lineWidth: 2))
                        .onTapGesture { colorHex = c; if kind == "image" { kind = "letter"; imageB64 = "" } }
                }
            }
        }
    }

    private var emojiPicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("或者用表情").font(.caption).foregroundStyle(.secondary)
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 8), spacing: 6) {
                ForEach(emojis, id: \.self) { e in
                    Text(e).font(.system(size: 20))
                        .frame(height: 36)
                        .frame(maxWidth: .infinity)
                        .background(Color(.secondarySystemBackground),
                                    in: RoundedRectangle(cornerRadius: 9, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 9, style: .continuous)
                                .stroke(kind == "emoji" && emoji == e ? Color.indigo : .clear, lineWidth: 2))
                        .onTapGesture { emoji = e; kind = "emoji"; imageB64 = "" }
                }
            }
        }
    }

    private func save() {
        var p = state.profile
        p.nickname = nick
        p.avatar_kind = kind
        p.avatar_value = colorHex
        p.avatar_emoji = emoji
        p.avatar_image = imageB64
        state.profile = p
        Task {
            await state.saveProfile()
            await state.pushActivity()
        }
        dismiss()
    }
}
