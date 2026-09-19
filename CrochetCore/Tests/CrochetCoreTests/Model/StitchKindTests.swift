import Testing
@testable import CrochetCore

@Suite("目の種類の表（domain-spec 1・6）")
struct StitchKindTests {
    @Test("図での高さ（鎖何目分か）", arguments: zip(StitchKind.allCases, [0, 0, 1, 2, 3, 4]))
    func height(kind: StitchKind, expected: Int) {
        #expect(kind.heightInChains == expected)
    }

    @Test("鎖編みだけが前段を拾わない")
    func takesPreviousStitch() {
        #expect(!StitchKind.chain.takesPreviousStitch)
        for kind in StitchKind.allCases where kind != .chain {
            #expect(kind.takesPreviousStitch)
        }
    }

    @Test("立ち上がりの鎖の初期値", arguments: zip(StitchKind.allCases, [nil, nil, 1, 2, 3, 4] as [Int?]))
    func defaultTurningChains(kind: StitchKind, expected: Int?) {
        #expect(kind.defaultTurningChains == expected)
    }
}

@Suite("編み方の表（domain-spec 5）")
struct WorkingMethodTests {
    @Test("立ち上がりと段を閉じる引き抜きの有無")
    func flags() {
        #expect(WorkingMethod.flat.usesTurningChain)
        #expect(!WorkingMethod.flat.closesRound)

        #expect(WorkingMethod.joinedRounds.usesTurningChain)
        #expect(WorkingMethod.joinedRounds.closesRound)

        #expect(!WorkingMethod.spiral.usesTurningChain)
        #expect(!WorkingMethod.spiral.closesRound)
    }
}
