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
    /// 鎖を輪にした作り目。`chainCount` は「輪にする鎖の目数」そのもの。
    /// 1段目はこの輪の中に束に編み入れるので、何目でも編み入れられる（domain-spec 33）
    case chainRing(chainCount: Int)
}

// MARK: - JSON 変換
// {"type":"magicRing"}、{"type":"chain","stitchCount":20}、{"type":"chainRing","chainCount":6} の形にする。

extension FoundationKind: Codable {
    private enum CodingKeys: String, CodingKey {
        case type, stitchCount, chainCount
    }

    private enum TypeName: String, Codable {
        case magicRing, chain, chainRing
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        switch try container.decode(TypeName.self, forKey: .type) {
        case .magicRing:
            self = .magicRing
        case .chain:
            let stitchCount = try container.decode(Int.self, forKey: .stitchCount)
            guard stitchCount >= 1 else {
                throw DecodingError.dataCorruptedError(
                    forKey: .stitchCount, in: container,
                    debugDescription: "鎖の作り目の目数は 1 以上で保存されます（読み込んだ値：\(stitchCount)）"
                )
            }
            self = .chain(stitchCount: stitchCount)
        case .chainRing:
            let chainCount = try container.decode(Int.self, forKey: .chainCount)
            guard chainCount >= 1 else {
                throw DecodingError.dataCorruptedError(
                    forKey: .chainCount, in: container,
                    debugDescription: "輪にする鎖の目数は 1 以上で保存されます（読み込んだ値：\(chainCount)）"
                )
            }
            self = .chainRing(chainCount: chainCount)
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
        case .chainRing(let chainCount):
            try container.encode(TypeName.chainRing, forKey: .type)
            try container.encode(chainCount, forKey: .chainCount)
        }
    }
}
