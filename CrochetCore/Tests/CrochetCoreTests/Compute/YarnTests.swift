import Foundation
import Testing
@testable import CrochetCore

/// 色（domain-spec 27〜31、TC-11）
@Suite("色と糸（TC-11）")
struct YarnTests {
    private let ivory = Yarn(name: "生成り", color: YarnColor(hex: "#EDE3D1")!)
    private let brown = Yarn(name: "こげ茶", color: YarnColor(hex: "#5A3A22")!, memo: "品番 12")

    /// TC-1 の作品に糸リスト（生成り・こげ茶）を付けたもの
    private func bearHead() -> Pattern {
        var pattern = TestPatterns.tc1()
        pattern.yarns = [ivory, brown]
        return pattern
    }

    @Test("糸の色：#RRGGBB と RGB の往復、明るい色の判定")
    func colors() {
        let color = YarnColor(hex: "#5A3A22")!
        #expect(color.hexString == "#5A3A22")
        #expect(YarnColor(hex: "ffffff")?.isLight == true)
        #expect(YarnColor(hex: "#EDE3D1")?.isLight == true)
        #expect(YarnColor(hex: "#5A3A22")?.isLight == false)
        #expect(YarnColor(hex: "#12345") == nil)
    }

    @Test("既定の糸：糸なしの操作は糸リストの先頭。リストが空なら生成りの仮の糸。削除した糸も既定に")
    func defaultYarn() {
        var pattern = bearHead()
        #expect(pattern.defaultYarn == ivory)
        #expect(pattern.yarn(for: nil) == ivory)
        #expect(pattern.yarn(for: brown.id) == brown)
        #expect(pattern.yarn(for: UUID()) == ivory)
        #expect(pattern.currentYarn == ivory)
        pattern.yarns = []
        #expect(pattern.defaultYarn == Yarn.fallback)
        #expect(pattern.resolvedYarnID(brown.id) == Yarn.fallback.id)
    }

    @Test("持ち替え（U17）：新しく編む目は今持っている糸になる。立ち上がり・引き抜きも同じ")
    func changeYarnStampsNewSteps() {
        var pattern = Pattern(method: .joinedRounds, foundation: .magicRing, yarns: [ivory, brown])
        PatternInput.addStitch(.singleCrochet, to: &pattern)
        #expect(pattern.rows[0].steps.map(\.yarnID) == [nil, nil])  // 既定の糸（生成り）

        #expect(PatternInput.changeYarn(to: brown.id, in: &pattern))
        PatternInput.addStitch(.singleCrochet, to: &pattern)
        PatternInput.finishRow(of: &pattern)
        #expect(pattern.rows[0].steps.map(\.yarnID) == [nil, nil, brown.id, brown.id])
        PatternInput.addStitch(.doubleCrochet, to: &pattern)
        #expect(pattern.rows[1].steps.map(\.yarnID) == [brown.id, brown.id])  // 立ち上がりも茶

        // 「残りすべてに」の単位の中の目に付く（繰り返しそのものには付かない）
        PatternInput.toggleTest(&pattern, yarn: brown.id)
        // リストにない糸には持ち替えられない
        #expect(PatternInput.changeYarn(to: UUID(), in: &pattern) == false)
        #expect(pattern.currentYarnID == brown.id)
    }

    @Test("段全体を塗る（28）：繰り返しの単位の中まで変わり、飛ばすには付かない")
    func paintRow() {
        var pattern = bearHead()
        #expect(PatternInput.setYarn(brown.id, forRowAt: 2, in: &pattern))
        let row = pattern.rows[2]
        #expect(row.steps[0].yarnID == brown.id)  // 立ち上がり
        guard case .repeatGroup(let unit, _) = row.steps[1].kind else { Issue.record("繰り返しがない"); return }
        #expect(row.steps[1].yarnID == nil)  // 繰り返しそのものには付けない
        #expect(unit.allSatisfy { $0.yarnID == brown.id })
        #expect(row.steps[2].yarnID == brown.id)  // 引き抜き
        #expect(pattern.rows[1].steps.allSatisfy { $0.yarnID == nil })  // ほかの段は変わらない
        #expect(PatternInput.setYarn(brown.id, forRowAt: 9, in: &pattern) == false)

        var skipping = Pattern(method: .joinedRounds, foundation: .magicRing, rows: [Row(steps: [.skip(), .leaveRemaining()])])
        PatternInput.setYarn(brown.id, forRowAt: 0, in: &skipping)
        #expect(skipping.rows[0].steps.allSatisfy { $0.yarnID == nil })
    }

