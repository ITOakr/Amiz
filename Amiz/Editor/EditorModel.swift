import Observation
import CrochetCore

/// 編集画面の状態（React の store に当たる）。
///
/// 画面はこのオブジェクトを見て描き、ボタンは `press…` を呼ぶ。編み物のルールは CrochetCore の
/// `PatternInput` に任せ、ここでは状態の保持と元に戻す／やり直しだけを扱う（tech-spec 9）。
@Observable
final class EditorModel {
    /// 編み図。変更は必ず `mutate` を通す（元に戻す用のコピーを積むため）
    private(set) var pattern: Pattern
    /// 展開結果。`pattern` が変わるたびに計算し直す（保存はしない。tech-spec 5-1）
    private(set) var expansion: PatternExpansion
    /// 図のレイアウト。`pattern` が変わるたびに計算し直す
    private(set) var layout: ChartLayout
    /// 先に選ぶボタンの状態（状態 S2）
    private(set) var modifier = StitchModifier.none
    /// 「繰り返し開始」を押した位置（入力中の段の操作数）。押していなければ nil
    private(set) var repeatStartIndex: Int?
    /// 立ち上がりの鎖の自動入力（ui-spec 6-3 の設定。画面側が UserDefaults の値を入れる）
    var autoTurningChain = true
    /// 立ち上がりを1目と数えるか（ui-spec 6-3 の設定。画面側が UserDefaults の値を入れる）
    var turningChainCounting = TurningChainCounting.standard
    /// 「毎回選択」で、立ち上がりを数えるかを聞いている最中（ui-spec 7-4）。答えが来るまで目は入れない
    private(set) var pendingTurningChainQuestion: TurningChainQuestion?
    /// 選択中の目（状態 S6。ui-spec U15）
    private(set) var selection: StitchRef?
    /// 確認待ちの修正（ui-spec 7-1）。画面がこれを見てダイアログを出す
    private(set) var pendingConfirmation: PendingConfirmation?
    /// 過去の段を編集中（状態 S4。ui-spec U16）。作業用のコピーに入力し、「完了」で編み図に反映する
    private(set) var editingSession: RowEditingSession?

    /// 過去の段の編集（U16）
    struct RowEditingSession {
        let rowIndex: Int
        /// 作業用のコピー（「完了」までは編み図に反映しない）
        var row: Row
        /// 入力位置（操作の間。0 なら先頭）
        var cursor: Int
        /// 編集中の繰り返し開始の位置
        var repeatStartIndex: Int?
    }

    /// 上の段に影響する修正の確認待ち（ui-spec 7-1）。「上の段を残す」か「ほどく」かで適用の仕方が変わる
    struct PendingConfirmation {
        let impact: EditImpact
        let edit: RowEdit

        /// 7-1 のメッセージ（「2段目の目数が12目から14目に変わりました。3〜5段目に影響があります。」）
        var message: String {
            var text = "\(impact.editedRowNumber)段目"
            switch edit {
            case .replace:
                if let before = impact.countBefore, let after = impact.countAfter {
                    text += "の目数が\(before)目から\(after)目に変わりました。"
                } else {
                    text += "を変更します。"
                }
            case .delete:
                text += "を削除します。"
            case .duplicate(_, let times):
                text += "を\(times)回複製します。"
            }
            if let affected = impact.affectedRowsDescription {
                text += "\(affected)に影響があります。"
            }
            return text
        }
    }

    /// 「立ち上がり鎖3目を1目と数えますか？」の確認待ち（ui-spec 7-4）。答えのあとに続ける操作を覚えておく
    struct TurningChainQuestion {
        enum Action {
            /// 目ボタン（先に選ぶ状態を含む）。立ち上がりを入れてからこの目を入れる
            case stitch(StitchKind, StitchModifier)
            /// 立ち上がりボタン（U23）
            case turningChain
        }

        let chains: Int
        let action: Action

        var message: String {
            "立ち上がり鎖\(chains)目を1目と数えますか？"
        }
    }

    /// 選択した目に対する編集（ui-spec U15）
    enum SelectionEdit {
        case changeKind(StitchKind)
        case delete
        case unwrapRepeat
        case setTurningChain(Int)
        case setTurningChainCounted(Bool)
    }

    private var undoStack: [Pattern] = []
    private var redoStack: [Pattern] = []

    init(pattern: Pattern) {
        self.pattern = pattern
        let expansion = pattern.expanded()
        self.expansion = expansion
        self.layout = pattern.circularLayout(expansion: expansion)
    }

