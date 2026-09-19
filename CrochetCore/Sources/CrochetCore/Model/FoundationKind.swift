/// 作り目（domain-spec 33）。
///
/// 「作り目」の英語は foundation だが、Apple の標準ライブラリ Foundation と名前が衝突するため
/// FoundationKind としている。
public enum FoundationKind: Hashable, Sendable {
    /// わの作り目
    case magicRing
    /// 鎖の作り目。`stitchCount` は「1段目に編む目数 n」。
    /// 実際に編む鎖の目数は保存せず、立ち上がりの鎖の目数から計算して表示する（domain-spec 33）
    case chain(stitchCount: Int)
}

// MARK: - JSON 変換
// {"type":"magicRing"} または {"type":"chain","stitchCount":20} の形にする。

extension FoundationKind: Codable {
    private enum CodingKeys: String, CodingKey {
        case type, stitchCount
    }

    private enum TypeName: String, Codable {
        case magicRing, chain
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        switch try container.decode(TypeName.self, forKey: .type) {
        case .magicRing:
            self = .magicRing
        case .chain:
            self = .chain(stitchCount: try container.decode(Int.self, forKey: .stitchCount))
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .magicRing:
            try container.encode(TypeName.magicRing, forKey: .type)
        case .chain(let stitchCount):
            try container.encode(TypeName.chain, forKey: .type)
            try container.encode(stitchCount, forKey: .stitchCount)
        }
    }
}
