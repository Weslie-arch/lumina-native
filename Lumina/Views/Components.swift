import SwiftUI

/// 头像：支持图片 / 表情 / 首字母三种
struct AvatarView: View {
    var profile: Profile
    var fallback: String = "L"
    var size: CGFloat = 52

    private var letter: String {
        let n = profile.nickname.trimmingCharacters(in: .whitespaces)
        return String((n.isEmpty ? fallback : n).prefix(1)).uppercased()
    }
    private var color: Color {
        if profile.avatar_value.isEmpty { return .indigo }
        return Color(hex: profile.avatar_value) ?? .indigo
    }

    var body: some View {
        ZStack {
            if profile.avatar_kind == "image", !profile.avatar_image.isEmpty,
               let img = UIImage.fromBase64(profile.avatar_image) {
                Image(uiImage: img).resizable().scaledToFill()
            } else {
                LinearGradient(colors: [color, .purple], startPoint: .topLeading, endPoint: .bottomTrailing)
                if profile.avatar_kind == "emoji", !profile.avatar_emoji.isEmpty {
                    Text(profile.avatar_emoji).font(.system(size: size * 0.5))
                } else {
                    Text(letter)
                        .font(.system(size: size * 0.42, weight: .semibold))
                        .foregroundStyle(.white)
                }
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: size * 0.32, style: .continuous))
    }
}

/// 玻璃卡片容器
struct GlassCard<Content: View>: View {
    @ViewBuilder var content: Content
    var body: some View {
        content
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.28), lineWidth: 1)
            )
    }
}

struct StatBox: View {
    var n: String
    var label: String
    var body: some View {
        VStack(spacing: 4) {
            Text(n).font(.system(size: 22, weight: .bold, design: .rounded))
            Text(label).font(.caption2).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

extension Color {
    init?(hex: String) {
        var s = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        s = s.replacingOccurrences(of: "#", with: "")
        guard s.count == 6, let v = UInt64(s, radix: 16) else { return nil }
        let r = Double((v >> 16) & 0xFF) / 255
        let g = Double((v >> 8) & 0xFF) / 255
        let b = Double(v & 0xFF) / 255
        self.init(red: r, green: g, blue: b)
    }
}

extension UIImage {
    static func fromBase64(_ s: String) -> UIImage? {
        let pure = s.contains(",") ? String(s.split(separator: ",").last ?? "") : s
        guard let d = Data(base64Encoded: pure, options: .ignoreUnknownCharacters) else { return nil }
        return UIImage(data: d)
    }

    /// 居中裁正方 + 压到 300，避免头像把数据库撑爆
    func avatarJPEG() -> String? {
        let side = min(size.width, size.height)
        guard let cg = cgImage?.cropping(to: CGRect(
            x: (size.width - side) / 2, y: (size.height - side) / 2,
            width: side, height: side)) else { return nil }
        let small = UIImage(cgImage: cg, scale: 1, orientation: .up)
        UIGraphicsBeginImageContextWithOptions(CGSize(width: 300, height: 300), true, 1)
        UIColor.white.setFill()
        UIRectFill(CGRect(x: 0, y: 0, width: 300, height: 300))
        small.draw(in: CGRect(x: 0, y: 0, width: 300, height: 300))
        let out = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        guard let d = out?.jpegData(compressionQuality: 0.76) else { return nil }
        return "data:image/jpeg;base64," + d.base64EncodedString()
    }
}

/// PostgREST 的时间串 → 显示用短格式
func shortTime(_ s: String?) -> String {
    guard let s, !s.isEmpty else { return "" }
    let f = ISO8601DateFormatter()
    f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    guard let d = f.date(from: s) ?? ISO8601DateFormatter().date(from: s) else {
        return String(s.prefix(5))
    }
    let cal = Calendar.current
    if cal.isDateInToday(d) {
        let c = cal.dateComponents([.hour, .minute], from: d)
        return String(format: "%02d:%02d", c.hour ?? 0, c.minute ?? 0)
    }
    if cal.isDateInYesterday(d) { return "昨天" }
    let c = cal.dateComponents([.month, .day], from: d)
    return "\(c.month ?? 0)/\(c.day ?? 0)"
}

func agoText(_ s: String?) -> String {
    guard let s, !s.isEmpty else { return "从未" }
    let f = ISO8601DateFormatter()
    f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    guard let d = f.date(from: s) ?? ISO8601DateFormatter().date(from: s) else { return "—" }
    let sec = Int(Date().timeIntervalSince(d))
    if sec < 5 { return "刚刚" }
    if sec < 60 { return "\(sec) 秒前" }
    if sec < 3600 { return "\(sec / 60) 分钟前" }
    if sec < 86400 { return "\(sec / 3600) 小时前" }
    return "\(sec / 86400) 天前"
}
