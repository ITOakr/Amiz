import Testing
import CrochetCore
@testable import Amiz

/// 設定「立ち上がりを1目と数える」が入力・選択に効くこと（ui-spec 6-3・7-4・U15・U23）
@Suite("立ち上がりを数えるかの設定（EditorModel）")
struct TurningChainCountingSettingTests {
    @Test("標準：鎖1目は数えない、鎖3目は数える")
    func standard() {
        let model = EditorModel()
        model.pressStitch(.singleCrochet)
        #expect(model.pattern.rows[0].steps[0].kind == .turningChain(chains: 1, counted: false))
        model.pressFinishRow()
        model.pressStitch(.doubleCrochet)
        #expect(model.pattern.rows[1].steps[0].kind == .turningChain(chains: 3, counted: true))
    }

    @Test("数える：細編みの鎖1目も1目と数え、目数に入る")
    func counted() {
        let model = EditorModel()
        model.turningChainCounting = .counted
        for _ in 0..<5 { model.pressStitch(.singleCrochet) }
        #expect(model.pattern.rows[0].steps[0].kind == .turningChain(chains: 1, counted: true))
        #expect(model.expansion.rows[0].totalCount == 6)
    }

    @Test("数えない：長編みの鎖3目も数えず、前段を拾わない")
    func notCounted() {
        let model = EditorModel()
        model.turningChainCounting = .notCounted
        for _ in 0..<6 { model.pressStitch(.singleCrochet) }
        model.pressFinishRow()
        model.toggleUntilEnd()
        model.pressStitch(.doubleCrochet)
        #expect(model.pattern.rows[1].steps[0].kind == .turningChain(chains: 3, counted: false))
        #expect(model.expansion.rows[1].totalCount == 6)
        #expect(model.expansion.rows[1].stitches.filter { $0.role == .regular }.count == 6)
    }

    @Test("毎回選択：目を押すと確認待ちになり、答えると立ち上がりと目が入る。キャンセルなら何も入らない")
    func askEveryTime() {
        let model = EditorModel()
        model.turningChainCounting = .askEveryTime
        model.toggleIncrease()
        model.pressStitch(.singleCrochet)
        #expect(model.pendingTurningChainQuestion?.message == "立ち上がり鎖1目を1目と数えますか？")
        #expect(model.pattern.rows.isEmpty || model.pattern.rows[0].steps.isEmpty)

        model.answerTurningChainQuestion(counted: true)
        #expect(model.pendingTurningChainQuestion == nil)
        #expect(model.pattern.rows[0].steps.map(\.kind) == [.turningChain(chains: 1, counted: true), .increase(.singleCrochet)])
        #expect(model.modifier == .none)

        // 2目め以降は立ち上がりが入らないので聞かない
        model.pressStitch(.singleCrochet)
        #expect(model.pendingTurningChainQuestion == nil)
        #expect(model.pattern.rows[0].steps.count == 3)

        // 次の段でキャンセル → 何も入らず、先に選ぶ状態は残る
        model.pressFinishRow()
        model.toggleIncrease()
        model.pressStitch(.singleCrochet)
        #expect(model.pendingTurningChainQuestion != nil)
        model.cancelTurningChainQuestion()
        #expect(model.pattern.rows[1].steps.isEmpty)
        #expect(model.modifier != .none)
    }

    @Test("毎回選択：立ち上がりボタン（U23）でも聞く")
    func askOnTurningChainButton() {
        let model = EditorModel()
        model.turningChainCounting = .askEveryTime
        model.pressTurningChain(chains: 3)
        #expect(model.pendingTurningChainQuestion?.message == "立ち上がり鎖3目を1目と数えますか？")
        model.answerTurningChainQuestion(counted: false)
        #expect(model.pattern.rows[0].steps.map(\.kind) == [.turningChain(chains: 3, counted: false)])
    }

    @Test("過去の段の編集中も設定に従う")
    func editingSessionFollowsSetting() {
        let model = EditorModel()
        model.turningChainCounting = .counted
        for _ in 0..<6 { model.pressStitch(.singleCrochet) }
        model.pressFinishRow()
        for _ in 0..<6 { model.pressStitch(.singleCrochet) }
        model.pressFinishRow()

        // 1段目を編集：目をすべて消してから入れ直すと、設定どおり「数える」の立ち上がりが自動で入る
        model.beginEditingRow(at: 0)
        model.moveCursor(to: 7)  // 立ち上がり＋細編み6目の後ろ（引き抜きの前）
        for _ in 0..<7 { model.pressDeleteLast() }
        model.turningChainCounting = .notCounted
        model.pressStitch(.singleCrochet)
        #expect(model.displayedPattern.rows[0].steps.map(\.kind).prefix(2) == [.turningChain(chains: 1, counted: false), .stitch(.singleCrochet)])

        // 「毎回選択」なら編集中も聞く
        model.cancelEditingRow()
        model.turningChainCounting = .askEveryTime
        model.beginEditingRow(at: 0)
        model.moveCursor(to: 7)
        for _ in 0..<7 { model.pressDeleteLast() }
        model.pressStitch(.singleCrochet)
        #expect(model.pendingTurningChainQuestion != nil)
        model.answerTurningChainQuestion(counted: true)
        #expect(model.displayedPattern.rows[0].steps.first?.kind == .turningChain(chains: 1, counted: true))
    }

    @Test("選択（U15）：立ち上がりの数え方を後から切り替えられる")
    func toggleViaSelection() {
        let model = EditorModel()
        for _ in 0..<6 { model.pressStitch(.singleCrochet) }
        let row = model.pattern.rows[0]
        model.select(StitchRef(rowID: row.id, stepID: row.steps[0].id))
        #expect(model.selectedTurningChainCounted == false)
        model.request(.setTurningChainCounted(true))
        #expect(model.pattern.rows[0].steps[0].kind == .turningChain(chains: 1, counted: true))
        #expect(model.selectedTurningChainCounted == true)
        #expect(model.selection != nil)  // 選択は残る
        #expect(model.expansion.rows[0].totalCount == 7)

        // 鎖の目数を変えると、設定（標準）に従って数え方も決まる
        model.request(.setTurningChain(3))
        #expect(model.pattern.rows[0].steps[0].kind == .turningChain(chains: 3, counted: true))
        model.request(.setTurningChain(1))
        #expect(model.pattern.rows[0].steps[0].kind == .turningChain(chains: 1, counted: false))
    }
}
