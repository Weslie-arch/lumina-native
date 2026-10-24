import SwiftUI

struct HomeView: View {
    @EnvironmentObject var state: AppState

    private var online: Bool { AppState.isOnline(state.device?.last_seen) }
    private var pending: Int { state.commands.filter { ($0.status ?? "") == "pending" }.count }

    var body: some View {
        ZStack {
            AppBackground()
            ScrollView {
                VStack(spacing: 14) {
                    header
                    deviceCard
                    HStack(spacing: 10) {
                        StatBox(n: "\(state.conversations.count)", label: "会话")
                        StatBox(n: "\(pending)", label: "待执行")
                        StatBox(n: "\(state.messages.count)", label: "已加载消息")
                    }
                    syncButton
                    activityCard
                    logCard
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 30)
            }
            .refreshable { await state.refreshAll() }
        }
        .background(AppBackground())
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Lumina").font(.system(size: 26, weight: .bold, design: .rounded))
                Text("运行状态").font(.footnote).foregroundStyle(.secondary)
            }
            Spacer()
            AvatarView(profile: state.profile, fallback: state.email, size: 42)
        }
        .padding(.top, 6)
    }

    private var deviceCard: some View {
        GlassCard {
            HStack(spacing: 12) {
                Circle()
                    .fill(online ? Color.green : Color.gray.opacity(0.5))
                    .frame(width: 10, height: 10)
                    .overlay(Circle().stroke(online ? Color.green.opacity(0.35) : .clear, lineWidth: 6))
                VStack(alignment: .leading, spacing: 3) {
                    Text(state.device?.name ?? "安卓中转机")
                        .font(.system(size: 15.5, weight: .semibold))
                    Text(online ? "在线 · 心跳 \(agoText(state.device?.last_seen))"
                                : "未绑定 · 手机还没接上")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 3) {
                    Text("绑定码").font(.caption2).foregroundStyle(.secondary)
                    Text(state.bindCode)
                        .font(.system(size: 17, weight: .bold, design: .monospaced))
                }
            }
            Divider().padding(.vertical, 10)
            HStack {
                Text("上次同步").font(.caption).foregroundStyle(.secondary)
                Spacer()
                Text(agoText(state.device?.last_sync)).font(.caption)
            }
            if let e = state.device?.last_error, !e.isEmpty {
                Text(e).font(.caption).foregroundStyle(.orange).padding(.top, 6)
            }
        }
    }

    private var syncButton: some View {
        Button {
            Task { await state.requestSync() }
        } label: {
            HStack(spacing: 8) {
                if state.working { ProgressView().tint(.white) }
                Image(systemName: "arrow.triangle.2.circlepath")
                Text(state.working ? "同步中…" : "立即同步")
            }
            .font(.system(size: 16, weight: .semibold))
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .foregroundStyle(.white)
            .background(LinearGradient(colors: [.indigo, .purple],
                                       startPoint: .leading, endPoint: .trailing))
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .disabled(state.working)
    }

    private var activityCard: some View {
        GlassCard {
            HStack(spacing: 12) {
                Image(systemName: "waveform.path.ecg")
                    .font(.system(size: 18))
                    .foregroundStyle(.indigo)
                    .frame(width: 34, height: 34)
                    .background(Color.indigo.opacity(0.14),
                                in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                VStack(alignment: .leading, spacing: 2) {
                    Text("锁屏实时活动").font(.system(size: 15, weight: .semibold))
                    Text(state.liveActivityOn ? "锁屏和灵动岛会显示同步状态" : "已关闭")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Toggle("", isOn: Binding(
                    get: { state.liveActivityOn },
                    set: { v in
                        state.liveActivityOn = v
                        Task { v ? await state.pushActivity() : await state.stopActivity() }
                    }))
                .labelsHidden()
                .tint(.indigo)
            }
        }
    }

    private var logCard: some View {
        GlassCard {
            Text("最近指令").font(.system(size: 15, weight: .semibold))
            if state.commands.isEmpty {
                Text("还没有指令。点上面的同步试试。")
                    .font(.caption).foregroundStyle(.secondary)
                    .padding(.top, 6)
            } else {
                ForEach(state.commands.prefix(6)) { c in
                    HStack(spacing: 8) {
                        Circle()
                            .fill(color(for: c.status))
                            .frame(width: 7, height: 7)
                        Text(c.cmd_type == "refresh" ? "同步快手私信"
                             : (c.payload?["name"] as? String).map { "发给 \($0)" } ?? "代发消息")
                            .font(.subheadline)
                        Spacer()
                        Text(statusText(c.status)).font(.caption2).foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 3)
                }
            }
        }
    }

    private func color(for s: String?) -> Color {
        switch s {
        case "done": return .green
        case "failed": return .red
        default: return .orange
        }
    }
    private func statusText(_ s: String?) -> String {
        switch s {
        case "done": return "已完成"
        case "failed": return "失败"
        default: return "等待中"
        }
    }
}
