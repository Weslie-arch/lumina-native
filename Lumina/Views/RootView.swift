import SwiftUI

struct RootView: View {
    @EnvironmentObject var state: AppState

    var body: some View {
        Group {
            if state.booting {
                BootView()
            } else if state.signedIn {
                mainTabs
            } else {
                AuthView()
            }
        }
        .animation(.easeOut(duration: 0.25), value: state.signedIn)
        .animation(.easeOut(duration: 0.25), value: state.booting)
    }

    /// iOS 26 上 TabView 会自动呈现官方液态玻璃底栏，
    /// 低版本用毛玻璃兜底 —— 两种情况下都是同一个 TabView，不用分支。
    private var mainTabs: some View {
        TabView {
            HomeView()
                .tabItem { Label("主页", systemImage: "gauge.with.dots.needle.67percent") }
            ChatListView()
                .tabItem { Label("聊天", systemImage: "bubble.left.and.bubble.right") }
            MeView()
                .tabItem { Label("我", systemImage: "person.crop.circle") }
        }
        .tint(.indigo)
        .onAppear { state.startActivity() }
    }
}

struct BootView: View {
    var body: some View {
        ZStack {
            AppBackground()
            VStack(spacing: 14) {
                ProgressView().controlSize(.large)
                Text("正在恢复登录")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .ignoresSafeArea()
    }
}

/// 整个 App 共用的渐变光斑背景
struct AppBackground: View {
    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(.systemGroupedBackground), Color(.systemBackground)],
                           startPoint: .top, endPoint: .bottom)
            Circle().fill(Color.indigo.opacity(0.28)).frame(width: 320, height: 320)
                .blur(radius: 90).offset(x: -110, y: -260)
            Circle().fill(Color.purple.opacity(0.24)).frame(width: 300, height: 300)
                .blur(radius: 90).offset(x: 130, y: -160)
            Circle().fill(Color.teal.opacity(0.18)).frame(width: 320, height: 320)
                .blur(radius: 100).offset(x: 40, y: 300)
        }
        .ignoresSafeArea()
    }
}
