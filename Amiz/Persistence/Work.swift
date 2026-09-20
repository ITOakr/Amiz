import Foundation
import SwiftData
import CrochetCore

/// 保存する「作品」（tech-spec 6）。Rails のモデルに近い。
///
/// 編み図本体は細かいテーブルに分けず、`Pattern` を JSON にした `Data` を1つ持つ。
/// 目数や図の座標は保存せず、開くたびに `Pattern` から計算する（tech-spec 5-1）。
/// 将来の iCloud 同期のため、すべてのプロパティに初期値を持たせ、一意制約は使わない。
@Model
final class Work {
    /// 作品名
    var name: String = ""
    /// 編み方（一覧のカードに出すため、JSON を読まずに済むよう別に持つ）
    var methodRawValue: String = WorkingMethod.joinedRounds.rawValue
    var createdAt: Date = Date()
    var updatedAt: Date = Date()
    /// 一覧のサムネイル（フェーズ10で生成する。それまで nil）
    var thumbnail: Data?
    /// 編み図本体（`Pattern` の JSON）
    var patternData: Data = Data()

    init(name: String, pattern: Pattern) {
        self.name = name
        self.methodRawValue = pattern.method.rawValue
        self.createdAt = Date()
        self.updatedAt = Date()
        self.patternData = (try? pattern.jsonData()) ?? Data()
    }

    /// 編み方
    var method: WorkingMethod {
        WorkingMethod(rawValue: methodRawValue) ?? .joinedRounds
    }

    /// 編み図を JSON から読み込む。壊れていれば nil
    func loadPattern() -> Pattern? {
        try? Pattern(jsonData: patternData)
    }

    /// 編み図を保存する（更新日も進める）。すぐにディスクへ書き込む
    func save(pattern: Pattern) {
        guard let data = try? pattern.jsonData() else { return }
        patternData = data
        methodRawValue = pattern.method.rawValue
        updatedAt = Date()
        try? modelContext?.save()
    }
}
