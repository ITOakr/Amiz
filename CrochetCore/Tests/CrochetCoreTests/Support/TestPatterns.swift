import CrochetCore

/// テストで使う編み図のサンプル。domain-spec.md のテストケースに対応する。
enum TestPatterns {
    /// 同じ種類の目を n 個並べる（それぞれ別の ID を持つ）
    static func stitches(_ kind: StitchKind, _ count: Int) -> [Step] {
        (0..<count).map { _ in .stitch(kind) }
    }

    /// TC-1 わの作り目からの輪編み（細編み）
    ///
    /// | 段 | 手順 | 目数 |
    /// |---|---|---|
    /// | 1 | わの作り目に細編み6目、1目めに引き抜き | 6 |
    /// | 2 | 全目に増し目 | 12 |
    /// | 3 | （細編み1目、増し目）×6 | 18 |
    /// | 4 | （細編み2目、増し目）×6 | 24 |
    /// | 5 | 残りの目すべてに細編み | 24 |
    static func tc1() -> Pattern {
        Pattern(method: .joinedRounds, foundation: .magicRing, rows: [
            Row(steps: [.turningChain(1)] + stitches(.singleCrochet, 6) + [.closeRound()]),
            Row(steps: [
                .turningChain(1),
                .untilEnd([.increase(.singleCrochet)]),
                .closeRound(),
            ]),
            Row(steps: [
                .turningChain(1),
                .repeating([.stitch(.singleCrochet), .increase(.singleCrochet)], times: 6),
                .closeRound(),
            ]),
            Row(steps: [
                .turningChain(1),
                .repeating(stitches(.singleCrochet, 2) + [.increase(.singleCrochet)], times: 6),
                .closeRound(),
            ]),
            Row(steps: [
                .turningChain(1),
                .untilEnd([.stitch(.singleCrochet)]),
                .closeRound(),
            ]),
        ])
    }
}