    /// 画面に出す編み図。過去の段を編集中は、その段を作業用のコピーに差し替えたもの
    var displayedPattern: Pattern {
        guard let session = editingSession else { return pattern }
        var preview = pattern
        preview.rows[session.rowIndex] = session.row
        return preview
    }

    /// 今、入力の対象になっている段の位置（編集中ならその段、そうでなければ入力中の段）
    var activeRowIndex: Int? {
        editingSession?.rowIndex ?? currentRowIndex
    }

    /// 今、入力の対象になっている段の展開結果
    var activeRow: RowExpansion? {
        activeRowIndex.map { expansion.rows[$0] }
    }

    /// 新しい作品（わの作り目・輪編み）で始める
    convenience init() {
        self.init(pattern: Pattern(method: .joinedRounds, foundation: .magicRing))
    }

    // MARK: - 画面が読む値

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

    var canUndo: Bool { !undoStack.isEmpty }
    var canRedo: Bool { !redoStack.isEmpty }
    var isRepeating: Bool { (editingSession?.repeatStartIndex ?? repeatStartIndex) != nil }

    /// 入力中の段の操作の列
    var currentRowSteps: [Step] {
        currentRowIndex.map { pattern.rows[$0].steps } ?? []
    }

    /// 直前に編んだ操作（「現在の段」に並べる。ui-spec 5-5）
    func recentSteps(count: Int) -> [Step] {
        Array(currentRowSteps.suffix(count))
    }

    /// 目数表の行（入力中の段を除く。同じ内容の段はまとめる。ui-spec 5-4）
    var finishedTableRows: [StitchTableRow] {
        guard let current = currentRowIndex else { return [] }
        var finished = displayedPattern
        finished.rows.removeLast()
        let finishedExpansion = PatternExpansion(rows: Array(expansion.rows[..<current]))
        return StitchTableFormatter.tableRows(for: finished, expansion: finishedExpansion, warnings: warnings)
    }

    /// 1段分の目数表の行（まとめた行を展開して表示するときに使う）
    func singleTableRow(at index: Int) -> StitchTableRow {
        let shown = displayedPattern
        return StitchTableRow(
            rowNumbers: (index + 1)...(index + 1),
            rowIDs: [shown.rows[index].id],
            instruction: StitchTableFormatter.instruction(for: shown.rows[index], rowIndex: index, in: shown),
            countText: StitchTableFormatter.countText(for: expansion.rows[index]),
            isUnchangedRun: index > 0 && expansion.rows[index].totalCount == expansion.rows[index - 1].totalCount
        )
    }

    /// 段の位置ごとの警告（目数表で引く）
    var warningsByRowIndex: [Int: RowWarning] {
        Dictionary(uniqueKeysWithValues: warnings.map { ($0.rowIndex, $0) })
    }

    /// 作り目の行の文章（「わの作り目」「作り目：鎖21目」）
    var foundationText: String {
        StitchTableFormatter.foundationText(for: pattern)
    }

    /// 次に拾う前段の目（図のハイライト。ui-spec 5-3）。前段がない・使い切った・段がないときは nil
    var nextStitchToPick: LaidOutStitch? {
        guard let index = currentRowIndex, index > 0, let row = currentRow,
              let unpicked = row.unpickedCount, unpicked > 0 else { return nil }
        return layout.countedStitch(rowIndex: index - 1, countedIndex: row.pickedCount)
    }

    /// 「繰り返し終了」で「段の終わりまで」を選べるか
    var canEndRepeatUntilEnd: Bool {
        guard let unit = pendingRepeatUnit else { return false }
        return PatternInput.canRepeatUntilEnd(unit: unit)
    }

    /// 「繰り返し開始」から今までの操作（繰り返し終了の確認に表示する）
    var pendingRepeatUnit: [Step]? {
        if let session = editingSession {
            guard let start = session.repeatStartIndex, start <= session.cursor else { return nil }
            return Array(session.row.steps[start..<session.cursor])
        }
        guard let start = repeatStartIndex, let index = currentRowIndex else { return nil }
        let steps = pattern.rows[index].steps
        guard start <= steps.count else { return nil }
        return Array(steps[start...])
    }

    // MARK: - 目ボタン・先に選ぶボタン

    /// 目ボタン。選択中なら選択した目の種類を変える（U15）。そうでなければ先に選ぶ状態を適用して1操作追加し、状態を解除する。
    /// 立ち上がりが自動で入る目で、設定が「毎回選択」なら、数えるかを聞いてから入れる（7-4）
    func pressStitch(_ kind: StitchKind) {
        if selection != nil {
            modifier = .none
            request(.changeKind(kind))
            return
        }
        var turningChainCounted: Bool?
        if let chains = turningChainToInsert(for: kind) {
            guard let counted = turningChainCounting.resolve(chains: chains) else {
                pendingTurningChainQuestion = TurningChainQuestion(chains: chains, action: .stitch(kind, modifier))
                return
            }
            turningChainCounted = counted
        }
        insertStitch(kind, modifier: modifier, turningChainCounted: turningChainCounted)
    }

