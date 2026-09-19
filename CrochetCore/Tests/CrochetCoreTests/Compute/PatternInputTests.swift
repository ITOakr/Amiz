import Testing
@testable import CrochetCore

@Suite("キーボード操作の編み図への適用（ui-spec 5-6）")
struct PatternInputTests {
    /// 「残りすべてに」＋「2目編み入れる」
    private var untilEndIncrease: StitchModifier {
        var modifier = StitchModifier()
        modifier.toggleUntilEnd()
        modifier.toggleIncrease()
        return modifier
    }

    @Test("TC-1「くまの頭」をボタン操作の列で組み立てると、手順も目数も TestPatterns.tc1() と一致する")
    func buildTC1ByPresses() {
        var pattern = Pattern(method: .joinedRounds, foundation: .magicRing)

        // 1段目：細編み×6（最初の細編みで立ち上がり鎖1が自動で入る）、段を終える
        for _ in 0..<6 { PatternInput.addStitch(.singleCrochet, to: &pattern) }
        PatternInput.finishRow(of: &pattern)

        // 2段目：「残りすべてに」「2目編み入れる」→ 細編み
        PatternInput.addStitch(.singleCrochet, modifier: untilEndIncrease, to: &pattern)
        PatternInput.finishRow(of: &pattern)

        // 3段目：繰り返し開始 → 細編み、2目編み入れる＋細編み → 繰り返し終了 ×6
        var increase = StitchModifier()
        increase.toggleIncrease()
        let start3 = pattern.rows[2].steps.count  // 0（繰り返し開始を押した時点の操作数）
        PatternInput.addStitch(.singleCrochet, to: &pattern)
        PatternInput.addStitch(.singleCrochet, modifier: increase, to: &pattern)
        #expect(PatternInput.wrapRepeat(from: start3, count: .times(6), in: &pattern))
        PatternInput.finishRow(of: &pattern)

        // 4段目：（細編み2目、増し目）×6
        let start4 = pattern.rows[3].steps.count
        PatternInput.addStitch(.singleCrochet, to: &pattern)
        PatternInput.addStitch(.singleCrochet, to: &pattern)
        PatternInput.addStitch(.singleCrochet, modifier: increase, to: &pattern)
        #expect(PatternInput.wrapRepeat(from: start4, count: .times(6), in: &pattern))
        PatternInput.finishRow(of: &pattern)

        // 5段目：「残りすべてに」→ 細編み、段を終える
        var untilEnd = StitchModifier()
        untilEnd.toggleUntilEnd()
        PatternInput.addStitch(.singleCrochet, modifier: untilEnd, to: &pattern)
        PatternInput.finishRow(of: &pattern)

        // 段を終えた後は空の6段目が入力中
        #expect(pattern.rows.count == 6)
        #expect(pattern.rows[5].steps.isEmpty)

        let expected = TestPatterns.tc1()
        for index in 0..<5 {
            #expect(pattern.rows[index].hasSameSteps(as: expected.rows[index]), "\(index + 1)段目の手順")
        }
        #expect(pattern.expanded().rows.prefix(5).map(\.totalCount) == [6, 12, 18, 24, 24])
    }

    @Test("立ち上がりの自動挿入：最初の目の種類で鎖の目数が決まる", arguments: [
        (StitchKind.singleCrochet, 1), (.halfDoubleCrochet, 2), (.doubleCrochet, 3), (.trebleCrochet, 4),
    ])
    func autoTurningChain(kind: StitchKind, chains: Int) {
        var pattern = TestPatterns.afterRound(of: 12, row: Row())
        let inserted = PatternInput.addStitch(kind, to: &pattern)

        #expect(inserted)
        #expect(pattern.rows[1].steps.first?.kind == .turningChain(chains: chains))
        #expect(pattern.rows[1].steps.count == 2)
    }

    @Test("立ち上がりの自動挿入：鎖から始まる段では、最初の鎖以外の目を押したときに先頭に入る")
    func autoTurningChainAfterChains() {
        var pattern = TestPatterns.afterRound(of: 12, row: Row())
        #expect(!PatternInput.addStitch(.chain, to: &pattern))
        #expect(!PatternInput.addStitch(.chain, to: &pattern))
        #expect(PatternInput.addStitch(.doubleCrochet, to: &pattern))

        let kinds = pattern.rows[1].steps.map(\.kind)
        #expect(kinds == [.turningChain(chains: 3), .stitch(.chain), .stitch(.chain), .stitch(.doubleCrochet)])
    }

