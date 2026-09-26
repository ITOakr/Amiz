import Foundation

/// 段に対する編集（domain-spec 25）。
public enum RowEdit: Hashable, Sendable {
    /// 段の手順を置き換える（過去の段の編集を「完了」したとき。段の ID は元のまま）
    case replace(rowIndex: Int, with: Row)
    /// 段を削除する
    case delete(rowIndex: Int)
    /// 段を複製し、その段の直後に `times` 段挿入する（domain-spec 18）
    case duplicate(rowIndex: Int, times: Int)

    /// 編集する段の位置（0始まり）
    public var rowIndex: Int {
        switch self {
        case .replace(let rowIndex, _), .delete(let rowIndex), .duplicate(let rowIndex, _):
            rowIndex
        }
    }
}

/// 編集が上の段に与える影響。修正の確認ダイアログ（ui-spec 7-1）の表示に使う。
public struct EditImpact: Hashable, Sendable {
    /// 編集する段の番号（1始まり）
    public var editedRowNumber: Int
    /// 置き換え前の目数。削除・複製では nil
    public var countBefore: Int?
    /// 置き換え後の目数。削除・複製では nil
    public var countAfter: Int?
    /// 影響を受ける上の段の範囲（段番号、1始まり）。影響がなければ nil
    public var affectedRowNumbers: ClosedRange<Int>?

    public init(editedRowNumber: Int, countBefore: Int? = nil, countAfter: Int? = nil, affectedRowNumbers: ClosedRange<Int>? = nil) {
        self.editedRowNumber = editedRowNumber
        self.countBefore = countBefore
        self.countAfter = countAfter
        self.affectedRowNumbers = affectedRowNumbers
    }

    /// 確認ダイアログを出す必要があるか（上の段に影響があるとき。domain-spec 25）
    public var needsConfirmation: Bool {
        affectedRowNumbers != nil
    }

    /// 影響範囲の表記（「3〜5段目」「3段目」）。影響がなければ nil
    public var affectedRowsDescription: String? {
        guard let range = affectedRowNumbers else { return nil }
        return range.count == 1 ? "\(range.lowerBound)段目" : "\(range.lowerBound)〜\(range.upperBound)段目"
    }
}

/// 段の編集を編み図に適用する（domain-spec 24・25）。
///
/// 上の段は「前段の目を順に拾う手順」として記録されているので（domain-spec 21）、
/// 編集した段の目数が変わると、上の段は同じ手順のまま新しい前段から拾い直される。
/// ここでは「影響があるか」の判定と、「上の段を残す」「上の段をほどく」の適用だけを行い、
/// 警告の計算は `ConsistencyChecker` に任せる。
public enum PatternEditor {
    /// 編集の影響を調べる。編み図は変更しない。段の位置が範囲外なら nil（落とさない。AMIZ-73）
    public static func impact(of edit: RowEdit, on pattern: Pattern) -> EditImpact? {
        let index = edit.rowIndex
        guard pattern.rows.indices.contains(index) else { return nil }

        // 上の段：編集した段より後ろで、目のある段まで（末尾の空の段＝入力を始めていない段は影響を受けない）
        let lastNonEmpty = pattern.rows.lastIndex { !$0.steps.isEmpty } ?? -1
        let rowsAbove: ClosedRange<Int>? = lastNonEmpty > index ? (index + 2)...(lastNonEmpty + 1) : nil

        switch edit {
        case .replace(_, let newRow):
            // 目数が変わらない修正は上の段に影響しない（domain-spec 24、TC-5）
            let expansion = pattern.expanded()
            let before = expansion.rows[index].totalCount
            let after = Expander.expand(row: newRow, previousCount: expansion.rows[index].previousCount).totalCount
            return EditImpact(
                editedRowNumber: index + 1,
                countBefore: before,
                countAfter: after,
                affectedRowNumbers: before == after ? nil : rowsAbove
            )

        case .delete, .duplicate:
            // 削除・複製は、上に段があれば必ず確認する（domain-spec 25）
            return EditImpact(editedRowNumber: index + 1, affectedRowNumbers: rowsAbove)
        }
    }

    /// 「上の段を残す」：編集を適用し、上の段はそのまま残す（新しい前段から拾い直される）
    public static func applyKeepingRowsAbove(_ edit: RowEdit, to pattern: Pattern) -> Pattern {
        var result = pattern
        let index = edit.rowIndex
        // 段の位置が範囲外なら何もしない（落とさない。AMIZ-73）
        guard result.rows.indices.contains(index) else { return pattern }

        switch edit {
        case .replace(_, let newRow):
            result.rows[index] = Row(id: result.rows[index].id, steps: newRow.steps)
        case .delete:
            result.rows.remove(at: index)
        case .duplicate(_, let times):
            let copies = (0..<max(0, times)).map { _ in result.rows[index].duplicated() }
            result.rows.insert(contentsOf: copies, at: index + 1)
        }
        return result
    }

    /// 「上の段をほどく」：編集を適用し、編集した段より上の段を削除する
    public static func applyUnravelingRowsAbove(_ edit: RowEdit, to pattern: Pattern) -> Pattern {
        var result = pattern
        let index = edit.rowIndex
        guard result.rows.indices.contains(index) else { return pattern }

        // 先に上の段を落としてから編集を適用する
        result.rows.removeSubrange((index + 1)...)
        return applyKeepingRowsAbove(edit, to: result)
    }
}
