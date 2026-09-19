import Foundation
import Testing
@testable import CrochetCore

@Suite("編み図の JSON 変換")
struct PatternCodingTests {
    /// テスト用の固定 ID。`id(0x11)` → 00000000-0000-0000-0000-000000000011
    private func id(_ n: Int) -> UUID {
        UUID(uuidString: String(format: "00000000-0000-0000-0000-%012X", n))!
    }

    @Test("TC-1 の編み図を JSON にして戻すと元と等しい")
    func roundTripTC1() throws {
        let original = TestPatterns.tc1()
        let data = try original.jsonData()
        let decoded = try Pattern(jsonData: data)
        #expect(decoded == original)
    }

    @Test("保存形式：手書きの JSON を読むと期待した型になり、書き戻すと同じ JSON になる")
    func fixedFormat() throws {
        // 保存形式を固定するためのテスト。この JSON が読めなくなる変更は、古いデータが読めなくなる変更。
        let json = """
        {
          "schemaVersion": 1,
          "method": "joinedRounds",
          "foundation": { "type": "magicRing" },
          "rows": [
            { "id": "00000000-0000-0000-0000-000000000001", "steps": [
              { "id": "00000000-0000-0000-0000-000000000011", "type": "turningChain", "chains": 1 },
              { "id": "00000000-0000-0000-0000-000000000012", "type": "repeat", "count": 6, "unit": [
                { "id": "00000000-0000-0000-0000-000000000013", "type": "stitch", "stitch": "singleCrochet", "into": "stitch" },
                { "id": "00000000-0000-0000-0000-000000000014", "type": "increase", "stitch": "singleCrochet", "count": 2, "into": "stitch" }
              ]},
              { "id": "00000000-0000-0000-0000-000000000015", "type": "closeRound" }
            ]},
            { "id": "00000000-0000-0000-0000-000000000002", "steps": [
              { "id": "00000000-0000-0000-0000-000000000021", "type": "repeat", "count": "untilEnd", "unit": [
                { "id": "00000000-0000-0000-0000-000000000022", "type": "decrease", "stitch": "doubleCrochet", "count": 3 }
              ]},
              { "id": "00000000-0000-0000-0000-000000000023", "type": "skip" },
              { "id": "00000000-0000-0000-0000-000000000024", "type": "stitch", "stitch": "chain", "into": "stitch" },
              { "id": "00000000-0000-0000-0000-000000000025", "type": "increase", "stitch": "halfDoubleCrochet", "count": 3, "into": "chainSpace" },
              { "id": "00000000-0000-0000-0000-000000000026", "type": "leaveRemaining" }
            ]}
          ]
        }
        """

        let expected = Pattern(method: .joinedRounds, foundation: .magicRing, rows: [
            Row(id: id(0x01), steps: [
                Step(id: id(0x11), kind: .turningChain(chains: 1)),
                Step(id: id(0x12), kind: .repeatGroup(unit: [
                    Step(id: id(0x13), kind: .stitch(.singleCrochet)),
                    Step(id: id(0x14), kind: .increase(.singleCrochet, count: 2)),
                ], count: .times(6))),
                Step(id: id(0x15), kind: .closeRound),
            ]),
            Row(id: id(0x02), steps: [
                Step(id: id(0x21), kind: .repeatGroup(unit: [
                    Step(id: id(0x22), kind: .decrease(.doubleCrochet, count: 3)),
                ], count: .untilEnd)),
                Step(id: id(0x23), kind: .skip),
                Step(id: id(0x24), kind: .stitch(.chain)),
                Step(id: id(0x25), kind: .increase(.halfDoubleCrochet, count: 3, into: .chainSpace)),
                Step(id: id(0x26), kind: .leaveRemaining),
            ]),
        ])

        // 読み込み
        let decoded = try Pattern(jsonData: Data(json.utf8))
        #expect(decoded == expected)

        // 書き戻し。キーの順序や空白の違いは無視して、中身が同じかを比べる
        let written = try JSONSerialization.jsonObject(with: expected.jsonData()) as? NSDictionary
        let source = try JSONSerialization.jsonObject(with: Data(json.utf8)) as? NSDictionary
        #expect(written == source)
    }

    @Test("鎖の作り目と往復編みの保存形式")
    func chainFoundation() throws {
        let pattern = Pattern(method: .flat, foundation: .chain(stitchCount: 20))
        let json = String(decoding: try pattern.jsonData(), as: UTF8.self)
        #expect(json == #"{"foundation":{"stitchCount":20,"type":"chain"},"method":"flat","rows":[],"schemaVersion":1}"#)
        #expect(try Pattern(jsonData: Data(json.utf8)) == pattern)
    }

    @Test("知らない操作の種類は読み込みエラーになる")
    func unknownStepType() {
        let json = #"""
        {"schemaVersion":1,"method":"flat","foundation":{"type":"magicRing"},
         "rows":[{"id":"00000000-0000-0000-0000-000000000001","steps":[
           {"id":"00000000-0000-0000-0000-000000000002","type":"popcorn"}]}]}
        """#
        #expect(throws: DecodingError.self) {
            try Pattern(jsonData: Data(json.utf8))
        }
    }

    @Test("繰り返しの回数が整数でも untilEnd でもなければ読み込みエラーになる")
    func invalidRepeatCount() {
        let json = #"""
        {"schemaVersion":1,"method":"flat","foundation":{"type":"magicRing"},
         "rows":[{"id":"00000000-0000-0000-0000-000000000001","steps":[
           {"id":"00000000-0000-0000-0000-000000000002","type":"repeat","count":"forever","unit":[]}]}]}
        """#
        #expect(throws: DecodingError.self) {
            try Pattern(jsonData: Data(json.utf8))
        }
    }
}
