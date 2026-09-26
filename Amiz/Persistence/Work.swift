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
    /// 一覧のサムネイル（図を小さく描いた PNG。保存時に作る）
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

    /// 保存や読み込みが失敗したときの理由（画面で伝えるために持つ）
    enum StorageError: LocalizedError {
        /// 編み図の JSON が壊れていて読めない
        case cannotReadPattern
        /// 編み図を JSON にできない
        case cannotEncodePattern
        /// 保存先に書き込めない（容量不足など）
        case cannotWrite(underlying: String)

        var errorDescription: String? {
            switch self {
            case .cannotReadPattern: "この作品の編み図を読み込めませんでした。"
            case .cannotEncodePattern: "編み図を保存できる形にできませんでした。"
            case .cannotWrite: "保存できませんでした。端末の空き容量を確認してください。"
            }
        }
    }

    /// 編み方
    var method: WorkingMethod {
        WorkingMethod(rawValue: methodRawValue) ?? .joinedRounds
    }

    /// 編み図を JSON から読み込む。壊れていれば `StorageError.cannotReadPattern`。
    /// **読めないときに空の編み図で開いてはいけない**（自動保存で元のデータを上書きしてしまうため。AMIZ-68）
    func loadPattern() throws -> Pattern {
        do {
            return try Pattern(jsonData: patternData)
        } catch {
            throw StorageError.cannotReadPattern
        }
    }

    /// 編み図を保存する（更新日も進める）。すぐにディスクへ書き込む。`thumbnail` を渡せばサムネイルも更新する。
    /// 失敗したら投げる（呼び出し側が画面で伝える）
    func save(pattern: Pattern, thumbnail: Data? = nil) throws {
        guard let data = try? pattern.jsonData() else { throw StorageError.cannotEncodePattern }
        patternData = data
        methodRawValue = pattern.method.rawValue
        if let thumbnail { self.thumbnail = thumbnail }
        updatedAt = Date()
        do {
            try modelContext?.save()
        } catch {
            throw StorageError.cannotWrite(underlying: error.localizedDescription)
        }
    }
}
