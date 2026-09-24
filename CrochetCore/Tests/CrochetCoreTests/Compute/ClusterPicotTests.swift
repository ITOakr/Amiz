import Foundation
import Testing
@testable import CrochetCore

/// 玉編みとピコット（domain-spec 2・3・21、TC-13・TC-14）
@Suite("玉編みとピコット（TC-13・TC-14）")
struct ClusterPicotTests {
    @Test("TC-13 玉編み：合計24目／鎖抜き12目、前段12目を拾い切り警告なし。玉編みは1目で本数を持つ")
    func tc13() {
        let pattern = TestPatterns.tc13()
        let expansion = pattern.expanded()
        let row = expansion.rows[1]
        #expect(row.totalCount == 24)
        #expect(row.nonChainCount == 12)
        #expect(row.pickedCount == 12)
        #expect(expansion.warnings().isEmpty)
        let clusters = row.stitches.filter { $0.clusterCount > 1 }
        #expect(clusters.count == 11)
        #expect(clusters.allSatisfy { $0.kind == .halfDoubleCrochet && $0.clusterCount == 3 && $0.isCounted && $0.picks.count == 1 })
        // 玉編みの高さは目の種類のとおり（中長編み＝2）
        #expect(CircularLayout.drawHeight(of: clusters[0], options: .init()) == 2)

        let rows = StitchTableFormatter.tableRows(for: pattern, expansion: expansion)
        #expect(rows[1].instruction == "立ち上がり鎖2目、（鎖1目、中長編み3目の玉編み）×11、鎖1目")
        #expect(rows[1].countText == "合計24目／鎖抜き12目")
    }

    @Test("TC-14 ピコット：12目（ピコットは数えない）、拾った目数12で警告なし。次の段の前段の目数は12")
    func tc14() {
        var pattern = TestPatterns.tc14()
        pattern.rows.append(Row(steps: [.turningChain(1), .untilEnd([.stitch(.singleCrochet)]), .closeRound()]))
        let expansion = pattern.expanded()
        let row = expansion.rows[1]
        #expect(row.totalCount == 12)
        #expect(row.pickedCount == 12)
        #expect(row.stitches.filter { if case .picot = $0.role { true } else { false } }.count == 4)
        #expect(row.stitches.filter { if case .picot(let chains) = $0.role { chains == 3 } else { false } }.count == 4)
        #expect(expansion.rows[2].previousCount == 12)
        #expect(expansion.rows[2].totalCount == 12)
        #expect(expansion.warnings().isEmpty)

        let rows = StitchTableFormatter.tableRows(for: pattern, expansion: expansion)
        #expect(rows[1].instruction == "細編み2目、ピコット、（細編み3目、ピコット）×3、細編み1目")
        #expect(rows[1].countText == "12目")
        #expect(StitchTableFormatter.label(for: .picot(4)) == "鎖4目のピコット")
        #expect(StitchTableFormatter.label(for: .cluster(.doubleCrochet, count: 5, into: .chainSpace)) == "束に長編み5目の玉編み")
    }

    @Test("束に玉編み：アーチを拾って1目。残りすべてにも使える")
    func clusterIntoChainSpace() {
        var pattern = TestPatterns.tc4()  // 36目、アーチ12
        pattern.rows.append(Row(steps: [.turningChain(3), .untilEnd([.stitch(.chain), .cluster(.doubleCrochet, count: 3, into: .chainSpace)]), .closeRound()]))
        let row = pattern.expanded().rows[2]
        #expect(row.stitches.filter { $0.clusterCount == 3 }.count == 12)
        #expect(row.pickedCount == 36)
        #expect(pattern.expanded().warnings().isEmpty)
    }

