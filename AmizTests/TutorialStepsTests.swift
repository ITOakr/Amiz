import Foundation
import Testing
import CrochetCore
@testable import Amiz

/// 使い方の案内（AMIZ-84）。案内どおりに操作すると、わ編みのコースター（6→12→18目）ができる
@MainActor
@Suite("使い方の案内")
struct TutorialStepsTests {
    /// テストごとに別の UserDefaults を使う（本物の設定を汚さない）
    private func makeDefaults() -> UserDefaults {
        let defaults = UserDefaults(suiteName: "tutorial-test-\(UUID().uuidString)")!
        return defaults
    }

    private func makeModel() -> (TutorialModel, EditorModel) {
        let tutorial = TutorialModel(defaults: makeDefaults())
        tutorial.start()
        let editor = EditorModel(pattern: Pattern(method: .joinedRounds, foundation: .magicRing, rows: [Row()]))
        return (tutorial, editor)
    }

    /// 今のステップの id
    private func stepID(_ tutorial: TutorialModel) -> String? {
        tutorial.currentStep?.id
    }

    @Test("案内どおりに操作すると、3段・6/12/18目のコースターができる")
    func followingTheStepsMakesTheCoaster() {
        let (tutorial, editor) = makeModel()

        // 1. ホーム →「新規作成」
        #expect(stepID(tutorial) == "newWork")
        tutorial.update(TutorialState(screen: .newWork))
        #expect(stepID(tutorial) == "create")

        // 2. 新規作成 →「作成」で編集画面へ
        tutorial.update(TutorialState(screen: .editor, model: editor))
        #expect(stepID(tutorial) == "firstRow")

        // 3. 1段目：細編み6回（立ち上がりは自動で入り、標準では数えない）
        for _ in 0..<6 {
            editor.pressStitch(.singleCrochet)
            tutorial.update(TutorialState(screen: .editor, model: editor))
        }
        #expect(stepID(tutorial) == "finishRow1")

        // 4. 段を終える
        editor.pressFinishRow()
        tutorial.update(TutorialState(screen: .editor, model: editor))
        #expect(stepID(tutorial) == "untilEnd")

        // 5〜7. 2段目：「全目に」→「増し目」→ 細編み
        editor.toggleUntilEnd()
        tutorial.update(TutorialState(screen: .editor, model: editor))
        #expect(stepID(tutorial) == "increase")

        editor.toggleIncrease()
        tutorial.update(TutorialState(screen: .editor, model: editor))
        #expect(stepID(tutorial) == "row2Stitch")

        editor.pressStitch(.singleCrochet)
        tutorial.update(TutorialState(screen: .editor, model: editor))
        #expect(stepID(tutorial) == "finishRow2")

        // 8. 段を終える
        editor.pressFinishRow()
        tutorial.update(TutorialState(screen: .editor, model: editor))
        #expect(stepID(tutorial) == "beginRepeat")

        // 9〜13. 3段目：繰り返し（細編み1目、増し目）×6
        editor.pressBeginRepeat()
        tutorial.update(TutorialState(screen: .editor, model: editor))
        #expect(stepID(tutorial) == "repeatStitch1")

        editor.pressStitch(.singleCrochet)
        tutorial.update(TutorialState(screen: .editor, model: editor))
        #expect(stepID(tutorial) == "repeatIncrease")

        editor.toggleIncrease()
        tutorial.update(TutorialState(screen: .editor, model: editor))
        #expect(stepID(tutorial) == "repeatStitch2")

        editor.pressStitch(.singleCrochet)
        tutorial.update(TutorialState(screen: .editor, model: editor))
        #expect(stepID(tutorial) == "endRepeat")

        #expect(editor.pressEndRepeat(count: .times(6)))
        tutorial.update(TutorialState(screen: .editor, model: editor))
        #expect(stepID(tutorial) == "finishRow3")

        // 14. 段を終える
        editor.pressFinishRow()
        tutorial.update(TutorialState(screen: .editor, model: editor))
        #expect(stepID(tutorial) == "table")

        // 15. 目数表を見る
        tutorial.update(TutorialState(screen: .editor, model: editor, showsTable: true))
        #expect(stepID(tutorial) == "done")

        // できあがった編み図：3段で 6 → 12 → 18目
        let counts = editor.expansion.rows.map(\.totalCount)
        #expect(counts.prefix(3) == [6, 12, 18])
        #expect(editor.warnings.isEmpty, "目数の警告は出ない")

        // 最後のステップでは「終わる」を出す
        #expect(tutorial.isOnLastStep)
        tutorial.finish()
        #expect(!tutorial.isActive)
        #expect(tutorial.hasCompleted)
    }

    @Test("案内と違う目を押しても、条件を満たせば次へ進む（止まらない）")
    func differentStitchStillAdvances() {
        let (tutorial, editor) = makeModel()
        tutorial.update(TutorialState(screen: .newWork))
        tutorial.update(TutorialState(screen: .editor, model: editor))
        #expect(stepID(tutorial) == "firstRow")

        // 細編みではなく長編みを6回
        for _ in 0..<6 {
            editor.pressStitch(.doubleCrochet)
            tutorial.update(TutorialState(screen: .editor, model: editor))
        }
        #expect(stepID(tutorial) == "finishRow1", "6目になったので次へ進む")
    }

    @Test("目数が足りないうちは進まない")
    func doesNotAdvanceTooEarly() {
        let (tutorial, editor) = makeModel()
        tutorial.update(TutorialState(screen: .newWork))
        tutorial.update(TutorialState(screen: .editor, model: editor))

        for _ in 0..<5 {
            editor.pressStitch(.singleCrochet)
            tutorial.update(TutorialState(screen: .editor, model: editor))
        }
        #expect(stepID(tutorial) == "firstRow", "5目では進まない")

        editor.pressStitch(.singleCrochet)
        tutorial.update(TutorialState(screen: .editor, model: editor))
        #expect(stepID(tutorial) == "finishRow1")
    }

    @Test("スキップすると案内が終わり、見たことが記録される")
    func skipRecordsCompletion() {
        let defaults = makeDefaults()
        let tutorial = TutorialModel(defaults: defaults)

        #expect(!tutorial.hasCompleted)
        tutorial.start()
        #expect(tutorial.isActive)

        tutorial.skip()
        #expect(!tutorial.isActive)
        #expect(tutorial.hasCompleted)
        #expect(defaults.bool(forKey: TutorialModel.completedKey))

        // もう一度始めることはできる（設定から開き直す）
        tutorial.start()
        #expect(tutorial.isActive)
        #expect(stepID(tutorial) == "newWork")
    }

    @Test("進み具合の表示")
    func progressText() {
        let (tutorial, _) = makeModel()
        #expect(tutorial.progressText == "1 / \(TutorialStep.coaster.count)")
        tutorial.update(TutorialState(screen: .newWork))
        #expect(tutorial.progressText == "2 / \(TutorialStep.coaster.count)")
    }
}
