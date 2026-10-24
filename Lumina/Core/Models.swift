import Foundation

struct Conversation: Identifiable, Codable {
    var id: Int = 0
    var name: String = ""
    var last_message: String?
    var last_time: String?
    var unread: Int?
    var external_key: String?
    var updated_at: String?

    enum C: String, CodingKey {
        case id, name, last_message, last_time, unread, external_key, updated_at
    }
    init() {}
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: C.self)
        id = try c.decodeIfPresent(Int.self, forKey: .id) ?? 0
        name = try c.decodeIfPresent(String.self, forKey: .name) ?? ""
        last_message = try c.decodeIfPresent(String.self, forKey: .last_message)
        last_time = try c.decodeIfPresent(String.self, forKey: .last_time)
        unread = try c.decodeIfPresent(Int.self, forKey: .unread)
        external_key = try c.decodeIfPresent(String.self, forKey: .external_key)
        updated_at = try c.decodeIfPresent(String.self, forKey: .updated_at)
    }
}

struct ChatMessage: Identifiable, Codable {
    var id: Int = 0
    var conversation_id: Int = 0
    var sender: String = ""
    var content: String = ""
    var msg_type: String?
    var created_at: String?

    enum C: String, CodingKey {
        case id, conversation_id, sender, content, msg_type, created_at
    }
    init() {}
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: C.self)
        id = try c.decodeIfPresent(Int.self, forKey: .id) ?? 0
        conversation_id = try c.decodeIfPresent(Int.self, forKey: .conversation_id) ?? 0
        sender = try c.decodeIfPresent(String.self, forKey: .sender) ?? ""
        content = try c.decodeIfPresent(String.self, forKey: .content) ?? ""
        msg_type = try c.decodeIfPresent(String.self, forKey: .msg_type)
        created_at = try c.decodeIfPresent(String.self, forKey: .created_at)
    }

    var isMine: Bool { sender == "me" }
}

struct Device: Identifiable, Codable {
    var id: Int = 0
    var code: String = ""
    var name: String?
    var status: String?
    var last_seen: String?
    var last_sync: String?
    var last_error: String?

    enum C: String, CodingKey {
        case id, code, name, status, last_seen, last_sync, last_error
    }
    init() {}
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: C.self)
        id = try c.decodeIfPresent(Int.self, forKey: .id) ?? 0
        code = try c.decodeIfPresent(String.self, forKey: .code) ?? ""
        name = try c.decodeIfPresent(String.self, forKey: .name)
        status = try c.decodeIfPresent(String.self, forKey: .status)
        last_seen = try c.decodeIfPresent(String.self, forKey: .last_seen)
        last_sync = try c.decodeIfPresent(String.self, forKey: .last_sync)
        last_error = try c.decodeIfPresent(String.self, forKey: .last_error)
    }
}

struct Command: Identifiable, Codable {
    var id: Int = 0
    var cmd_type: String = ""
    var status: String?
    var payload: [String: Any]?
    var created_at: String?

    enum C: String, CodingKey { case id, cmd_type, status, payload, created_at }
    init() {}
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: C.self)
        id = try c.decodeIfPresent(Int.self, forKey: .id) ?? 0
        cmd_type = try c.decodeIfPresent(String.self, forKey: .cmd_type) ?? ""
        status = try c.decodeIfPresent(String.self, forKey: .status)
        created_at = try c.decodeIfPresent(String.self, forKey: .created_at)
        // payload 是 JSONB，形状不固定，用 JSONSerialization 兜住
        if let any = try? c.decode(AnyJSON.self, forKey: .payload) { payload = any.value }
    }
    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: C.self)
        try c.encode(id, forKey: .id)
        try c.encode(cmd_type, forKey: .cmd_type)
        try c.encodeIfPresent(status, forKey: .status)
        try c.encodeIfPresent(created_at, forKey: .created_at)
    }
}

/// 把任意 JSON 塞进 Codable 体系
struct AnyJSON: Codable {
    let value: [String: Any]?
    init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        if let d = try? c.decode([String: AnyCodable].self) {
            var out: [String: Any] = [:]
            for (k, v) in d { out[k] = v.value }
            value = out
        } else { value = nil }
    }
    func encode(to encoder: Encoder) throws {}
}

struct AnyCodable: Codable {
    let value: Any
    init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        if let b = try? c.decode(Bool.self) { value = b }
        else if let n = try? c.decode(Double.self) { value = n }
        else if let s = try? c.decode(String.self) { value = s }
        else if let a = try? c.decode([AnyCodable].self) { value = a.map { $0.value } }
        else if let d = try? c.decode([String: AnyCodable].self) {
            var o: [String: Any] = [:]
            for (k, v) in d { o[k] = v.value }
            value = o
        } else { value = "" }
    }
    func encode(to encoder: Encoder) throws {}
}

struct Profile: Codable {
    var id: Int?
    var nickname: String = ""
    var avatar_kind: String = "letter"   // letter | emoji | image
    var avatar_value: String = ""        // 颜色
    var avatar_emoji: String = ""
    var avatar_image: String = ""        // base64

    enum C: String, CodingKey {
        case id, nickname, avatar_kind, avatar_value, avatar_emoji, avatar_image
    }
    init() {}
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: C.self)
        id = try c.decodeIfPresent(Int.self, forKey: .id)
        nickname = try c.decodeIfPresent(String.self, forKey: .nickname) ?? ""
        avatar_kind = try c.decodeIfPresent(String.self, forKey: .avatar_kind) ?? "letter"
        avatar_value = try c.decodeIfPresent(String.self, forKey: .avatar_value) ?? ""
        avatar_emoji = try c.decodeIfPresent(String.self, forKey: .avatar_emoji) ?? ""
        avatar_image = try c.decodeIfPresent(String.self, forKey: .avatar_image) ?? ""
    }
    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: C.self)
        try c.encodeIfPresent(id, forKey: .id)
        try c.encode(nickname, forKey: .nickname)
        try c.encode(avatar_kind, forKey: .avatar_kind)
        try c.encode(avatar_value, forKey: .avatar_value)
        try c.encode(avatar_emoji, forKey: .avatar_emoji)
        try c.encode(avatar_image, forKey: .avatar_image)
    }
}
