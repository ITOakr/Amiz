import Testing
@testable import CrochetCore

@Suite("修正の影響範囲と適用（domain-spec 24・25）")
struct PatternEditorTests {
    /// TC-2 の修正：1段目を「わの作り目に細編み7目」に置き換える
    private var tc2Edit: RowEdit {
        .replace(rowIndex: 0, with: Row(
            steps: [.turningChain(1)] + TestPatterns.stitches(.singleCrochet, 7) + [.closeRound()]
        ))
    }

    @Test("TC-2 影響範囲：1段目が6目から7目に変わり、2〜5段目に影響がある")
    func tc2Impact() throws {
        let impact = try #require(PatternEditor.impact(of: tc2Edit, on: TestPatterns.tc1()))

        #expect(impact.editedRowNumber == 1)
        #expect(impact.countBefore == 6)
        #expect(impact.countAfter == 7)
        #expect(impact.affectedRowNumbers == 2...5)
        #expect(impact.affectedRowsDescription == "2〜5段目")
        #expect(impact.needsConfirmation)
    }

    @Test("TC-2 「上の段を残す」：各段は 7/14/18/24/24 になり、3段目に警告が出る")
    func tc2Keep() throws {
        let original = TestPatterns.tc1()
        let edited = PatternEditor.applyKeepingRowsAbove(tc2Edit, to: original)
        let expansion = edited.expanded()

        #expect(edited.rows.count == 5)
        #expect(expansion.rows.map(\.totalCount) == [7, 14, 18, 24, 24])
        #expect(expansion.warnings().map(\.rowNumber) == [3])
        // 段の ID は変わらない（上の段は同じ手順のまま）
        #expect(edited.rows.map(\.id) == original.rows.map(\.id))
        #expect(edited.rows[1...] == original.rows[1...])
    }

    @Test("TC-2 「上の段をほどく」：1段目（7目）だけが残る")
    func tc2Unravel() throws {
        let edited = PatternEditor.applyUnravelingRowsAbove(tc2Edit, to: TestPatterns.tc1())

        #expect(edited.rows.count == 1)
        #expect(edited.expanded().rows.map(\.totalCount) == [7])
        #expect(edited.expanded().warnings().isEmpty)
    }

    @Test("TC-5 拾う目数が変わらない修正：3段目を中長編みにしても影響なし")
    func tc5() throws {
        let original = TestPatterns.tc1()
        let edit = RowEdit.replace(rowIndex: 2, with: Row(steps: [
            .turningChain(1),
            .repeating([.stitch(.halfDoubleCrochet), .increase(.halfDoubleCrochet)], times: 6),
            .closeRound(),
        ]))

        let impact = try #require(PatternEditor.impact(of: edit, on: original))
        #expect(impact.countBefore == 18)
        #expect(impact.countAfter == 18)
        #expect(impact.affectedRowNumbers == nil)
        #expect(!impact.needsConfirmation)

        let edited = PatternEditor.applyKeepingRowsAbove(edit, to: original)
        #expect(edited.expanded().rows.map(\.totalCount) == [6, 12, 18, 24, 24])
        #expect(edited.expanded().warnings().isEmpty)
        #expect(edited.rows[2].id == original.rows[2].id)
    }

    @Test("最後の段の修正は目数が変わっても確認不要")
    func lastRowReplace() throws {
        let edit = RowEdit.replace(rowIndex: 4, with: Row(steps: [
            .turningChain(1), .untilEnd([.increase(.singleCrochet)]), .closeRound(),
        ]))
        let impact = try #require(PatternEditor.impact(of: edit, on: TestPatterns.tc1()))

        #expect(impact.countBefore == 24)
        #expect(impact.countAfter == 48)
        #expect(!impact.needsConfirmation)
    }

    @Test("段の削除：上に段があれば確認が必要。残すと上の段はそのまま、ほどくと消える")
    func delete() throws {
        let original = TestPatterns.tc1()
        let edit = RowEdit.delete(rowIndex: 1)

        let impact = try #require(PatternEditor.impact(of: edit, on: original))
        #expect(impact.affectedRowNumbers == 3...5)
        #expect(impact.countBefore == nil)

        let kept = PatternEditor.applyKeepingRowsAbove(edit, to: original)
        #expect(kept.rows.map(\.id) == [original.rows[0].id] + original.rows[2...].map(\.id))

        let unraveled = PatternEditor.applyUnravelingRowsAbove(edit, to: original)
        #expect(unraveled.rows.map(\.id) == [original.rows[0].id])

        // 最後の段の削除は確認不要
        #expect(try #require(PatternEditor.impact(of: .delete(rowIndex: 4), on: original)).needsConfirmation == false)
    }

    @Test("段の複製：最後の段を5回複製すると「増減なし」の段が5段増える")
    func duplicateLastRow() throws {
        let original = TestPatterns.tc1()
        let edit = RowEdit.duplicate(rowIndex: 4, times: 5)

        #expect(try #require(PatternEditor.impact(of: edit, on: original)).needsConfirmation == false)

        let edited = PatternEditor.applyKeepingRowsAbove(edit, to: original)
        #expect(edited.rows.count == 10)
        #expect(edited.expanded().rows.map(\.totalCount) == [6, 12, 18, 24, 24, 24, 24, 24, 24, 24])
        #expect(edited.expanded().warnings().isEmpty)

        // 複製した段は手順が同じで、段と操作の ID はすべて新しい
        let copies = edited.rows[5...]
        #expect(copies.allSatisfy { $0.hasSameSteps(as: original.rows[4]) })
        let allRowIDs = Set(edited.rows.map(\.id))
        #expect(allRowIDs.count == 10)
        let allStepIDs = edited.rows.flatMap { $0.steps.map(\.id) }
        #expect(Set(allStepIDs).count == allStepIDs.count)
    }