    @Test("立ち上がりの自動挿入：段ごとに1回だけ。引き抜き編みが最初なら入れない。設定オフや螺旋編みでは入れない")
    func autoTurningChainRules() {
        // 2目めでは入らない
        var pattern = TestPatterns.afterRound(of: 12, row: Row())
        PatternInput.addStitch(.singleCrochet, to: &pattern)
        #expect(!PatternInput.addStitch(.doubleCrochet, to: &pattern))
        #expect(pattern.rows[1].steps.count == 3)

        // 引き抜き編み
        var slip = TestPatterns.afterRound(of: 12, row: Row())
        #expect(!PatternInput.addStitch(.slipStitch, to: &slip))
        #expect(slip.rows[1].steps.count == 1)

        // 設定オフ
        var off = TestPatterns.afterRound(of: 12, row: Row())
        #expect(!PatternInput.addStitch(.singleCrochet, autoTurningChain: false, to: &off))
        #expect(off.rows[1].steps.count == 1)

        // 螺旋編み
        var spiral = Pattern(method: .spiral, foundation: .magicRing)
        #expect(!PatternInput.addStitch(.singleCrochet, to: &spiral))
        #expect(spiral.rows[0].steps.count == 1)
    }

    @Test("「残りすべてに」を鎖編みに付けても、鎖は前段を拾わないので普通の鎖になる")
    func untilEndWithChainFallsBack() {
        var pattern = TestPatterns.afterRound(of: 12, row: Row())
        var modifier = StitchModifier()
        modifier.toggleUntilEnd()
        PatternInput.addStitch(.chain, modifier: modifier, to: &pattern)

        #expect(pattern.rows[1].steps.map(\.kind) == [.stitch(.chain)])
    }

    @Test("段を終える：輪編みは段を閉じる引き抜きを足し、往復編み・螺旋編みは足さない。どちらも次の空の段ができる")
    func finishRow() {
        var round = Pattern(method: .joinedRounds, foundation: .magicRing)
        PatternInput.addStitch(.singleCrochet, to: &round)
        PatternInput.finishRow(of: &round)
        #expect(round.rows.count == 2)
        #expect(round.rows[0].steps.last?.kind == .closeRound)

        for method in [WorkingMethod.flat, .spiral] {
            var pattern = Pattern(method: method, foundation: .magicRing)
            PatternInput.addStitch(.singleCrochet, to: &pattern)
            PatternInput.finishRow(of: &pattern)
            #expect(pattern.rows.count == 2)
            #expect(pattern.rows[0].steps.last?.kind != .closeRound)
        }
    }

    @Test("1目削除：最後の操作を消す。繰り返しは丸ごと。空の段では「段を終える」を取り消す")
    func deleteLastStep() {
        var pattern = TestPatterns.tc1()
        PatternInput.finishRow(of: &pattern)  // 空の6段目
        #expect(pattern.rows.count == 6)

        // 空の段で削除 → 6段目が消え、5段目の引き抜きが外れて入力中に戻る
        #expect(PatternInput.deleteLastStep(from: &pattern))
        #expect(pattern.rows.count == 5)
        #expect(pattern.rows[4].steps.last?.kind != .closeRound)

        // 5段目の残り（立ち上がり、残りすべてに細編み）：繰り返しごと消える
        #expect(PatternInput.deleteLastStep(from: &pattern))
        #expect(pattern.rows[4].steps.map(\.kind) == [.turningChain(chains: 1)])
        #expect(PatternInput.deleteLastStep(from: &pattern))
        #expect(pattern.rows[4].steps.isEmpty)

        // 何もない編み図では何も起きない
        var empty = Pattern(method: .joinedRounds, foundation: .magicRing)
        #expect(!PatternInput.deleteLastStep(from: &empty))
    }

    @Test("繰り返し終了：立ち上がりは含めない。空・入れ子・段の終わりまでで拾わない単位はまとめない")
    func wrapRepeat() {
        // 単位が空
        var pattern = TestPatterns.afterRound(of: 12, row: Row())
        #expect(!PatternInput.wrapRepeat(from: 0, count: .times(6), in: &pattern))

        // 立ち上がりだけの段（開始位置 0 でも立ち上がりは除く）
        PatternInput.addStitch(.singleCrochet, to: &pattern)
        PatternInput.deleteLastStep(from: &pattern)
        #expect(pattern.rows[1].steps.count == 1)
        #expect(!PatternInput.wrapRepeat(from: 0, count: .times(6), in: &pattern))

        // 鎖だけの単位を「段の終わりまで」にはできない
        PatternInput.addStitch(.chain, to: &pattern)
        #expect(!PatternInput.wrapRepeat(from: 1, count: .untilEnd, in: &pattern))
        #expect(PatternInput.wrapRepeat(from: 1, count: .times(3), in: &pattern))

        // 繰り返しを含む範囲は入れ子になるのでまとめない
        #expect(!PatternInput.wrapRepeat(from: 1, count: .times(2), in: &pattern))
    }

