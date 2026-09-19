import Testing
import CrochetCore
@testable import Amiz

@Suite("編集の状態管理（EditorModel）")
struct EditorModelTests {
    /// TC-1「くまの頭」の1〜3段目をボタン操作で入力する
    private func inputFirstThreeRows(into model: EditorModel) {
        // 1段目：細編み6目、段を終える
        for _ in 0..<6 { model.pressStitch(.singleCrochet) }
        model.pressFinishRow()

        // 2段目：残りすべてに + 2目編み入れる → 細編み
        model.toggleUntilEnd()
        model.toggleIncrease()
        model.pressStitch(.singleCrochet)
        model.pressFinishRow()

        // 3段目：繰り返し開始 → 細編み、2目編み入れる → 繰り返し終了 ×6
        model.pressBeginRepeat()
        model.pressStitch(.singleCrochet)
        model.toggleIncrease()
        model.pressStitch(.singleCrochet)
        model.pressEndRepeat(count: .times(6))
        model.pressFinishRow()
    }

    @Test("ボタン操作に相当する呼び出しで目数が 6/12/18 になる")
    func pressesProduceCounts() {
        let model = EditorModel()
        inputFirstThreeRows(into: model)

        #expect(model.expansion.rows.map(\.totalCount) == [6, 12, 18, 0])
        #expect(model.currentRowIndex == 3)
        #expect(model.warnings.isEmpty)
        #expect(!model.modifier.isActive)
        #expect(!model.isRepeating)
    }

    @Test("先に選ぶ状態は目ボタンで解除される。繰り返し開始の位置は立ち上がりの自動挿入でずれる")
    func modifierAndRepeatStart() {
        let model = EditorModel()
        model.toggleIncrease()
        #expect(model.modifier.group == .increase(count: 2))
        model.pressStitch(.singleCrochet)
        #expect(!model.modifier.isActive)
        model.pressFinishRow()

        // 段の先頭で繰り返し開始 → 最初の細編みで立ち上がりが入り、開始位置が 0 → 1 になる
        model.pressBeginRepeat()
        #expect(model.repeatStartIndex == 0)
        model.pressStitch(.singleCrochet)
        #expect(model.repeatStartIndex == 1)
        #expect(model.pendingRepeatUnit?.count == 1)
        #expect(model.canEndRepeatUntilEnd)
    }

    @Test("元に戻す → やり直し")
    func undoRedo() {
        let model = EditorModel()
        #expect(!model.canUndo)

        inputFirstThreeRows(into: model)
        #expect(model.canUndo)
        #expect(!model.canRedo)

        // 段を終えるを戻す → 3段目が入力中に戻る
        model.undo()
        #expect(model.pattern.rows.count == 3)
        #expect(model.expansion.rows.map(\.totalCount) == [6, 12, 18])
        #expect(model.canRedo)

        // 繰り返し終了を戻す → 3段目は 立ち上がり・細編み・増し目 の3操作
        model.undo()
        #expect(model.pattern.rows[2].steps.count == 3)
        #expect(model.expansion.rows[2].totalCount == 3)

        // やり直し2回で元に戻る
        model.redo()
        model.redo()
        #expect(model.pattern.rows.count == 4)
        #expect(model.expansion.rows.map(\.totalCount) == [6, 12, 18, 0])
        #expect(!model.canRedo)

        // 戻した後に別の操作をすると、やり直しの履歴は消える
        model.undo()
        model.pressStitch(.singleCrochet)
        #expect(!model.canRedo)
        #expect(model.pattern.rows.count == 3)
    }

    @Test("1目削除は繰り返しごと消し、空の段では段を終えるを取り消す")
    func deleteLast() {
        let model = EditorModel()
        inputFirstThreeRows(into: model)

        model.pressDeleteLast()  // 空の4段目 → 3段目の引き抜きが外れて入力中に戻る
        #expect(model.pattern.rows.count == 3)
        #expect(model.currentRow?.totalCount == 18)

        model.pressDeleteLast()  // （細編み、増し目）×6 が丸ごと消える
        #expect(model.currentRow?.totalCount == 0)
        #expect(model.pattern.rows[2].steps.count == 1)  // 立ち上がりだけ残る
    }

    @Test("段を終える前の確認：前段に目が残っていればその数、使い切っていれば nil")
    func remainingBeforeFinish() {
        let model = EditorModel()
        for _ in 0..<6 { model.pressStitch(.singleCrochet) }
        #expect(model.remainingBeforeFinish == nil)  // わの作り目の1段目は前段がない
        #expect(!model.hasUsedUpPreviousRow)
        model.pressFinishRow()

        for _ in 0..<3 { model.pressStitch(.singleCrochet) }
        #expect(model.remainingBeforeFinish == 3)
        #expect(!model.hasUsedUpPreviousRow)

        for _ in 0..<3 { model.pressStitch(.singleCrochet) }
        #expect(model.remainingBeforeFinish == nil)
        #expect(model.hasUsedUpPreviousRow)

        model.pressStitch(.singleCrochet)  // 拾いすぎ
        #expect(model.remainingBeforeFinish == nil)
        #expect(model.hasUsedUpPreviousRow)
        model.pressFinishRow()
        #expect(model.warnings.map(\.message) == ["前段6目に対して7目拾っています"])
    }

