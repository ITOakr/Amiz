import Foundation

/// 編み図全体。作品1つにつき1つ持ち、JSON にして保存する（tech-spec 5・6）。
///
/// 作品名や更新日などの「作品」の情報はここには持たない（アプリ側の保存用モデルが持つ）。
public struct Pattern: Hashable, Sendable, Codable {
    /// 現在のデータ形式のバージョン。データ構造を変えたときに上げる（tech-spec 5-4）
    public static let currentSchemaVersion = 1

    /// このデータが書かれたときのデータ形式のバージョン
    public var schemaVersion: Int
    /// 編み方
    public var method: WorkingMethod
    /// 作り目
    public var foundation: FoundationKind
    /// 段。作り目は含めず、作り目に編み入れる段が `rows[0]`（1段目）
    public var rows: [Row]

    public init(
        method: WorkingMethod,
        foundation: FoundationKind,
        rows: [Row] = [],
        schemaVersion: Int = Pattern.currentSchemaVersion
    ) {
        self.schemaVersion = schemaVersion
        self.method = method
        self.foundation = foundation
        self.rows = rows
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
