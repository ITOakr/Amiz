import Foundation

/// 段の目数の警告（domain-spec 23）。保存せず、展開結果から毎回計算する。
public struct RowWarning: Hashable, Sendable {
    public enum Kind: Hashable, Sendable {
        /// 前段の目を拾い切っていない
        case shortage(previousCount: Int, pickedCount: Int)
        /// 前段の目数より多く拾っている
        case excess(previousCount: Int, pickedCount: Int)
    }

    /// 段の位置（0始まり。段番号は +1）
    public var rowIndex: Int
    /// 段の ID
    public var rowID: UUID
    /// 警告の種類
    public var kind: Kind

    public init(rowIndex: Int, rowID: UUID, kind: Kind) {
        self.rowIndex = rowIndex
        self.rowID = rowID
        self.kind = kind
    }

    /// 段番号（1始まり）
    public var rowNumber: Int {
        rowIndex + 1
    }

    /// 目数表などに出す警告文（ui-spec 5-4）
    public var message: String {
        switch kind {
        case .shortage(let previousCount, let pickedCount):
            "前段\(previousCount)目のうち\(pickedCount)目しか拾っていません"
        case .excess(let previousCount, let pickedCount):
            "前段\(previousCount)目に対して\(pickedCount)目拾っています"
        }
    }
}

/// 整合性チェック（domain-spec 23）。
/// 段ごとに「その段で拾った目数」と「前段の目数」を比べ、合わない段に警告を出す。
public enum ConsistencyChecker {
    /// 編み図全体の警告。段の順に並ぶ
    /// - Parameter excluded: チェックしない段の位置（入力中の段など。domain-spec 23）
    public static func warnings(in expansion: PatternExpansion, excludingRowAt excluded: Int? = nil) -> [RowWarning] {
        expansion.rows.enumerated().compactMap { index, row in
            guard index != excluded else { return nil }
            return warning(for: row, at: index)
        }
    }

    /// 1段の警告。問題がなければ nil
    public static func warning(for row: RowExpansion, at index: Int) -> RowWarning? {
        // わの作り目の1段目は前段の目数がないのでチェックしない（domain-spec 33）
        guard let previousCount = row.previousCount else { return nil }

        let kind: RowWarning.Kind
        if row.pickedCount > previousCount {
            kind = .excess(previousCount: previousCount, pickedCount: row.pickedCount)
        } else if row.pickedCount < previousCount, !row.leavesRemaining {
            // 「残りは編まない」を使った段では、残りの目について警告を出さない（domain-spec 23）
            kind = .shortage(previousCount: previousCount, pickedCount: row.pickedCount)
        } else {
            return nil
        }

        return RowWarning(rowIndex: index, rowID: row.rowID, kind: kind)
    }
}

extension PatternExpansion {
    /// 目数の警告（`ConsistencyChecker.warnings(in:excludingRowAt:)` の省略形）
    public func warnings(excludingRowAt excluded: Int? = nil) -> [RowWarning] {
        ConsistencyChecker.warnings(in: self, excludingRowAt: excluded)
    }
}
