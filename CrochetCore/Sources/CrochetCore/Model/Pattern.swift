import Foundation

/// 編み図全体。作品1つにつき1つ持ち、JSON にして保存する（tech-spec 5・6）。
///
/// 作品名や更新日などの「作品」の情報はここには持たない（アプリ側の保存用モデルが持つ）。
public struct Pattern: Hashable, Sendable {
    /// 現在のデータ形式のバージョン。データ構造を変えたときに上げる（tech-spec 5-4）。
    /// 1：初期形式。2：糸リストと操作ごとの糸（domain-spec 27・29）
    public static let currentSchemaVersion = 2

    /// このデータが書かれたときのデータ形式のバージョン
    public var schemaVersion: Int
    /// 編み方
    public var method: WorkingMethod
    /// 作り目
    public var foundation: FoundationKind
    /// 段。作り目は含めず、作り目に編み入れる段が `rows[0]`（1段目）
    public var rows: [Row]
    /// 糸リスト（domain-spec 29）。先頭が「既定の糸」で、糸を指定していない操作はこの糸になる。空なら `Yarn.fallback`
    public var yarns: [Yarn]
    /// 今持っている糸（ui-spec U17）。nil なら既定の糸。新しく編む目はこの糸になる
    public var currentYarnID: UUID?

    public init(
        method: WorkingMethod,
        foundation: FoundationKind,
        rows: [Row] = [],
        yarns: [Yarn] = [],
        currentYarnID: UUID? = nil,
        schemaVersion: Int = Pattern.currentSchemaVersion
    ) {
        self.schemaVersion = schemaVersion
        self.method = method
        self.foundation = foundation
        self.rows = rows
        self.yarns = yarns
        self.currentYarnID = currentYarnID
    }

    // MARK: - 糸

    /// 既定の糸（糸リストの先頭。空なら生成りの仮の糸）
    public var defaultYarn: Yarn {
        yarns.first ?? Yarn.fallback
    }

    /// 糸 ID から糸を引く。nil や、リストにない ID（削除した糸）は既定の糸
    public func yarn(for id: UUID?) -> Yarn {
        guard let id, let yarn = yarns.first(where: { $0.id == id }) else { return defaultYarn }
        return yarn
    }

    /// 糸 ID を「実際に使われる糸」の ID にそろえる（nil・削除済みは既定の糸の ID）。色替えの比較に使う
    public func resolvedYarnID(_ id: UUID?) -> UUID {
        yarn(for: id).id
    }

    /// 今持っている糸
    public var currentYarn: Yarn {
        yarn(for: currentYarnID)
    }
}

// MARK: - Codable
// 糸のキー（yarns・currentYarnID）は形式 2 で増えた。無い古いデータは糸なし（既定の糸で表示）として読む

extension Pattern: Codable {
    private enum CodingKeys: String, CodingKey {
        case schemaVersion, method, foundation, rows, yarns, currentYarnID
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        schemaVersion = try container.decode(Int.self, forKey: .schemaVersion)
        method = try container.decode(WorkingMethod.self, forKey: .method)
        foundation = try container.decode(FoundationKind.self, forKey: .foundation)
        rows = try container.decode([Row].self, forKey: .rows)
        yarns = try container.decodeIfPresent([Yarn].self, forKey: .yarns) ?? []
        currentYarnID = try container.decodeIfPresent(UUID.self, forKey: .currentYarnID)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        // 書き出すときは常に今の形式
        try container.encode(Pattern.currentSchemaVersion, forKey: .schemaVersion)
        try container.encode(method, forKey: .method)
        try container.encode(foundation, forKey: .foundation)
        try container.encode(rows, forKey: .rows)
        try container.encode(yarns, forKey: .yarns)
        try container.encodeIfPresent(currentYarnID, forKey: .currentYarnID)
    }
}

// MARK: - JSON との変換
// 保存（tech-spec 6）はこの2つを通して行う。キーを並べ替えて出力するのは、
// 同じ内容なら同じバイト列になり、差分の確認やテストがしやすいため。

extension Pattern {
    /// JSON の `Data` にする
    public func jsonData() throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        return try encoder.encode(self)
    }

    /// JSON の `Data` から読み込む
    public init(jsonData: Data) throws {
        self = try JSONDecoder().decode(Pattern.self, from: jsonData)
    }
}