    /// 目を入れる（先に選ぶ状態は解除する）。`turningChainCounted` は自動で入る立ち上がりを数えるか
    private func insertStitch(_ kind: StitchKind, modifier: StitchModifier, turningChainCounted: Bool?) {
        self.modifier = .none
        if editingSession != nil {
            editRow { session, method in
                let result = PatternInput.insertStitch(
                    kind, modifier: modifier, at: session.cursor, in: &session.row,
                    method: method, autoTurningChain: autoTurningChain, turningChainCounted: turningChainCounted
                )
                session.cursor = result.stepIndex + 1
                if result.insertedTurningChain, let start = session.repeatStartIndex {
                    session.repeatStartIndex = start + 1
                }
            }
            return
        }
        mutate { pattern in
            let inserted = PatternInput.addStitch(
                kind, modifier: modifier, autoTurningChain: autoTurningChain, turningChainCounted: turningChainCounted, to: &pattern
            )
            // 立ち上がりが先頭に入ると、繰り返し開始の位置が1つ後ろにずれる
            if inserted, let start = repeatStartIndex {
                repeatStartIndex = start + 1
            }
        }
    }

    /// この目を押すと立ち上がりが自動で入るなら、その鎖の目数
    private func turningChainToInsert(for kind: StitchKind) -> Int? {
        if let session = editingSession {
            return PatternInput.turningChainToInsert(for: kind, in: session.row, method: pattern.method, autoTurningChain: autoTurningChain)
        }
        return PatternInput.turningChainToInsert(for: kind, autoTurningChain: autoTurningChain, in: pattern)
    }

    /// 7-4 の答え：数える（true）／数えない（false）。聞いたときの操作を続ける
    func answerTurningChainQuestion(counted: Bool) {
        guard let question = pendingTurningChainQuestion else { return }
        pendingTurningChainQuestion = nil
        switch question.action {
        case .stitch(let kind, let modifier):
            insertStitch(kind, modifier: modifier, turningChainCounted: counted)
        case .turningChain:
            setTurningChain(chains: question.chains, counted: counted)
        }
    }

    /// 7-4 をキャンセル。目は入れない（先に選ぶ状態はそのまま）
    func cancelTurningChainQuestion() {
        pendingTurningChainQuestion = nil
    }

    func toggleIncrease() { modifier.toggleIncrease() }
    func toggleDecrease() { modifier.toggleDecrease() }
    func toggleChainSpace() { modifier.toggleChainSpace() }
    func toggleUntilEnd() { modifier.toggleUntilEnd() }

    /// 「飛ばす」（選択状態にならず、押すたびに1目飛ばす）
    func pressSkip() {
        if editingSession != nil {
            editRow { session, _ in
                PatternInput.insertSkip(at: session.cursor, in: &session.row)
                session.cursor += 1
            }
            return
        }
        mutate { pattern in
            PatternInput.addSkip(to: &pattern)
        }
    }

    /// 「残りは編まない」（段を終えるときの確認 7-2 から呼ぶ）
    func pressLeaveRemaining() {
        mutate { pattern in
            PatternInput.addLeaveRemaining(to: &pattern)
        }
    }

    // MARK: - 段の操作

    /// 「1目削除」。編集中は入力位置の直前を消す
    func pressDeleteLast() {
        modifier = .none
        if editingSession != nil {
            editRow { session, _ in
                if PatternInput.deleteStep(before: session.cursor, in: &session.row) {
                    session.cursor -= 1
                    if let start = session.repeatStartIndex, start > session.cursor {
                        session.repeatStartIndex = nil
                    }
                }
            }
            return
        }
        mutate { pattern in
            PatternInput.deleteLastStep(from: &pattern)
        }
        // 繰り返し開始の位置が段の外に出たら解除
        if let start = repeatStartIndex, let index = currentRowIndex, start > pattern.rows[index].steps.count {
            repeatStartIndex = nil
        }
    }

    /// 「段を終える」を押したときに、前段に拾っていない目が残っていれば その数（確認 7-2 を出す）。なければ nil
    var remainingBeforeFinish: Int? {
        guard let unpicked = currentRow?.unpickedCount, unpicked > 0 else { return nil }
        return unpicked
    }

