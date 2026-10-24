import SwiftUI

struct ChatListView: View {
    @EnvironmentObject var state: AppState

    var body: some View {
        NavigationStack {
        ZStack {
            AppBackground()
            Group {
                if state.conversations.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "bubble.left.and.bubble.right")
                            .font(.system(size: 40))
                            .foregroundStyle(.secondary)
                        Text("还没有会话")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Text("去主页点「立即同步」，安卓机会把快手私信搬过来")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(40)
                } else {
                    List {
                        ForEach(state.conversations) { c in
                            NavigationLink {
                                ChatView(conv: c)
                            } label: {
                                ConversationRow(conv: c)
                            }
                            .listRowBackground(Color.clear)
                        }
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                }
            }
        }
        .background(AppBackground())
        }
    }
}

struct ConversationRow: View {
    var conv: Conversation
    var body: some View {
        HStack(spacing: 12) {
            AvatarView(profile: Profile(), fallback: conv.name, size: 48)
            VStack(alignment: .leading, spacing: 3) {
                HStack {
                    Text(conv.name.isEmpty ? "未命名" : conv.name)
                        .font(.system(size: 15.5, weight: .semibold))
                        .lineLimit(1)
                    Spacer()
                    Text(shortTime(conv.last_time ?? conv.updated_at))
                        .font(.caption2).foregroundStyle(.secondary)
                }
                HStack {
                    Text(conv.last_message ?? "")
                        .font(.caption).foregroundStyle(.secondary).lineLimit(1)
                    Spacer()
                    if let u = conv.unread, u > 0 {
                        Text("\(u)")
                            .font(.caption2).bold()
                            .foregroundStyle(.white)
                            .padding(.horizontal, 7).padding(.vertical, 3)
                            .background(Capsule().fill(Color.red))
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }
}

struct ChatView: View {
    @EnvironmentObject var state: AppState
    var conv: Conversation
    @State private var text = ""
    @State private var timer: Timer?

    var body: some View {
        VStack(spacing: 0) {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(state.messages) { m in
                            BubbleView(msg: m).id(m.id)
                        }
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                }
                .onChange(of: state.messages.count) { _, _ in
                    if let last = state.messages.last {
                        withAnimation { proxy.scrollTo(last.id, anchor: .bottom) }
                    }
                }
            }
            inputBar
        }
        .navigationTitle(conv.name.isEmpty ? "会话" : conv.name)
        .navigationBarTitleDisplayMode(.inline)
        .background(AppBackground())
        .task {
            await state.loadMessages(conv.id)
            timer = Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { _ in
                Task { @MainActor in await state.loadMessages(conv.id) }
            }
        }
        .onDisappear { timer?.invalidate(); timer = nil }
    }

    private var inputBar: some View {
        HStack(spacing: 10) {
            TextField("说点什么", text: $text)
                .padding(.horizontal, 14)
                .frame(height: 44)
                .background(Color(.secondarySystemBackground),
                            in: RoundedRectangle(cornerRadius: 15, style: .continuous))
            Button {
                let t = text.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !t.isEmpty else { return }
                text = ""
                Task { await state.send(t, to: conv) }
            } label: {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 32))
                    .foregroundStyle(LinearGradient(colors: [.indigo, .purple],
                                                    startPoint: .top, endPoint: .bottom))
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.bar)
    }
}

struct BubbleView: View {
    var msg: ChatMessage
    var body: some View {
        HStack {
            if msg.isMine { Spacer(minLength: 50) }
            VStack(alignment: msg.isMine ? .trailing : .leading, spacing: 2) {
                Text(msg.content)
                    .font(.system(size: 15))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 9)
                    .background(msg.isMine
                                ? AnyShapeStyle(LinearGradient(colors: [.indigo, .purple],
                                                               startPoint: .leading, endPoint: .trailing))
                                : AnyShapeStyle(.ultraThinMaterial))
                    .foregroundStyle(msg.isMine ? .white : .primary)
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                Text(shortTime(msg.created_at))
                    .font(.caption2).foregroundStyle(.tertiary)
            }
            if !msg.isMine { Spacer(minLength: 50) }
        }
    }
}
