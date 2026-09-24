import Foundation
import Observation
import CrochetCore

/// `EditorModel` の目の選択とその編集（ui-spec U15）。
///
/// 状態そのものは `EditorModel.swift` が持ち、ここには操作だけを置く（AMIZ-71）
extension EditorModel {
    /// 目を選ぶ。同じ目をもう一度選ぶと解除
    func select(_ ref: StitchRef?) {
        guard !isColorEditing else { return }
        selection = selection == ref ? nil : ref
        modifier = .none
    }

    func clearSelection() {
        selection = nil
    }

    /// 選択中の目の図上の位置（強調表示に使う）
    var selectedStitch: LaidOutStitch? {
        selection.flatMap { layout.stitch(for: $0) }
    }

    /// 選択中の操作の場所
    var selectedLocation: PatternInput.StepLocation? {
        selection.flatMap { PatternInput.locate($0, in: pattern) }
    }

    /// 選択中の操作
    var selectedStep: Step? {
        selectedLocation.flatMap { PatternInput.step(at: $0, in: pattern) }
    }

    /// 選択中の目が繰り返しの中（または繰り返しそのもの）か
    var selectionIsInRepeat: Bool {
        guard let location = selectedLocation else { return false }
        if location.isInsideRepeat { return true }
        if case .repeatGroup = pattern.rows[location.rowIndex].steps[location.stepIndex].kind { return true }
        return false
    }

    /// 選択中の目が立ち上がりなら、その鎖の目数
    var selectedTurningChainCount: Int? {
        if case .turningChain(let chains, _) = selectedStep?.kind { chains } else { nil }
    }

    /// 選択中の目が立ち上がりなら、1目と数えるか
    var selectedTurningChainCounted: Bool? {
        if case .turningChain(_, let counted) = selectedStep?.kind { counted } else { nil }
    }

    /// 選択中の目の表記と段番号（「細編み（3段目）」）
    var selectionDescription: String? {
        guard let location = selectedLocation, let step = selectedStep else { return nil }
        return "\(StitchTableFormatter.label(for: step))（\(location.rowIndex + 1)段目）"
    }

    /// 選択した目を編集する。過去の段で目数が変わり上に段があれば、確認待ち（7-1）にする
    func request(_ edit: SelectionEdit) {
        guard let ref = selection, let location = selectedLocation else { return }

        // まず編集後の段を作る
        var edited = pattern
        let applied: Bool
        switch edit {
        case .changeKind(let kind):
            applied = PatternInput.changeStitchKind(at: ref, to: kind, in: &edited)
        case .delete:
            applied = PatternInput.deleteStep(at: ref, in: &edited)
        case .unwrapRepeat:
            applied = PatternInput.unwrapRepeat(containing: ref, in: &edited)
        case .setTurningChain(let chains):
            // 数えるかは設定に従う。「毎回選択」のときは今の値のまま（隣のメニューで切り替えられる）
            let counted = turningChainCounting.resolve(chains: chains) ?? selectedTurningChainCounted
            applied = PatternInput.setTurningChain(chains: chains, counted: counted, rowID: ref.rowID, in: &edited)
        case .setTurningChainCounted(let counted):
            applied = PatternInput.setTurningChainCounted(counted, rowID: ref.rowID, in: &edited)
        }
        guard applied else { return }

        let editedRow = edited.rows[location.rowIndex]
        guard let impact = PatternEditor.impact(of: .replace(rowIndex: location.rowIndex, with: editedRow), on: pattern) else { return }
        let keepsSelection: Bool = switch edit {
        case .changeKind, .setTurningChain, .setTurningChainCounted: true
        case .delete, .unwrapRepeat: false
        }

        if impact.needsConfirmation {
            pendingConfirmation = PendingConfirmation(impact: impact, edit: .replace(rowIndex: location.rowIndex, with: editedRow))
        } else {
            mutate { $0 = edited }
            if !keepsSelection { selection = nil }
        }
    }

    /// 確認（7-1）の答え：上の段を残す（true）／ほどく（false）
    func resolveConfirmation(keepingRowsAbove: Bool) {
        guard let pending = pendingConfirmation else { return }
        pendingConfirmation = nil
        let edit = pending.edit
        editingSession = nil
        mutate { pattern in
            pattern = keepingRowsAbove
                ? PatternEditor.applyKeepingRowsAbove(edit, to: pattern)
                : PatternEditor.applyUnravelingRowsAbove(edit, to: pattern)
            // ほどいて最後の段が閉じた段になったら、続きを入力する空の段を足す
            PatternInput.ensureOpenRow(in: &pattern)
        }
        recompute()
        selection = nil
    }

    /// 確認（7-1）をキャンセル
    func cancelConfirmation() {
        pendingConfirmation = nil
    }
}