    @Test("「残りは編まない」で段を終えると警告が出ず、1回の元に戻すで取り消せる")
    func finishRowLeavingRemaining() {
        let model = EditorModel()
        for _ in 0..<6 { model.pressStitch(.singleCrochet) }
        model.pressFinishRow()
        for _ in 0..<3 { model.pressStitch(.singleCrochet) }

        model.pressFinishRow(leavingRemaining: true)
        #expect(model.warnings.isEmpty)
        #expect(model.pattern.rows.count == 3)
        #expect(model.pattern.rows[1].steps.contains { $0.kind == .leaveRemaining })

        model.undo()
        #expect(model.pattern.rows.count == 2)
        #expect(!model.pattern.rows[1].steps.contains { $0.kind == .leaveRemaining })
    }

    @Test("立ち上がりの自動入力をオフにすると入らない")
    func autoTurningChainOff() {
        let model = EditorModel()
        model.autoTurningChain = false
        model.pressStitch(.singleCrochet)
        #expect(model.pattern.rows[0].steps.count == 1)

        model.pressTurningChain(chains: 1)
        #expect(model.pattern.rows[0].steps.count == 2)
        #expect(model.pattern.rows[0].steps[0].kind == .turningChain(chains: 1))
    }

    @Test("選択：入力中の段の目は確認なしで種類を変えられ、削除もできる")
    func selectionInCurrentRow() {
        let model = EditorModel()
        for _ in 0..<3 { model.pressStitch(.singleCrochet) }
        let row = model.pattern.rows[0]
        let ref = StitchRef(rowID: row.id, stepID: row.steps[2].id)

        model.select(ref)
        #expect(model.selection == ref)
        #expect(model.selectionDescription == "細編み（1段目）")

        // 目ボタンで種類の変更（追加ではない）
        model.pressStitch(.doubleCrochet)
        #expect(model.pattern.rows[0].steps.count == 4)  // 立ち上がり + 3目のまま
        #expect(model.pattern.rows[0].steps[2].kind == .stitch(.doubleCrochet))
        #expect(model.selection == ref)  // 種類の変更では選択が残る
        #expect(model.pendingConfirmation == nil)

        model.request(.delete)
        #expect(model.pattern.rows[0].steps.count == 3)
        #expect(model.selection == nil)

        // 元に戻すで戻る
        model.undo()
        #expect(model.pattern.rows[0].steps.count == 4)
    }

    @Test("選択：過去の段で目数が変わる編集は確認待ちになり、残す／ほどくで結果が分かれる")
    func selectionInPastRowNeedsConfirmation() {
        let model = EditorModel(pattern: SamplePatterns.bearHead)
        let row1 = model.pattern.rows[0]
        model.select(StitchRef(rowID: row1.id, stepID: row1.steps[1].id))

        // 1段目の細編みを消す → 6目→5目、2〜5段目に影響
        model.request(.delete)
        #expect(model.pendingConfirmation != nil)
        #expect(model.pendingConfirmation?.message == "1段目の目数が6目から5目に変わりました。2〜5段目に影響があります。")
        #expect(model.pattern.rows[0].steps.count == 8)  // まだ変わっていない

        // キャンセル → 何も変わらない
        model.cancelConfirmation()
        #expect(model.pendingConfirmation == nil)
        #expect(model.pattern.rows[0].steps.count == 8)

        // もう一度 → 上の段を残す
        model.request(.delete)
        model.resolveConfirmation(keepingRowsAbove: true)
        #expect(model.pattern.rows.count == 5)
        #expect(model.expansion.rows.map(\.totalCount) == [5, 10, 18, 24, 4])
        #expect(model.warnings.map(\.rowNumber) == [3])
        #expect(model.selection == nil)

        // やり直しの履歴ではなく元に戻す：1回で戻る
        model.undo()
        #expect(model.expansion.rows.map(\.totalCount) == [6, 12, 18, 24, 4])

        // 上の段をほどく
        model.select(StitchRef(rowID: row1.id, stepID: row1.steps[1].id))
        model.request(.delete)
        model.resolveConfirmation(keepingRowsAbove: false)
        #expect(model.pattern.rows.count == 1)
        #expect(model.expansion.rows.map(\.totalCount) == [5])
    }

    @Test("選択：TC-5 の画面版。過去の段の細編みを中長編みにしても確認は出ない")
    func selectionTC5() {
        let model = EditorModel(pattern: SamplePatterns.bearHead)
        guard case .repeatGroup(let unit, _) = model.pattern.rows[2].steps[1].kind else { Issue.record("繰り返しのはず"); return }
        model.select(StitchRef(rowID: model.pattern.rows[2].id, stepID: unit[0].id))
        #expect(model.selectionIsInRepeat)

        model.pressStitch(.halfDoubleCrochet)
        #expect(model.pendingConfirmation == nil)
        #expect(model.expansion.rows.map(\.totalCount) == [6, 12, 18, 24, 4])
        #expect(model.warnings.isEmpty)
        #expect(model.expansion.rows[2].stitches.filter { $0.kind == .halfDoubleCrochet }.count == 6)
    }
}
