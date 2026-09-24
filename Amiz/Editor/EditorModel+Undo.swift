import Foundation
import Observation
import CrochetCore

/// `EditorModel` の元に戻す／やり直しと、編み図の書き換え（tech-spec 9）。
///
/// 状態そのものは `EditorModel.swift` が持ち、ここには操作だけを置く（AMIZ-71）
extension EditorModel {
    func undo() {
        guard let previous = undoStack.popLast() else { return }
        redoStack.append(pattern)
        replacePattern(with: previous)
    }

    func redo() {
        guard let next = redoStack.popLast() else { return }
        undoStack.append(pattern)
        replacePattern(with: next)
    }

    /// 編み図を変更する。変更前のコピーを履歴に積み、やり直しの履歴は捨てる
}