    @Test("目を塗る（27）：繰り返しの中の1目を塗ると、その繰り返しが解除されてその目だけ変わる")
    func paintStitchInsideRepeat() {
        var pattern = bearHead()
        let repeatStep = pattern.rows[2].steps[1]
        guard case .repeatGroup(let unit, _) = repeatStep.kind else { Issue.record("繰り返しがない"); return }
        // 3段目「（細編み1目、増し目）×6」の 3回目の増し目（unit[1]）を茶に
        let ref = StitchRef(rowID: pattern.rows[2].id, stepID: unit[1].id, repetition: 2)
        #expect(PatternInput.setYarn(brown.id, at: ref, in: &pattern))

        let steps = pattern.rows[2].steps
        #expect(steps.count == 1 + 12 + 1)  // 立ち上がり、展開した12操作、引き抜き
        #expect(!steps.contains { if case .repeatGroup = $0.kind { true } else { false } })
        let brownSteps = steps.enumerated().filter { $0.element.yarnID == brown.id }
        #expect(brownSteps.map(\.offset) == [1 + 2 * 2 + 1])  // 3回目の2目め
        #expect(brownSteps.first?.element.kind == .increase(.singleCrochet))
        // 目数は変わらない
        #expect(pattern.expanded().rows[2].totalCount == 18)
        #expect(pattern.expanded().warnings().isEmpty)

        // 繰り返しの外の目はそのまま塗れる
        let plain = StitchRef(rowID: pattern.rows[0].id, stepID: pattern.rows[0].steps[1].id)
        #expect(PatternInput.setYarn(brown.id, at: plain, in: &pattern))
        #expect(pattern.rows[0].steps[1].yarnID == brown.id)
        #expect(pattern.rows[0].steps.count == 8)
    }

    @Test("展開結果の目に糸が付き、色替え位置は「新しい糸の最初の目」と「直前の目」の組になる（31）")
    func yarnChanges() {
        var pattern = bearHead()
        PatternInput.setYarn(brown.id, forRowAt: 1, in: &pattern)  // 2段目だけ茶
        let expansion = pattern.expanded()
        #expect(expansion.rows[1].stitches.allSatisfy { $0.yarnID == brown.id })
        #expect(expansion.rows[0].stitches.allSatisfy { $0.yarnID == nil })

        let changes = expansion.yarnChanges(in: pattern)
        #expect(changes.count == 2)
        // 2段目の最初の目（立ち上がり）で茶に。持ち替えるのは1段目の最後の目（引き抜き）
        #expect(changes[0].ref == expansion.rows[1].stitches[0].ref)
        #expect(changes[0].previousRef == expansion.rows[0].stitches.last?.ref)
        #expect(changes[0].yarnID == brown.id && changes[0].isAtRowStart)
        // 3段目の最初の目で生成りに戻る
        #expect(changes[1].ref == expansion.rows[2].stitches[0].ref)
        #expect(changes[1].yarnID == ivory.id && changes[1].isAtRowStart)
        #expect(expansion.lastYarnID(inRowAt: 1, pattern: pattern) == brown.id)

        // 段の途中で替える：3段目の3回目の増し目だけ茶 → 直前の細編みで持ち替え、次の細編みで戻す
        var nose = bearHead()
        guard case .repeatGroup(let unit, _) = nose.rows[2].steps[1].kind else { return }
        PatternInput.setYarn(brown.id, at: StitchRef(rowID: nose.rows[2].id, stepID: unit[1].id, repetition: 2), in: &nose)
        let noseChanges = nose.expanded().yarnChanges(in: nose)
        #expect(noseChanges.count == 2)
        #expect(noseChanges.allSatisfy { !$0.isAtRowStart })
        #expect(noseChanges[0].yarnID == brown.id && noseChanges[1].yarnID == ivory.id)
        // 茶の目は増し目の2目。替えの位置は1つめの茶の目、戻すのはその次の生成りの目
        let row3 = nose.expanded().rows[2].stitches
        let firstBrown = row3.firstIndex { $0.yarnID == brown.id }!
        #expect(noseChanges[0].ref == row3[firstBrown].ref)
        #expect(noseChanges[0].previousRef == row3[firstBrown - 1].ref)
        #expect(noseChanges[1].ref == row3[firstBrown + 2].ref)
        #expect(noseChanges[1].previousRef == row3[firstBrown + 1].ref)

        // 糸なし（古いデータ）は替えなし
        #expect(TestPatterns.tc1().expanded().yarnChanges(in: TestPatterns.tc1()).isEmpty)
    }

