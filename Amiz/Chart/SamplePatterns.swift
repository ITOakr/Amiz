import CrochetCore

/// 確認用のサンプル編み図（ui-spec 8章）。プレビューと、環境変数 `AMIZ_SCREEN=sample` での起動に使う。
enum SamplePatterns {
    /// 「くまの頭」：domain-spec TC-1 と同じ内容（4段目まで完成し、5段目を入力中）
    static var bearHead: Pattern {
        func stitches(_ kind: StitchKind, _ count: Int) -> [Step] {
            (0..<count).map { _ in .stitch(kind) }
        }
        return Pattern(method: .joinedRounds, foundation: .magicRing, rows: [
            Row(steps: [.turningChain(1)] + stitches(.singleCrochet, 6) + [.closeRound()]),
            Row(steps: [.turningChain(1), .untilEnd([.increase(.singleCrochet)]), .closeRound()]),
            Row(steps: [.turningChain(1), .repeating([.stitch(.singleCrochet), .increase(.singleCrochet)], times: 6), .closeRound()]),
            Row(steps: [.turningChain(1), .repeating(stitches(.singleCrochet, 2) + [.increase(.singleCrochet)], times: 6), .closeRound()]),
            Row(steps: [.turningChain(1)] + stitches(.singleCrochet, 4)),
        ])
    }

    /// 「くまの頭（色付き）」：TC-11。糸は生成り・こげ茶・白。2段目がこげ茶、3段目の3回目の増し目（鼻）がこげ茶、4段目が白
    static var bearHeadColored: Pattern {
        let ivory = Yarn(name: "生成り", color: YarnColor(hex: "#EDE3D1")!)
        let brown = Yarn(name: "こげ茶", color: YarnColor(hex: "#5A3A22")!, memo: "品番 12")
        let white = Yarn(name: "白", color: YarnColor(hex: "#FFFFFF")!)
        var pattern = bearHead
        pattern.yarns = [ivory, brown, white]
        PatternInput.setYarn(brown.id, forRowAt: 1, in: &pattern)
        if case .repeatGroup(let unit, _) = pattern.rows[2].steps[1].kind {
            PatternInput.setYarn(brown.id, at: StitchRef(rowID: pattern.rows[2].id, stepID: unit[1].id, repetition: 2), in: &pattern)
        }
        PatternInput.setYarn(white.id, forRowAt: 3, in: &pattern)
        pattern.currentYarnID = white.id
        return pattern
    }

    /// 「花のモチーフ」：1段目は長編み12目、2段目は長編みと鎖2目の繰り返し（TC-4 と同じ内容）
    static var flowerMotif: Pattern {
        func stitches(_ kind: StitchKind, _ count: Int) -> [Step] {
            (0..<count).map { _ in .stitch(kind) }
        }
        return Pattern(method: .joinedRounds, foundation: .magicRing, rows: [
            Row(steps: [.turningChain(3)] + stitches(.doubleCrochet, 11) + [.closeRound()]),
            Row(steps: [
                .turningChain(3), .stitch(.chain), .stitch(.chain),
                .untilEnd([.stitch(.doubleCrochet), .stitch(.chain), .stitch(.chain)]),
                .closeRound(),
            ]),
            // 3段目：鎖のアーチに束で細編み3目ずつ（TC-10）
            Row(steps: [
                .turningChain(1),
                .untilEnd([.increase(.singleCrochet, count: 3, into: .chainSpace)]),
                .closeRound(),
            ]),
            Row(),
        ])
    }

    /// 「うさぎの胴体」：螺旋編み 12 段（domain-spec TC-8）。12段目まで完成し、13段目を入力中
    static var rabbitBody: Pattern {
        func stitches(_ kind: StitchKind, _ count: Int) -> [Step] {
            (0..<count).map { _ in .stitch(kind) }
        }
        return Pattern(method: .spiral, foundation: .magicRing, rows: [
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
            Row(),
        ])
    }

    /// 「ブランケットの縁」：往復編み 6 段、鎖の作り目 20 目（domain-spec TC-9）。6段目まで完成し、7段目を入力中
    static var blanketEdge: Pattern {
        func stitches(_ kind: StitchKind, _ count: Int) -> [Step] {
            (0..<count).map { _ in .stitch(kind) }
        }
        return Pattern(method: .flat, foundation: .chain(stitchCount: 20), rows: [
            Row(steps: [.turningChain(1)] + stitches(.singleCrochet, 20)),
            Row(steps: [.turningChain(3)] + stitches(.doubleCrochet, 19)),
            Row(steps: [.turningChain(1), .increase(.singleCrochet)] + stitches(.singleCrochet, 18) + [.increase(.singleCrochet)]),
            Row(steps: [.turningChain(2)] + stitches(.halfDoubleCrochet, 21)),
            Row(steps: [.turningChain(1), .decrease(.singleCrochet)] + stitches(.singleCrochet, 18) + [.decrease(.singleCrochet)]),
            Row(steps: [.turningChain(3)] + stitches(.doubleCrochet, 19)),
            Row(),
        ])
    }

    /// 性能確認用の大きな作品：わの作り目から毎段6目ずつ増える平らな円（rows 段で約 3×rows×(rows+1) 目）
    static func largeDisc(rows: Int) -> Pattern {
        func stitches(_ kind: StitchKind, _ count: Int) -> [Step] {
            (0..<count).map { _ in .stitch(kind) }
        }
        var result = Pattern(method: .joinedRounds, foundation: .magicRing)
        result.rows.append(Row(steps: [.turningChain(1)] + stitches(.singleCrochet, 6) + [.closeRound()]))
        for row in 2...max(rows, 2) {
            // 「（細編み row-2 目、増し目）×6」
            result.rows.append(Row(steps: [
                .turningChain(1),
                .repeating(stitches(.singleCrochet, row - 2) + [.increase(.singleCrochet)], times: 6),
                .closeRound(),
            ]))
        }
        return result
    }
}
