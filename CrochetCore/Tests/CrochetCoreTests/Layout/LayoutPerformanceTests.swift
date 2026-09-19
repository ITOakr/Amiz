import Foundation
import Testing
@testable import CrochetCore

@Suite("大きな作品での計算時間（tech-spec 13「描画の性能」の一部）")
struct LayoutPerformanceTests {
    /// 毎段6目ずつ増える平らな円を rows 段（約 3×rows×(rows+1) 目）
    private func largeDisc(rows: Int) -> Pattern {
        var pattern = Pattern(method: .joinedRounds, foundation: .magicRing)
        pattern.rows.append(Row(steps: [.turningChain(1)] + TestPatterns.stitches(.singleCrochet, 6) + [.closeRound()]))
        for row in 2...rows {
            pattern.rows.append(Row(steps: [
                .turningChain(1),
                .repeating(TestPatterns.stitches(.singleCrochet, row - 2) + [.increase(.singleCrochet)], times: 6),
                .closeRound(),
            ]))
        }
        return pattern
    }

    @Test("40段・約4900目の展開とレイアウトが 0.5 秒以内に終わる")
    func fiveThousandStitches() {
        let pattern = largeDisc(rows: 40)
        let start = Date()
        let expansion = pattern.expanded()
        let layout = pattern.circularLayout(expansion: expansion)
        let elapsed = Date().timeIntervalSince(start)

        #expect(expansion.rows.last?.totalCount == 240)
        #expect(layout.stitches.count > 4900)
        #expect(elapsed < 0.5, "展開＋レイアウトに \(elapsed) 秒")
    }
}