    @Test("目数表：色が変わる項目に糸名を付ける。段の先頭は前の段の終わりと違うときだけ。しま模様の段はまとまらない")
    func tableText() {
        var pattern = bearHead()
        PatternInput.setYarn(brown.id, forRowAt: 1, in: &pattern)
        let rows = StitchTableFormatter.tableRows(for: pattern, expansion: pattern.expanded())
        #expect(rows[0].instruction == "わの作り目に細編み6目")
        #expect(rows[1].instruction == "こげ茶で細編み2目編み入れる×全目")
        #expect(rows[2].instruction == "生成りで（細編み1目、細編み2目編み入れる）×6")
        #expect(rows[3].instruction == "（細編み2目、細編み2目編み入れる）×6")

        // 段の途中：鼻（3回目の増し目）だけ茶
        var nose = bearHead()
        guard case .repeatGroup(let unit, _) = nose.rows[2].steps[1].kind else { return }
        PatternInput.setYarn(brown.id, at: StitchRef(rowID: nose.rows[2].id, stepID: unit[1].id, repetition: 2), in: &nose)
        let noseRows = StitchTableFormatter.tableRows(for: nose, expansion: nose.expanded())
        #expect(noseRows[2].instruction == "細編み1目、細編み2目編み入れる、細編み1目、細編み2目編み入れる、細編み1目、こげ茶で細編み2目編み入れる、生成りで細編み1目、細編み2目編み入れる、細編み1目、細編み2目編み入れる、細編み1目、細編み2目編み入れる")

        // 単位の中で糸が変わる繰り返しは、単位の最初にも糸名を付ける（どの回でも読めるように）
        var striped = Pattern(method: .joinedRounds, foundation: .magicRing, yarns: [ivory, brown])
        striped.rows = [
            Row(steps: TestPatterns.stitches(.singleCrochet, 8)),
            Row(steps: [.repeating([
                Step(kind: .stitch(.singleCrochet), yarnID: ivory.id), Step(kind: .stitch(.singleCrochet), yarnID: ivory.id),
                Step(kind: .stitch(.singleCrochet), yarnID: brown.id), Step(kind: .stitch(.singleCrochet), yarnID: brown.id),
            ], times: 2)]),
        ]
        let stripedRows = StitchTableFormatter.tableRows(for: striped, expansion: striped.expanded())
        #expect(stripedRows[1].instruction == "（生成りで細編み2目、こげ茶で細編み2目）×2")

        // 「残りすべてに」に糸名が付くとき
        var rest = Pattern(method: .spiral, foundation: .magicRing, yarns: [ivory, brown])
        rest.rows = [Row(steps: TestPatterns.stitches(.singleCrochet, 6)), Row(steps: [.untilEnd([Step(kind: .stitch(.singleCrochet), yarnID: brown.id)])])]
        #expect(StitchTableFormatter.tableRows(for: rest, expansion: rest.expanded())[1].instruction == "こげ茶で残りの目すべてに細編み")

        // 同じ手順で増減なしでも、糸が違う段はまとまらない
        var stripes = Pattern(method: .spiral, foundation: .magicRing, yarns: [ivory, brown])
        stripes.rows = [
            Row(steps: TestPatterns.stitches(.singleCrochet, 6)),
            Row(steps: [.untilEnd([.stitch(.singleCrochet)])]),
            Row(steps: [.untilEnd([Step(kind: .stitch(.singleCrochet), yarnID: brown.id)])]),
            Row(steps: [.untilEnd([.stitch(.singleCrochet)])]),
        ]
        let stripeRows = StitchTableFormatter.tableRows(for: stripes, expansion: stripes.expanded())
        #expect(stripeRows.map(\.rowNumberText) == ["1段目", "2段目", "3段目", "4段目"])
    }

    @Test("JSON：糸と操作の糸が往復する")
    func json() throws {
        var pattern = bearHead()
        pattern.currentYarnID = brown.id
        PatternInput.setYarn(brown.id, forRowAt: 1, in: &pattern)
        let data = try pattern.jsonData()
        let text = String(decoding: data, as: UTF8.self)
        #expect(text.contains("\"name\":\"こげ茶\"") && text.contains("\"memo\":\"品番 12\"") && text.contains("\"color\":\"#5A3A22\""))
        #expect(try Pattern(jsonData: data) == pattern)
    }
}

private extension PatternInput {
    /// テスト用：「残りすべてに」で入れた目に糸が付き、繰り返しそのものには付かないことを確かめる
    static func toggleTest(_ pattern: inout Pattern, yarn: UUID) {
        var modifier = StitchModifier.none
        modifier.toggleUntilEnd()
        addStitch(.singleCrochet, modifier: modifier, to: &pattern)
        let last = pattern.rows[pattern.currentRowIndex!].steps.last!
        #expect(last.yarnID == nil)
        if case .repeatGroup(let unit, _) = last.kind {
            #expect(unit.map(\.yarnID) == [yarn])
        } else {
            Issue.record("繰り返しになっていない")
        }
    }
}
