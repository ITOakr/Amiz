import Foundation

/// 糸の表示色（domain-spec 29）。SwiftUI に依存しないよう RGB（0〜1）で持ち、JSON では "#RRGGBB" にする
public struct YarnColor: Hashable, Sendable, Codable {
    public var red: Double
    public var green: Double
    public var blue: Double

    public init(red: Double, green: Double, blue: Double) {
        self.red = min(max(red, 0), 1)
        self.green = min(max(green, 0), 1)
        self.blue = min(max(blue, 0), 1)
    }

    /// "#RRGGBB"（先頭の # はなくてもよい）。読めなければ nil
    public init?(hex: String) {
        var text = hex.trimmingCharacters(in: .whitespaces)
        if text.hasPrefix("#") { text.removeFirst() }
        guard text.count == 6, let value = UInt32(text, radix: 16) else { return nil }
        self.init(
            red: Double((value >> 16) & 0xFF) / 255,
            green: Double((value >> 8) & 0xFF) / 255,
            blue: Double(value & 0xFF) / 255
        )
    }

    /// "#RRGGBB"
    public var hexString: String {
        String(format: "#%02X%02X%02X", Int((red * 255).rounded()), Int((green * 255).rounded()), Int((blue * 255).rounded()))
    }

    /// 明るさ（0〜1）。白など背景に近い色の判定に使う（domain-spec 30）
    public var luminance: Double {
        0.2126 * red + 0.7152 * green + 0.0722 * blue
    }

    /// 白い背景と見分けにくい明るい色か（輪郭を付ける対象）
    public var isLight: Bool {
        luminance > 0.8
    }

    public init(from decoder: Decoder) throws {
        let text = try decoder.singleValueContainer().decode(String.self)
        guard let color = YarnColor(hex: text) else {
            throw DecodingError.dataCorrupted(.init(codingPath: decoder.codingPath, debugDescription: "色の形式が不正です: \(text)"))
        }
        self = color
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(hexString)
    }
}

/// 作品で使う糸（domain-spec 29）。表示色・名前・メモ（品番など、任意）
public struct Yarn: Identifiable, Hashable, Sendable, Codable {
    public let id: UUID
    public var name: String
    public var color: YarnColor
    public var memo: String

    public init(id: UUID = UUID(), name: String, color: YarnColor, memo: String = "") {
        self.id = id
        self.name = name
        self.color = color
        self.memo = memo
    }

    /// 糸リストが空のときに使う糸（生成り）。古いデータ（色なし）はこの色で表示する
    public static let fallback = Yarn(
        id: UUID(uuidString: "00000000-0000-0000-0000-00000000F1B0")!,
        name: "メイン", color: YarnColor(hex: "#EDE3D1")!
    )

    private enum CodingKeys: String, CodingKey {
        case id, name, color, memo
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        color = try container.decode(YarnColor.self, forKey: .color)
        memo = try container.decodeIfPresent(String.self, forKey: .memo) ?? ""
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(color, forKey: .color)
        if !memo.isEmpty { try container.encode(memo, forKey: .memo) }
    }
}
