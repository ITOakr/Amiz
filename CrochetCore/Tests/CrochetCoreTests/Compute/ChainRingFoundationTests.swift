import Foundation
import Testing
@testable import CrochetCore

/// 鎖を輪にした作り目（domain-spec 33。AMIZ-76）
@Suite("鎖を輪にした作り目")
struct ChainRingFoundationTests {
    /// 鎖6目を輪にして、その中に1段目「立ち上がり鎖3目、長編み15目、引き抜き」＝16目
    private func motif(chainCount: Int = 6) -> Pattern {
        Pattern(method: .joinedRounds, foundation: .chainRing(chainCount: chainCount), rows: [
            Row(steps: [.turningChain(3)] + TestPatterns.stitches(.doubleCrochet, 15) + [.closeRound()]),
        ])
    }

    @Test("JSON の書き出しと読み込みが往復する")
    func jsonRoundTrip() throws {
        let pattern = motif()
        let restored = try Pattern(jsonData: pattern.jsonData())

        #expect(restored.foundation == .chainRing(chainCount: 6))
        #expect(restored.rows.count == 1)

        // JSON の形（tech-spec 5-4）
        let text = String(decoding: try pattern.jsonData(), as: UTF8.self)
        #expect(text.contains("\"type\":\"chainRing\""))
        #expect(text.contains("\"chainCount\":6"))
    }

    @Test("輪にする鎖の目数が 0 以下の JSON は読み込みエラーになる")
    func invalidChainCount() {
        for value in ["0", "-6"] {
            let json = Data("""
            {"schemaVersion":2,"method":"joinedRounds",
             "foundation":{"type":"chainRing","chainCount":\(value)},"yarns":[],"rows":[]}
            """.utf8)
            #expect(throws: DecodingError.self) { _ = try Pattern(jsonData: json) }
        }
    }

    @Test("鎖の目数に上限は付けない（大きな輪の編み始めが実際にある）")
    func largeChainRing() throws {
        let json = Data("""
        {"schemaVersion":2,"method":"joinedRounds",
         "foundation":{"type":"chainRing","chainCount":120},"yarns":[],"rows":[]}
        """.utf8)
        #expect(try Pattern(jsonData: json).foundation == .chainRing(chainCount: 120))
    }

    @Test("1段目を輪の中に編み入れて展開でき、目数が数えられる")
    func expandsFirstRow() {
        let expansion = motif().expanded()

        #expect(expansion.rows.count == 1)
        // 立ち上がりの鎖3目を1目と数え（domain-spec 6）、長編み15目と合わせて16目
        #expect(expansion.rows[0].totalCount == 16)
    }

    @Test("1段目は整合性チェックの対象外（何目でも警告が出ない）")
    func firstRowHasNoWarning() {
        // 前段の目数を持たないので、1目でも 40 目でも警告は出ない
        for count in [1, 15, 40] {
            let pattern = Pattern(method: .joinedRounds, foundation: .chainRing(chainCount: 6), rows: [
                Row(steps: [.turningChain(3)] + TestPatterns.stitches(.doubleCrochet, count) + [.closeRound()]),
            ])
            #expect(pattern.expanded().warnings().isEmpty)
        }
        // わの作り目と同じ扱いであること
        #expect(Expander.initialPreviousCount(for: .chainRing(chainCount: 6)) == nil)
    }

    @Test("2段目からは普通に前段を拾い、整合性チェックの対象になる")
    func secondRowIsChecked() {
        let pattern = Pattern(method: .joinedRounds, foundation: .chainRing(chainCount: 6), rows: [
            Row(steps: [.turningChain(3)] + TestPatterns.stitches(.doubleCrochet, 15) + [.closeRound()]),
            // 前段16目に対して14目しか拾わない
            Row(steps: [.turningChain(3)] + TestPatterns.stitches(.doubleCrochet, 13) + [.closeRound()]),
        ])
        let warnings = pattern.expanded().warnings()

        #expect(warnings.map(\.rowNumber) == [2])
        #expect(warnings.first?.message == "前段16目のうち14目しか拾っていません")
    }

    @Test("目数表の作り目の行と、1段目の手順の頭")
    func tableText() {
        let pattern = motif()

        #expect(StitchTableFormatter.foundationText(for: pattern) == "作り目：鎖6目を輪にする")
        // 鎖の作り目と違い、実際に編む鎖の目数を計算する必要はない（保存した目数がそのまま）
        #expect(StitchTableFormatter.foundationChainCount(for: pattern) == nil)

        let instruction = StitchTableFormatter.instruction(for: pattern.rows[0], rowIndex: 0, in: pattern)
        // 目数表は数える立ち上がりも項目として書く
        #expect(instruction == "鎖の輪の中に立ち上がり鎖3目、長編み15目")
    }

    @Test("作り目の日本語名")
    func japaneseName() {
        #expect(FoundationKind.chainRing(chainCount: 6).japaneseName == "鎖を輪にした作り目")
    }
}
