import Foundation
import Observation
import CrochetCore

/// `EditorModel` の過去の段の編集（U16）と段の削除・複製（U22）。
///
/// 状態そのものは `EditorModel.swift` が持ち、ここには操作だけを置く（AMIZ-71）
extension EditorModel {
    /// 段の編集を始める。入力中の段（最後の段）は対象外
    func beginEditingRow(at index: Int) {
        guard !isColorEditing, let current = currentRowIndex, index < current, pattern.rows.indices.contains(index) else { return }
        selection = nil
        modifier = .none
        let row = pattern.rows[index]
        // 入力位置は段を閉じる引き抜きの手前（引き抜きの後ろには入れない）
        let cursor = if case .closeRound = row.steps.last?.kind { row.steps.count - 1 } else { row.steps.count }
        editingSession = RowEditingSession(rowIndex: index, row: row, cursor: cursor, repeatStartIndex: nil)
        recompute()
    }

    /// 入力位置を動かす（操作の間の位置。0 なら先頭）
    func moveCursor(to index: Int) {
        guard var session = editingSession else { return }
        var upper = session.row.steps.count
        if case .closeRound = session.row.steps.last?.kind { upper -= 1 }
        session.cursor = min(max(index, 0), upper)
        editingSession = session
    }

    /// 「完了」：目数が変わり上に段があれば確認（7-1）、そうでなければそのまま反映
    func finishEditingRow() {
        guard let session = editingSession else { return }
        let edit = RowEdit.replace(rowIndex: session.rowIndex, with: session.row)
        guard let impact = PatternEditor.impact(of: edit, on: pattern) else { return }
        if impact.needsConfirmation {
            pendingConfirmation = PendingConfirmation(impact: impact, edit: edit)
        } else {
            editingSession = nil
            mutate { $0 = PatternEditor.applyKeepingRowsAbove(edit, to: $0) }
            recompute()
        }
    }

    /// 編集をやめて元に戻す
    func cancelEditingRow() {
        editingSession = nil
        modifier = .none
        recompute()
    }

    /// 作業用のコピーを変更して表示を更新する
    func editRow(_ change: (inout RowEditingSession, WorkingMethod) -> Void) {
        guard var session = editingSession else { return }
        change(&session, pattern.method)
        editingSession = session
        recompute()
    }

    // MARK: - 段の削除・複製（ui-spec U22、domain-spec 18・25）

    /// 段を削除する。上に段があれば確認（7-1）
    func requestDeleteRow(at index: Int) {
        requestRowEdit(.delete(rowIndex: index))
    }

    /// 段を複製し、その段の直後に times 段挿入する。上に段があれば確認（7-1）
    func requestDuplicateRow(at index: Int, times: Int) {
        guard times > 0 else { return }
        requestRowEdit(.duplicate(rowIndex: index, times: times))
    }

    private func requestRowEdit(_ edit: RowEdit) {
        guard pattern.rows.indices.contains(edit.rowIndex) else { return }
        selection = nil
        editingSession = nil
        guard let impact = PatternEditor.impact(of: edit, on: pattern) else { return }
        if impact.needsConfirmation {
            pendingConfirmation = PendingConfirmation(impact: impact, edit: edit)
        } else {
            mutate { pattern in
                pattern = PatternEditor.applyKeepingRowsAbove(edit, to: pattern)
                PatternInput.ensureOpenRow(in: &pattern)
            }
            recompute()
        }
    }
}
