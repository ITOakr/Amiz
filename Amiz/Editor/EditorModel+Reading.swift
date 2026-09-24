import Foundation
import Observation
import CrochetCore

/// `EditorModel` の画面が読む値（目数表の行・警告・次に拾う目など）。
///
/// 状態そのものは `EditorModel.swift` が持ち、ここには操作だけを置く（AMIZ-71）
extension EditorModel {
    /// 入力中の段の位置（0始まり）。まだ段がなければ nil
    var currentRowIndex: Int? {
        pattern.currentRowIndex
    }

    /// 入力中の段の展開結果
    var currentRow: RowExpansion? {
        currentRowIndex.map { expansion.rows[$0] }
    }

    /// 目数の警告。入力中の段は対象外（domain-spec 23）
    var warnings: [RowWarning] {
        expansion.warnings(excludingRowAt: currentRowIndex)
    }

    /// 色替えの位置（domain-spec 31）
    var yarnChanges: [YarnChange] {
        expansion.yarnChanges(in: displayedPattern)
    }
}