    @Test("入力：玉編みは先に選ぶ（3→4→5→2→解除）。鎖・引き抜き・細編みには効かない。ピコットは直前に目がないと付けられない")
    func input() {
        var modifier = StitchModifier.none
        modifier.toggleCluster()
        #expect(modifier.group == .cluster(count: 3))
        #expect(modifier.step(for: .doubleCrochet).kind == .cluster(.doubleCrochet, count: 3, into: .stitch))
        #expect(modifier.step(for: .singleCrochet).kind == .stitch(.singleCrochet, into: .stitch))
        modifier.toggleChainSpace()
        #expect(modifier.step(for: .halfDoubleCrochet).kind == .cluster(.halfDoubleCrochet, count: 3, into: .chainSpace))
        modifier.toggleCluster(); #expect(modifier.group == .cluster(count: 4))
        modifier.toggleCluster(); #expect(modifier.group == .cluster(count: 5))
        modifier.toggleCluster(); #expect(modifier.group == .cluster(count: 2))
        modifier.toggleCluster(); #expect(modifier.group == nil)
        modifier.toggleCluster()
        modifier.toggleIncrease()  // 増し目とは排他
        #expect(modifier.group == .increase(count: 2))

        var pattern = Pattern(method: .joinedRounds, foundation: .magicRing)
        #expect(PatternInput.canAddPicot(in: pattern) == false)
        #expect(PatternInput.addPicot(to: &pattern) == false)
        PatternInput.addStitch(.singleCrochet, to: &pattern)
        #expect(PatternInput.canAddPicot(in: pattern))
        #expect(PatternInput.addPicot(to: &pattern))
        #expect(pattern.rows[0].steps.map(\.kind) == [.turningChain(chains: 1), .stitch(.singleCrochet), .picot(chains: 3)])
        #expect(PatternInput.canAddPicot(in: pattern) == false)  // ピコットの直後には付けない
        PatternInput.addSkip(to: &pattern)
        #expect(PatternInput.canAddPicot(in: pattern) == false)  // 飛ばすの直後も付けない
    }

    @Test("選択：玉編みの種類は中長・長・長々の間で変えられ、細編みには変えられない")
    func changeClusterKind() {
        var pattern = Pattern(method: .joinedRounds, foundation: .magicRing, rows: [Row(steps: [.cluster(.doubleCrochet)])])
        let ref = StitchRef(rowID: pattern.rows[0].id, stepID: pattern.rows[0].steps[0].id)
        #expect(PatternInput.changeStitchKind(at: ref, to: .trebleCrochet, in: &pattern))
        #expect(pattern.rows[0].steps[0].kind == .cluster(.trebleCrochet, count: 3, into: .stitch))
        #expect(PatternInput.changeStitchKind(at: ref, to: .singleCrochet, in: &pattern) == false)
    }

    @Test("JSON：玉編みとピコットが往復する")
    func json() throws {
        let pattern = TestPatterns.tc14()
        var withCluster = pattern
        withCluster.rows[1].steps.insert(.cluster(.doubleCrochet, count: 4, into: .chainSpace), at: 1)
        let data = try withCluster.jsonData()
        let text = String(decoding: data, as: UTF8.self)
        #expect(text.contains("\"type\":\"cluster\"") && text.contains("\"type\":\"picot\""))
        #expect(try Pattern(jsonData: data) == withCluster)
    }

    @Test("図：ピコットは直前の目の頭の外側に置かれ、段の高さには含めない")
    func picotLayout() {
        let layout = TestPatterns.tc14().circularLayout()
        let ring = layout.rings[1]
        #expect(abs((ring.outerRadius - ring.innerRadius) - 1) < 0.001)  // 細編みの段の高さのまま
        let picots = layout.stitches.filter { if case .picot = $0.role { true } else { false } }
        #expect(picots.count == 4)
        for picot in picots {
            #expect(abs(picot.polarRadius - (ring.outerRadius + 0.45)) < 0.001)
            #expect(picot.countedIndex == nil)
        }
        // 最初のピコットは2目めの細編みの真上
        let second = layout.countedStitch(rowIndex: 1, countedIndex: 1)!
        #expect(abs(picots[0].polarAngle - second.polarAngle) < 0.001)

        // 平面図でも直前の目の頭の上
        var flat = Pattern(method: .flat, foundation: .chain(stitchCount: 5))
        flat.rows.append(Row(steps: [.turningChain(1)] + TestPatterns.stitches(.singleCrochet, 2) + [.picot()] + TestPatterns.stitches(.singleCrochet, 3)))
        let flatLayout = flat.flatLayout()
        let flatPicot = flatLayout.stitches.first { if case .picot = $0.role { true } else { false } }!
        let secondSc = flatLayout.countedStitch(rowIndex: 0, countedIndex: 1)!
        #expect(abs(flatPicot.head.x - secondSc.head.x) < 0.001)
        #expect(flatPicot.head.y < secondSc.head.y)
    }
}
