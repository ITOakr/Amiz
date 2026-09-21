import Foundation
import Testing
import CrochetCore
@testable import Amiz

/// 糸リストと持ち替え（EditorModel。ui-spec U17・6-1）
@Suite("糸リストと持ち替え（EditorModel）")
struct YarnModelTests {
    @Test("糸リストのない作品を開くと既定の糸が1本入る")
    func fallbackYarn() {
        let model = EditorModel(pattern: TestPatternsForApp.bearWithoutYarns())
        #expect(model.yarns.count == 1)
        #expect(model.currentYarn == Yarn.fallback)
    }

    @Test("糸を追加して持ち替えると、新しく編む目はその糸になる。元に戻すで戻る")
    func addAndChange() {
        let model = EditorModel()
        let brown = Yarn(name: "こげ茶", color: YarnColor(hex: "#5A3A22")!)
        model.addYarn(brown)
        #expect(model.yarns.map(\.name) == ["メイン", "こげ茶"])
        model.pressStitch(.singleCrochet)
        model.changeYarn(to: brown.id)
        #expect(model.currentYarn.id == brown.id)
        model.pressStitch(.singleCrochet)
        let steps = model.pattern.rows[0].steps
        #expect(steps.map(\.yarnID) == [nil, nil, brown.id])

        model.undo()  // 目を取り消す
        model.undo()  // 持ち替えを取り消す
        #expect(model.currentYarn.id == Yarn.fallback.id)
        #expect(model.pattern.rows[0].steps.count == 2)
    }

    @Test("糸の編集・並べ替え・削除")
    func editMoveDelete() {
        let model = EditorModel()
        let brown = Yarn(name: "こげ茶", color: YarnColor(hex: "#5A3A22")!)
        model.addYarn(brown)
        var renamed = brown
        renamed.name = "チョコ"
        model.updateYarn(renamed)
        #expect(model.yarns[1].name == "チョコ")

        model.moveYarns(fromOffsets: IndexSet(integer: 1), toOffset: 0)
        #expect(model.yarns.map(\.id) == [brown.id, Yarn.fallback.id])
        #expect(model.pattern.defaultYarn.id == brown.id)

        model.changeYarn(to: brown.id)
        model.pressStitch(.singleCrochet)
        model.deleteYarn(id: brown.id)
        #expect(model.yarns.map(\.id) == [Yarn.fallback.id])
        #expect(model.pattern.rows[0].steps.allSatisfy { $0.yarnID == nil })
        #expect(model.currentYarn.id == Yarn.fallback.id)
        model.deleteYarn(id: Yarn.fallback.id)  // 最後の1本は消えない
        #expect(model.yarns.count == 1)
    }
}

enum TestPatternsForApp {
    /// 糸リストのない「くまの頭」（色に対応する前のデータ相当）
    static func bearWithoutYarns() -> Pattern {
        var pattern = SamplePatterns.bearHead
        pattern.yarns = []
        return pattern
    }
}
