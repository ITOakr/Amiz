import Foundation
import Testing
@testable import CrochetCore

/// 束に編み入れる（domain-spec 3・4・21・23、TC-10）
@Suite("束に編み入れる（TC-10）")
struct ChainSpaceTests {
    @Test("TC-10 花のモチーフ 3段目：12 のアーチに細編み3目ずつで 36 目、前段 36 目を拾い切り警告なし")
    func tc10() {
        let pattern = TestPatterns.tc10()
        let expansion = pattern.expanded()
        let row3 = expansion.rows[2]
        #expect(row3.totalCount == 36)
        #expect(row3.previousCount == 36)
        #expect(row3.pickedCount == 36)
        #expect(row3.issues.isEmpty)
        #expect(expansion.warnings().isEmpty)

        // 繰り返しは 12 回
        let repeatID = pattern.rows[2].steps[1].id
        #expect(row3.repeatCounts[repeatID] == 12)

        // 最初のアーチは前段の 1・2 目め（立ち上がりの次の鎖2目）。3目とも同じアーチを拾い、束に編み入れている
        let stitches = row3.stitches.filter { $0.role == .regular }
        #expect(stitches[0].picks == 1..<3 && stitches[1].picks == 1..<3 && stitches[2].picks == 1..<3)
        #expect(stitches[0].into == .chainSpace)
        // 2つめのアーチは長編み（3）を飛ばして 4・5 目め、最後のアーチは 34・35 目め
        #expect(stitches[3].picks == 4..<6)
        #expect(stitches[35].picks == 34..<36)
    }

    @Test("長編みにも編む場合：細編み（長編みに）、束に細編み3目 を 12 回で 48 目")
    func stitchesBetweenArches() {
        var pattern = TestPatterns.tc4()
        pattern.rows.append(Row(steps: [
            .turningChain(1),
            .repeating([.stitch(.singleCrochet), .increase(.singleCrochet, count: 3, into: .chainSpace)], times: 12),
            .closeRound(),
        ]))
        let row = pattern.expanded().rows[2]
        #expect(row.totalCount == 48)
        #expect(row.pickedCount == 36)
        #expect(pattern.expanded().warnings().isEmpty)
        let stitches = row.stitches.filter { $0.role == .regular }
        #expect(stitches[0].picks == 0..<1)   // 立ち上がり（長編みの代わり）に細編み
        #expect(stitches[1].picks == 1..<3)   // アーチ
        #expect(stitches[4].picks == 3..<4)   // 長編み
        #expect(stitches[5].picks == 4..<6)
    }

    @Test("アーチが残っていないのに束に編むと、前段は拾わず問題として記録し、段を終えると拾い残しの警告になる")
    func noChainSpaceAhead() {
        var pattern = TestPatterns.tc1()
        pattern.rows = Array(pattern.rows.prefix(1))  // 6目（鎖なし）
        let step = Step.stitch(.singleCrochet, into: .chainSpace)
        pattern.rows.append(Row(steps: [.turningChain(1), step, .closeRound()]))
        let expansion = pattern.expanded()
        let row = expansion.rows[1]
        #expect(row.stitches[1].picks.isEmpty)
        #expect(row.pickedCount == 0)
        #expect(row.issues == [.noChainSpaceAhead(stepID: step.id)])
        #expect(expansion.warnings().map(\.message) == ["前段6目のうち0目しか拾っていません"])
    }

    @Test("往復編みでは逆順にアーチを探す：前段の最後のアーチから拾う")
    func reversedRows() {
        var pattern = Pattern(method: .flat, foundation: .chain(stitchCount: 10))
        // 1段目：長編み、鎖2、長編み、鎖2、長編み、鎖2、長編み（作り目 10 目を 1目ずつ拾って 3 目ずつ飛ばす形は考えず、目数だけ見る）
        pattern.rows.append(Row(steps: [
            .turningChain(3), .stitch(.chain), .stitch(.chain),
            .skip(), .skip(), .stitch(.doubleCrochet), .stitch(.chain), .stitch(.chain),
            .skip(), .skip(), .stitch(.doubleCrochet),
        ]))
        // 2段目：束に細編み3目 ×2
        pattern.rows.append(Row(steps: [
            .turningChain(1),
            .repeating([.increase(.singleCrochet, count: 3, into: .chainSpace)], times: 2),
        ]))
        let expansion = pattern.expanded()
        let row1 = expansion.rows[0]
        #expect(row1.totalCount == 7)  // 立ち上がり、鎖2、長編み、鎖2、長編み
        let row2 = expansion.rows[1]
        let stitches = row2.stitches.filter { $0.role == .regular }
        // 前段（編んだ順）：0 立ち上がり、1・2 鎖、3 長編み、4・5 鎖、6 長編み。逆順なので最初のアーチは 4・5
        #expect(stitches[0].picks == 4..<6)
        #expect(stitches[3].picks == 1..<3)
        #expect(row2.pickedCount == 6)  // 立ち上がり（0）は残る
        #expect(row2.nextPickIndex == 0)
    }

    @Test("「残りすべてに」：単位が収まる間だけ繰り返す。束の単位はアーチの数だけ、普通の単位は今までどおり")
    func untilEndGeneralized() {
        // 束＋長編みの単位：アーチ 12 個に対して「細編み、束に細編み3目」は 12 回で前段を使い切る
        var pattern = TestPatterns.tc4()
        pattern.rows.append(Row(steps: [
            .turningChain(1),
            .untilEnd([.stitch(.singleCrochet), .increase(.singleCrochet, count: 3, into: .chainSpace)]),
            .closeRound(),
        ]))
        let row = pattern.expanded().rows[2]
        #expect(row.totalCount == 48)
        #expect(row.pickedCount == 36)

        // 普通の単位は変わらない（TC-6：13目に（細編み、増し目）→ 6回、1目残る）
        let tc6 = TestPatterns.tc6().expanded().rows[1]
        #expect(tc6.repeatCounts.values.first == 6)
        #expect(tc6.unpickedCount == 1)

        // 「残りすべてに束に細編み」は単位が前段を拾うので選べる
        #expect(PatternInput.canRepeatUntilEnd(unit: [.stitch(.singleCrochet, into: .chainSpace)]))
    }

    @Test("目数表：「残りのアーチすべてに束に細編み3目編み入れる」")
    func tableText() {
        let pattern = TestPatterns.tc10()
        let rows = StitchTableFormatter.tableRows(for: pattern, expansion: pattern.expanded())
        #expect(rows[2].instruction == "束に細編み3目編み入れる×全目")
        #expect(rows[2].countText == "36目")
    }
}