    @Test("段の複製：途中の段を複製すると上の段に影響があり、確認が必要")
    func duplicateMiddleRow() throws {
        let original = TestPatterns.tc1()
        let edit = RowEdit.duplicate(rowIndex: 1, times: 1)

        let impact = try #require(PatternEditor.impact(of: edit, on: original))
        #expect(impact.affectedRowNumbers == 3...5)
        #expect(impact.affectedRowsDescription == "3〜5段目")

        let kept = PatternEditor.applyKeepingRowsAbove(edit, to: original)
        #expect(kept.rows.count == 6)
        #expect(kept.rows[2].hasSameSteps(as: original.rows[1]))

        let unraveled = PatternEditor.applyUnravelingRowsAbove(edit, to: original)
        #expect(unraveled.rows.count == 3)
    }

    @Test("影響範囲が1段だけのときの表記")
    func singleAffectedRow() throws {
        let pattern = TestPatterns.afterRound(of: 6, row: Row(
            steps: [.turningChain(1)] + TestPatterns.stitches(.singleCrochet, 6) + [.closeRound()]
        ))
        let edit = RowEdit.replace(rowIndex: 0, with: Row(
            steps: [.turningChain(1)] + TestPatterns.stitches(.singleCrochet, 5) + [.closeRound()]
        ))
        #expect(try #require(PatternEditor.impact(of: edit, on: pattern)).affectedRowsDescription == "2段目")
    }

    @Test("影響範囲は目のある段まで。末尾の空の段（入力を始めていない段）は含めない")
    func trailingEmptyRowIsNotAffected() throws {
        var pattern = TestPatterns.tc1()
        pattern.rows.append(Row())  // 入力中の空の6段目
        let edit = RowEdit.replace(rowIndex: 0, with: Row(
            steps: [.turningChain(1)] + TestPatterns.stitches(.singleCrochet, 7) + [.closeRound()]
        ))
        #expect(try #require(PatternEditor.impact(of: edit, on: pattern)).affectedRowNumbers == 2...5)

        // 空の段しか上にないなら影響なし
        var single = Pattern(method: .joinedRounds, foundation: .magicRing, rows: [pattern.rows[0], Row()])
        #expect(try #require(PatternEditor.impact(of: edit, on: single)).needsConfirmation == false)
        single.rows[0] = edit_row(edit)
        #expect(single.rows.count == 2)
    }

    private func edit_row(_ edit: RowEdit) -> Row {
        if case .replace(_, let row) = edit { return row }
        fatalError()
    }

    @Test("ほどいた後：最後の段が閉じていれば空の段を足す")
    func ensureOpenRow() throws {
        var pattern = PatternEditor.applyUnravelingRowsAbove(.delete(rowIndex: 2), to: TestPatterns.tc1())
        #expect(pattern.rows.count == 2)
        #expect(PatternInput.ensureOpenRow(in: &pattern))
        #expect(pattern.rows.count == 3)
        #expect(pattern.rows[2].steps.isEmpty)
        // すでに空の段があれば足さない
        #expect(!PatternInput.ensureOpenRow(in: &pattern))
    }
}

/// 範囲外の段を指しても落ちない（AMIZ-73）
@Suite("段の編集：範囲外の位置")
struct PatternEditorSafetyTests {
    @Test("範囲外の段は nil を返し、適用しても編み図が変わらない")
    func outOfRange() throws {
        let pattern = TestPatterns.tc1()
        for edit: RowEdit in [.replace(rowIndex: 9, with: Row()), .delete(rowIndex: -1), .duplicate(rowIndex: 99, times: 2)] {
            #expect(PatternEditor.impact(of: edit, on: pattern) == nil)
            #expect(PatternEditor.applyKeepingRowsAbove(edit, to: pattern) == pattern)
            #expect(PatternEditor.applyUnravelingRowsAbove(edit, to: pattern) == pattern)
        }
        // 正しい位置なら今までどおり
        #expect(PatternEditor.impact(of: .delete(rowIndex: 0), on: pattern) != nil)
    }

    @Test("目数表：段数と展開結果が食い違っていたら空を返す（落ちない）")
    func mismatchedExpansion() throws {
        let pattern = TestPatterns.tc1()
        let short = PatternExpansion(rows: Array(pattern.expanded().rows.prefix(2)))
        #expect(StitchTableFormatter.tableRows(for: pattern, expansion: short).isEmpty)
        #expect(StitchTableFormatter.tableRows(for: pattern, expansion: pattern.expanded()).count == 5)
    }

    @Test("末尾の空の段を落とす処理は段数をそろえる")
    func trimming() throws {
        var pattern = TestPatterns.tc1()
        pattern.rows.append(Row())
        pattern.rows.append(Row())
        let trimmed = pattern.trimmingTrailingEmptyRows(expansion: pattern.expanded())
        #expect(trimmed.pattern.rows.count == 5)
        #expect(trimmed.expansion.rows.count == 5)
        #expect(StitchTableFormatter.tableRows(for: trimmed.pattern, expansion: trimmed.expansion).count == 5)
    }
}
