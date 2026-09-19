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
            Row(),
        ])
    }
}
