import Foundation
import ActivityKit

/// 实时活动的属性定义。
/// 这个文件同时编译进主 App 和 Widget Extension —— 两边必须是同一个类型，
/// 所以放在 Lumina/LiveActivity/ 下，两个 target 的 sources 都包含它。
public struct LuminaAttributes: ActivityAttributes {

    /// 会变的部分（锁屏和灵动岛上刷新的内容）
    public struct ContentState: Codable, Hashable {
        public var status: String      // 在线 / 同步中 / 空闲 / 失败
        public var detail: String      // 一句话说明
        public var unread: Int         // 未读会话数
        public var pending: Int        // 待执行指令数
        public var updatedAt: Date

        public init(status: String, detail: String, unread: Int, pending: Int, updatedAt: Date) {
            self.status = status
            self.detail = detail
            self.unread = unread
            self.pending = pending
            self.updatedAt = updatedAt
        }
    }

    /// 固定不变的部分
    public var title: String = "Lumina"

    public init() {}
}
