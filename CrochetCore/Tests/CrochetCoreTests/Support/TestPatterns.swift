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

    /// 「前段 n 目」を用意するための1段目（わの作り目に細編み n 目）と、その上に test 用の段を1つ載せた編み図
    static func afterRound(of previousCount: Int, row: Row) -> Pattern {
        Pattern(method: .joinedRounds, foundation: .magicRing, rows: [
            Row(steps: [.turningChain(1)] + stitches(.singleCrochet, previousCount) + [.closeRound()]),
            row,
        ])
    }

    /// TC-3 長編みの段の立ち上がり：前段12目に「立ち上がり鎖3目、長編み11目、引き抜き」
    static func tc3() -> Pattern {
        afterRound(of: 12, row: Row(steps: [.turningChain(3)] + stitches(.doubleCrochet, 11) + [.closeRound()]))
    }

    /// TC-4 鎖を含む段：前段12目に「立ち上がり鎖3目、鎖2目、（長編み1目、鎖2目）×11、引き抜き」
    static func tc4() -> Pattern {
        afterRound(of: 12, row: Row(steps: [
            .turningChain(3),
            .stitch(.chain), .stitch(.chain),
            .repeating([.stitch(.doubleCrochet), .stitch(.chain), .stitch(.chain)], times: 11),
            .closeRound(),
        ]))
    }

    /// TC-6 割り切れない場合：前段13目に「（細編み1目、増し目）を段の終わりまで」
    static func tc6(leaveRemaining: Bool = false) -> Pattern {
        var steps: [Step] = [
            .turningChain(1),
            .untilEnd([.stitch(.singleCrochet), .increase(.singleCrochet)]),
        ]
        if leaveRemaining {
            steps.append(.leaveRemaining())
        }
        steps.append(.closeRound())
        return afterRound(of: 13, row: Row(steps: steps))
    }
}
