import CrochetCore

/// テストで使う編み図のサンプル。domain-spec.md のテストケースに対応する。
enum TestPatterns {
    /// 同じ種類の目を n 個並べる（それぞれ別の ID を持つ）
    static func stitches(_ kind: StitchKind, _ count: Int) -> [Step] {
        (0..<count).map { _ in .stitch(kind) }
    }

    /// TC-8 螺旋編み「うさぎの胴体」（12段。立ち上がりも引き抜きもない）
    ///
    /// 6→12→18→24→30→30×4→24→18→12。`rows` で先頭から何段ぶん含めるかを指定できる（既定は12段すべて）
    static func tc8(rows count: Int = 12) -> Pattern {
        let rows: [Row] = [
            Row(steps: stitches(.singleCrochet, 6)),
            Row(steps: [.untilEnd([.increase(.singleCrochet)])]),
            Row(steps: [.repeating([.stitch(.singleCrochet), .increase(.singleCrochet)], times: 6)]),
            Row(steps: [.repeating(stitches(.singleCrochet, 2) + [.increase(.singleCrochet)], times: 6)]),
            Row(steps: [.repeating(stitches(.singleCrochet, 3) + [.increase(.singleCrochet)], times: 6)]),
            Row(steps: [.untilEnd([.stitch(.singleCrochet)])]),
            Row(steps: [.untilEnd([.stitch(.singleCrochet)])]),
            Row(steps: [.untilEnd([.stitch(.singleCrochet)])]),
            Row(steps: [.untilEnd([.stitch(.singleCrochet)])]),
            Row(steps: [.repeating(stitches(.singleCrochet, 3) + [.decrease(.singleCrochet)], times: 6)]),
            Row(steps: [.repeating(stitches(.singleCrochet, 2) + [.decrease(.singleCrochet)], times: 6)]),
            Row(steps: [.repeating([.stitch(.singleCrochet), .decrease(.singleCrochet)], times: 6)]),
        ]
        return Pattern(method: .spiral, foundation: .magicRing, rows: Array(rows.prefix(count)))
    }

    /// TC-9 往復編み「ブランケットの縁」（鎖の作り目 20 目、6段）。`rows` で先頭から何段ぶん含めるか
    static func tc9(rows count: Int = 6) -> Pattern {
        let rows: [Row] = [
            Row(steps: [.turningChain(1)] + stitches(.singleCrochet, 20)),
            Row(steps: [.turningChain(3)] + stitches(.doubleCrochet, 19)),
            Row(steps: [.turningChain(1), .increase(.singleCrochet)] + stitches(.singleCrochet, 18) + [.increase(.singleCrochet)]),
            Row(steps: [.turningChain(2)] + stitches(.halfDoubleCrochet, 21)),
            Row(steps: [.turningChain(1), .decrease(.singleCrochet)] + stitches(.singleCrochet, 18) + [.decrease(.singleCrochet)]),
            Row(steps: [.turningChain(3)] + stitches(.doubleCrochet, 19)),
        ]
        return Pattern(method: .flat, foundation: .chain(stitchCount: 20), rows: Array(rows.prefix(count)))
    }

    /// TC-13 玉編み：前段12目に「立ち上がり鎖2目（数える）、（鎖1目、中長編み3目の玉編み）×11、鎖1目、引き抜き」
    static func tc13() -> Pattern {
        afterRound(of: 12, row: Row(steps: [
            .turningChain(2),
            .repeating([.stitch(.chain), .cluster(.halfDoubleCrochet, count: 3)], times: 11),
            .stitch(.chain),
            .closeRound(),
        ]))
    }

    /// TC-14 ピコット：前段12目に「細編み2目、ピコット、（細編み3目、ピコット）×3、細編み1目、引き抜き」
    static func tc14() -> Pattern {
        afterRound(of: 12, row: Row(steps: [
            .turningChain(1),
            .stitch(.singleCrochet), .stitch(.singleCrochet), .picot(),
            .repeating(stitches(.singleCrochet, 3) + [.picot()], times: 3),
            .stitch(.singleCrochet),
            .closeRound(),
        ]))
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

    /// TC-2 TC-1 の1段目を「わの作り目に細編み7目」に修正し、「上の段を残す」を選んだ状態
    static func tc2AfterKeepingRowsAbove() -> Pattern {
        var pattern = tc1()
        pattern.rows[0] = Row(
            id: pattern.rows[0].id,
            steps: [.turningChain(1)] + stitches(.singleCrochet, 7) + [.closeRound()]
        )
        return pattern
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

    /// TC-10 花のモチーフ 3段目：TC-4 の段（長編み1目、鎖2目 ×12。合計36目）に続けて、
    /// 「立ち上がり鎖1目、残りのアーチすべてに束に細編み3目編み入れる、引き抜き」
    static func tc10() -> Pattern {
        var pattern = tc4()
        pattern.rows.append(Row(steps: [
            .turningChain(1),
            .untilEnd([.increase(.singleCrochet, count: 3, into: .chainSpace)]),
            .closeRound(),
        ]))
        return pattern
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
