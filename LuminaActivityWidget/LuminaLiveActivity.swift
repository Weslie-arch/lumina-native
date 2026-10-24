import WidgetKit
import SwiftUI
import ActivityKit

struct LuminaLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: LuminaAttributes.self) { context in
            // 锁屏
            HStack(spacing: 12) {
                Circle()
                    .fill(statusColor(context.state.status))
                    .frame(width: 10, height: 10)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Lumina · \(context.state.status)")
                        .font(.system(size: 14, weight: .semibold))
                    Text(context.state.detail)
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Spacer()
                if context.state.unread > 0 {
                    Text("\(context.state.unread) 未读")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.red)
                }
                if context.state.pending > 0 {
                    Text("\(context.state.pending) 待发")
                        .font(.system(size: 12))
                        .foregroundStyle(.orange)
                }
            }
            .padding(14)
            .activityBackgroundTint(Color(.secondarySystemBackground))
            .activitySystemActionForegroundColor(.primary)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    HStack(spacing: 6) {
                        Circle().fill(statusColor(context.state.status)).frame(width: 8, height: 8)
                        Text(context.state.status).font(.system(size: 13, weight: .semibold))
                    }
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text(context.state.detail).font(.system(size: 12)).foregroundStyle(.secondary)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    HStack {
                        if context.state.unread > 0 {
                            Label("\(context.state.unread) 条未读", systemImage: "bubble.left")
                                .font(.system(size: 12))
                        }
                        if context.state.pending > 0 {
                            Label("\(context.state.pending) 条待发", systemImage: "paperplane")
                                .font(.system(size: 12))
                        }
                        Spacer()
                        Text(context.state.updatedAt, style: .time)
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }
                }
            } compactLeading: {
                Circle().fill(statusColor(context.state.status)).frame(width: 7, height: 7)
            } compactTrailing: {
                Text(context.state.unread > 0 ? "\(context.state.unread)" : context.state.status)
                    .font(.system(size: 11, weight: .medium))
            } minimal: {
                Circle().fill(statusColor(context.state.status)).frame(width: 8, height: 8)
            }
            .widgetURL(URL(string: "lumina://home"))
        }
    }
}

private func statusColor(_ s: String) -> Color {
    if s.contains("同步") { return .blue }
    if s.contains("在線") || s.contains("在线") { return .green }
    if s.contains("错") { return .red }
    return .gray
}