    /// 前段の目を使い切ったか（ui-spec 5-5「前段を使い切りました」）
    var hasUsedUpPreviousRow: Bool {
        guard let row = currentRow, row.previousCount != nil else { return false }
        return row.unpickedCount == 0
    }

    /// 「段を終える」。残っている前段の目の確認（7-2）は画面側が先に行う。
    /// - Parameter leavingRemaining: 確認で「残りは編まない」を選んだとき true（1回の操作として元に戻せる）
    func pressFinishRow(leavingRemaining: Bool = false) {
        guard editingSession == nil else { return }
        modifier = .none
        repeatStartIndex = nil
        mutate { pattern in
            if leavingRemaining {
                PatternInput.addLeaveRemaining(to: &pattern)
            }
            PatternInput.finishRow(of: &pattern)
        }
    }

    /// 「繰り返し開始」：今の段の操作数を覚える（段がまだなければ 0）。編集中は入力位置を覚える
    func pressBeginRepeat() {
        if editingSession != nil {
            editingSession?.repeatStartIndex = editingSession?.cursor
            return
        }
        repeatStartIndex = pattern.rows.last?.steps.count ?? 0
    }

    /// 「繰り返し終了」。回数を指定してまとめる
    /// - Returns: まとめられたか（単位が空などのときは false で、開始位置は残る）
    @discardableResult
    func pressEndRepeat(count: RepeatCount) -> Bool {
        if let session = editingSession, let start = session.repeatStartIndex {
            var wrapped = false
            editRow { session, _ in
                let before = session.row.steps.count
                wrapped = PatternInput.wrapRepeat(start..<session.cursor, count: count, in: &session.row)
                if wrapped {
                    session.cursor -= before - session.row.steps.count
                    session.repeatStartIndex = nil
                }
            }
            return wrapped
        }
        guard let start = repeatStartIndex else { return false }
        var wrapped = false
        mutate { pattern in
            wrapped = PatternInput.wrapRepeat(from: start, count: count, in: &pattern)
        }
        if wrapped {
            repeatStartIndex = nil
        }
        return wrapped
    }

    /// 繰り返しの入力をやめる（まとめずに開始位置を忘れる）
    func cancelRepeat() {
        repeatStartIndex = nil
        editingSession?.repeatStartIndex = nil
    }

    /// 「立ち上がり」ボタン（U23）。設定が「毎回選択」なら数えるかを聞いてから入れる（7-4）
    func pressTurningChain(chains: Int) {
        guard let counted = turningChainCounting.resolve(chains: chains) else {
            pendingTurningChainQuestion = TurningChainQuestion(chains: chains, action: .turningChain)
            return
        }
        setTurningChain(chains: chains, counted: counted)
    }

    private func setTurningChain(chains: Int, counted: Bool) {
        mutate { pattern in
            let inserted = PatternInput.setTurningChain(chains: chains, counted: counted, in: &pattern)
            if inserted, let start = repeatStartIndex {
                repeatStartIndex = start + 1
            }
        }
    }

    // MARK: - 過去の段の編集（ui-spec U16）

    /// 段の編集を始める。入力中の段（最後の段）は対象外
    func beginEditingRow(at index: Int) {
        guard let current = currentRowIndex, index < current, pattern.rows.indices.contains(index) else { return }
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
        let impact = PatternEditor.impact(of: edit, on: pattern)
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
    private func editRow(_ change: (inout RowEditingSession, WorkingMethod) -> Void) {
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
        let impact = PatternEditor.impact(of: edit, on: pattern)
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

    // MARK: - 目の選択（ui-spec U15）

    /// 目を選ぶ。同じ目をもう一度選ぶと解除
    func select(_ ref: StitchRef?) {
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
        let impact = PatternEditor.impact(of: .replace(rowIndex: location.rowIndex, with: editedRow), on: pattern)
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

    // MARK: - 元に戻す／やり直し（tech-spec 9）

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
    private func mutate(_ change: (inout Pattern) -> Void) {
        let before = pattern
        var after = pattern
        change(&after)
        guard after != before else { return }
        undoStack.append(before)
        redoStack.removeAll()
        pattern = after
        recompute()
    }

    /// 元に戻す／やり直しで編み図を差し替える。先に選ぶ状態と繰り返し開始の位置はずれるので解除する
    private func replacePattern(with newPattern: Pattern) {
        pattern = newPattern
        editingSession = nil
        recompute()
        modifier = .none
        repeatStartIndex = nil
        selection = nil
    }

    /// 展開結果とレイアウトを計算し直す（編集中は作業用のコピーを差し込んだ編み図から）
    private func recompute() {
        let shown = displayedPattern
        expansion = shown.expanded()
        layout = shown.circularLayout(expansion: expansion)
    }
}