    @Test("飛ばす：前段の目が残っていなければ何もしない")
    func skip() {
        var pattern = TestPatterns.afterRound(of: 2, row: Row())
        #expect(PatternInput.addSkip(to: &pattern))
        #expect(PatternInput.addSkip(to: &pattern))
        #expect(!PatternInput.addSkip(to: &pattern))
        #expect(pattern.rows[1].steps.count == 2)

        // わの作り目の1段目は前段の目数がないので、いつでも飛ばせる（意味はないが止めない）
        var ring = Pattern(method: .joinedRounds, foundation: .magicRing)
        #expect(PatternInput.addSkip(to: &ring))
    }

    @Test("立ち上がりボタン：なければ先頭に入れ、あれば目数を変える。螺旋編みでは何もしない")
    func setTurningChain() {
        var pattern = TestPatterns.afterRound(of: 12, row: Row())
        PatternInput.addStitch(.chain, to: &pattern)
        PatternInput.setTurningChain(chains: 3, in: &pattern)
        #expect(pattern.rows[1].steps.map(\.kind) == [.turningChain(chains: 3), .stitch(.chain)])

        let id = pattern.rows[1].steps[0].id
        PatternInput.setTurningChain(chains: 2, in: &pattern)
        #expect(pattern.rows[1].steps[0].kind == .turningChain(chains: 2))
        #expect(pattern.rows[1].steps[0].id == id)

        PatternInput.setTurningChain(chains: 9, in: &pattern)  // 範囲外は無視
        #expect(pattern.rows[1].steps[0].kind == .turningChain(chains: 2))

        var spiral = Pattern(method: .spiral, foundation: .magicRing)
        PatternInput.setTurningChain(chains: 1, in: &spiral)
        #expect(spiral.rows.isEmpty)
    }
}

@Suite("先に選ぶボタンの状態（ui-spec 5-6）")
struct StitchModifierTests {
    @Test("2目編み入れるは 2 → 3 → 解除")
    func toggleIncrease() {
        var modifier = StitchModifier()
        modifier.toggleIncrease()
        #expect(modifier.group == .increase(count: 2))
        modifier.toggleIncrease()
        #expect(modifier.group == .increase(count: 3))
        modifier.toggleIncrease()
        #expect(modifier.group == nil)
        #expect(!modifier.isActive)
    }

    @Test("2目編み入れると2目一度は同時に選べない")
    func increaseAndDecreaseAreExclusive() {
        var modifier = StitchModifier()
        modifier.toggleIncrease()
        modifier.toggleDecrease()
        #expect(modifier.group == .decrease(count: 2))
        modifier.toggleIncrease()
        #expect(modifier.group == .increase(count: 2))
    }

    @Test("束にと2目一度は同時に選べない。束にと2目編み入れる、残りすべてには同時に選べる")
    func chainSpaceRules() {
        var modifier = StitchModifier()
        modifier.toggleChainSpace()
        modifier.toggleDecrease()
        #expect(!modifier.chainSpace)
        #expect(modifier.group == .decrease(count: 2))

        modifier.toggleChainSpace()
        #expect(modifier.chainSpace)
        #expect(modifier.group == nil)

        modifier.toggleIncrease()
        modifier.toggleUntilEnd()
        #expect(modifier == StitchModifier(group: .increase(count: 2), chainSpace: true, untilEnd: true))
    }

    @Test("目ボタンを押したときの操作への変換")
    func stepConversion() {
        #expect(StitchModifier.none.step(for: .singleCrochet).kind == .stitch(.singleCrochet))
        #expect(StitchModifier(group: .increase(count: 3)).step(for: .singleCrochet).kind == .increase(.singleCrochet, count: 3))
        #expect(StitchModifier(group: .decrease(count: 2)).step(for: .doubleCrochet).kind == .decrease(.doubleCrochet, count: 2))
        #expect(StitchModifier(chainSpace: true).step(for: .singleCrochet).kind == .stitch(.singleCrochet, into: .chainSpace))

        let untilEnd = StitchModifier(group: .increase(count: 2), untilEnd: true).step(for: .singleCrochet)
        guard case .repeatGroup(let unit, .untilEnd) = untilEnd.kind else {
            Issue.record("残りすべてには段の終わりまでの繰り返しになるはず")
            return
        }
        #expect(unit.map(\.kind) == [.increase(.singleCrochet, count: 2)])
    }
}
