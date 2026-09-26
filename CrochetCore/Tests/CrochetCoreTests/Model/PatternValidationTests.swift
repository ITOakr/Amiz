import Foundation
import Testing
@testable import CrochetCore

/// 壊れた JSON で落ちないこと（AMIZ-67）。読み込みの時点でエラーにする
@Suite("壊れたデータの読み込み")
struct PatternValidationTests {
    /// 1つの操作だけを持つ編み図の JSON
    private func json(step: String) -> Data {
        Data("""
        {"schemaVersion":2,"method":"joinedRounds","foundation":{"type":"magicRing"},"yarns":[],
         "rows":[{"id":"00000000-0000-0000-0000-000000000001","steps":[\(step)]}]}
        """.utf8)
    }

    private func step(_ body: String) -> String {
        "{\"id\":\"00000000-0000-0000-0000-000000000011\",\(body)}"
    }

    @Test("負の目数・0・大きすぎる値は読み込みエラーになる（落ちない）")
    func invalidCounts() {
        let bad = [
            step("\"type\":\"increase\",\"stitch\":\"singleCrochet\",\"count\":-3,\"into\":\"stitch\""),
            step("\"type\":\"increase\",\"stitch\":\"singleCrochet\",\"count\":0,\"into\":\"stitch\""),
            step("\"type\":\"increase\",\"stitch\":\"singleCrochet\",\"count\":1,\"into\":\"stitch\""),
            step("\"type\":\"decrease\",\"stitch\":\"singleCrochet\",\"count\":-1"),
            step("\"type\":\"cluster\",\"stitch\":\"doubleCrochet\",\"count\":0,\"into\":\"stitch\""),
            step("\"type\":\"cluster\",\"stitch\":\"doubleCrochet\",\"count\":1000,\"into\":\"stitch\""),
            step("\"type\":\"turningChain\",\"chains\":0"),
            step("\"type\":\"turningChain\",\"chains\":-2"),
            step("\"type\":\"picot\",\"chains\":0"),
            step("\"type\":\"repeat\",\"count\":-5,\"unit\":[]"),
        ]
        for text in bad {
            #expect(throws: DecodingError.self) {
                _ = try Pattern(jsonData: json(step: text))
            }
        }
    }

    @Test("正しい値は今までどおり読める")
    func validCounts() throws {
        let good = [
            step("\"type\":\"increase\",\"stitch\":\"singleCrochet\",\"count\":2,\"into\":\"stitch\""),
            step("\"type\":\"decrease\",\"stitch\":\"singleCrochet\",\"count\":3"),
            step("\"type\":\"cluster\",\"stitch\":\"doubleCrochet\",\"count\":5,\"into\":\"chainSpace\""),
            step("\"type\":\"turningChain\",\"chains\":3"),
            step("\"type\":\"picot\",\"chains\":3"),
            step("\"type\":\"repeat\",\"count\":0,\"unit\":[]"),
            step("\"type\":\"repeat\",\"count\":\"untilEnd\",\"unit\":[]"),
        ]
        for text in good {
            let pattern = try Pattern(jsonData: json(step: text))
            #expect(pattern.rows[0].steps.count == 1)
            _ = pattern.expanded()  // 展開しても落ちない
        }
    }

    @Test("鎖の作り目の目数が 0 以下なら読み込みエラー")
    func invalidFoundation() {
        let text = """
        {"schemaVersion":2,"method":"flat","foundation":{"type":"chain","stitchCount":0},"yarns":[],"rows":[]}
        """
        #expect(throws: DecodingError.self) {
            _ = try Pattern(jsonData: Data(text.utf8))
        }
    }

    @Test("展開は万一おかしな値でも落ちない（多重防御）")
    func expanderIsSafe() {
        // 読み込みを通さず、コードから直接おかしな値を作った場合
        var pattern = Pattern(method: .joinedRounds, foundation: .magicRing)
        pattern.rows = [Row(steps: [
            .increase(.singleCrochet, count: 0),
            .decrease(.singleCrochet, count: -2),
            .repeating([.stitch(.singleCrochet)], times: -3),
        ])]
        let expansion = pattern.expanded()
        #expect(expansion.rows[0].totalCount >= 0)
        #expect(pattern.circularLayout().stitches.isEmpty == false)
    }
}
