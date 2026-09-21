import Foundation
import Testing
import CrochetCore
@testable import Amiz

/// 色編集モード（EditorModel。ui-spec U21）
@Suite("色編集モード（EditorModel）")
struct ColorEditingTests {
    private let brown = Yarn(name: "こげ茶", color: YarnColor(hex: "#5A3A22")!)

    private func bearModel() -> EditorModel {
        var pattern = SamplePatterns.bearHead
        pattern.yarns = [Yarn(name: "生成り", color: YarnColor(hex: "#EDE3D1")!), brown]
        return EditorModel(pattern: pattern)
    }

    @Test("モードに入ると選択と先に選ぶ状態が解け、目ボタンや選択は効かない。塗る色は今持っている糸から")
    func enterMode() {
        let model = bearModel()
        model.toggleIncrease()
        model.select(StitchRef(rowID: model.pattern.rows[0].id, stepID: model.pattern.rows[0].steps[1].id))
        model.beginColorEditing()
        #expect(model.isColorEditing)
        #expect(model.selection == nil && model.modifier == .none)
        #expect(model.paintYarnID == model.currentYarn.id)

        let before = model.pattern
        model.pressStitch(.singleCrochet)
        model.select(StitchRef(rowID: model.pattern.rows[0].id, stepID: model.pattern.rows[0].steps[1].id))
        model.beginEditingRow(at: 0)
        #expect(model.pattern == before && model.selection == nil && model.editingSession == nil)

        model.endColorEditing()
        #expect(!model.isColorEditing)
        model.pressStitch(.singleCrochet)
        #expect(model.pattern != before)
    }

    @Test("段を塗る：段全体がその糸になり、元に戻すで戻る")
    func paintRow() {
        let model = bearModel()
        model.beginColorEditing()
        model.paintYarnID = brown.id
        model.paintRow(at: 1)
        #expect(model.expansion.rows[1].stitches.allSatisfy { $0.yarnID == brown.id })
        #expect(model.expansion.rows[0].stitches.allSatisfy { $0.yarnID == nil })
        model.undo()
        #expect(model.expansion.rows[1].stitches.allSatisfy { $0.yarnID == nil })
        #expect(model.isColorEditing)  // 元に戻してもモードは続く
    }

    @Test("目を塗る：繰り返しの中の目を塗ると繰り返しが解けてその目だけ変わる。モード外では塗れない")
    func paintStitch() {
        let model = bearModel()
        guard case .repeatGroup(let unit, _) = model.pattern.rows[2].steps[1].kind else { Issue.record("繰り返しがない"); return }
        let ref = StitchRef(rowID: model.pattern.rows[2].id, stepID: unit[1].id, repetition: 2)

        model.paintStitch(ref)  // モード外
        #expect(model.pattern.rows[2].steps.count == 3)

        model.beginColorEditing()
        model.paintYarnID = brown.id
        model.paintStitch(ref)
        #expect(model.pattern.rows[2].steps.count == 14)
        #expect(model.pattern.rows[2].steps.filter { $0.yarnID == brown.id }.count == 1)
        #expect(model.expansion.rows[2].totalCount == 18)
        #expect(model.expansion.rows[2].stitches.filter { $0.yarnID == brown.id }.count == 2)  // 増し目の2目
    }

    @Test("なぞって塗る：なぞり始めから終わりまでが元に戻すの1回になる")
    func paintStroke() {
        let model = bearModel()
        model.beginColorEditing()
        model.paintYarnID = brown.id
        let row = model.pattern.rows[0]
        model.beginPaintStroke()
        for step in row.steps.dropFirst().prefix(3) {
            model.paintStitch(StitchRef(rowID: row.id, stepID: step.id))
        }
        model.endPaintStroke()
        #expect(model.pattern.rows[0].steps.filter { $0.yarnID == brown.id }.count == 3)
        model.undo()
        #expect(model.pattern.rows[0].steps.allSatisfy { $0.yarnID == nil })
        #expect(!model.canUndo)

        // 何も塗らなかったなぞりは積まない
        model.beginPaintStroke()
        model.endPaintStroke()
        #expect(!model.canUndo)
    }
}

/// 図の色（レイアウトに糸が乗ること。描画そのものは目視）
@Suite("図の色（レイアウトの糸）")
struct ChartColorTests {
    @Test("色付きのくまの頭：レイアウトの各目に糸が付き、色替えの位置が6つある")
    func coloredSample() {
        let pattern = SamplePatterns.bearHeadColored
        let model = EditorModel(pattern: pattern)
        let brown = pattern.yarns[1].id
        let white = pattern.yarns[2].id
        #expect(model.layout.stitches.filter { $0.rowIndex == 1 }.allSatisfy { $0.yarnID == brown })
        #expect(model.layout.stitches.filter { $0.rowIndex == 3 }.allSatisfy { $0.yarnID == white })
        #expect(model.layout.stitches.filter { $0.rowIndex == 2 && $0.yarnID == brown }.count == 2)
        // 2段目でこげ茶に、3段目で生成りに、鼻でこげ茶→生成り、4段目で白、5段目（入力中。糸の指定なし）で生成りに戻る
        let changes = model.yarnChanges
        #expect(changes.count == 6)
        #expect(changes.allSatisfy { change in change.previousRef.map { model.layout.stitch(for: $0) != nil } ?? false })
    }
}
