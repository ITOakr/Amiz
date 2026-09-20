import Foundation

/// 段を展開した結果。保存せず、表示のたびに計算する（tech-spec 5-1）。
public struct RowExpansion: Hashable, Sendable {
    /// 展開中に見つかった問題。目数の警告（domain-spec 23）とは別に、手順そのものの不備を表す
    public enum Issue: Hashable, Sendable {
        /// 「段の終わりまで」の単位が前段を1目も拾わないため、回数が決められない（domain-spec 17）
        case untilEndUnitPicksNothing(stepID: UUID)
        /// 前段の目数が決まらない段（わの作り目の1段目）で「段の終わりまで」が使われている
        case untilEndWithoutPreviousCount(stepID: UUID)
        /// 束に編み入れようとしたが、前段の残りに鎖のアーチがない（domain-spec 21）
        case noChainSpaceAhead(stepID: UUID)
    }

    /// 段の ID
    public var rowID: UUID
    /// 展開後の目の列（編む順）
    public var stitches: [ExpandedStitch]
    /// 前段から拾った目数。飛ばした目も含む（domain-spec 21）
    public var pickedCount: Int
    /// 前段の目数。わの作り目の1段目は nil（domain-spec 33）
    public var previousCount: Int?
    /// 「残りは編まない」を使ったか（domain-spec 23）
    public var leavesRemaining: Bool
    /// 繰り返しごとの実際の回数（「段の終わりまで」で決まった回数を含む）。キーは繰り返しの操作の ID
    public var repeatCounts: [UUID: Int]
    /// 展開中に見つかった問題
    public var issues: [Issue]
    /// 前段を逆順に拾う段か（往復編み。domain-spec 21）。`picks` の番号は前段の編んだ順のままで、拾う順だけが逆になる
    public var picksReversed: Bool

    public init(
        rowID: UUID,
        stitches: [ExpandedStitch] = [],
        pickedCount: Int = 0,
        previousCount: Int? = nil,
        leavesRemaining: Bool = false,
        repeatCounts: [UUID: Int] = [:],
        issues: [Issue] = [],
        picksReversed: Bool = false
    ) {
        self.rowID = rowID
        self.stitches = stitches
        self.pickedCount = pickedCount
        self.previousCount = previousCount
        self.leavesRemaining = leavesRemaining
        self.repeatCounts = repeatCounts
        self.issues = issues
        self.picksReversed = picksReversed
    }

    /// 合計目数（domain-spec 8）
    public var totalCount: Int {
        stitches.count(where: \.isCounted)
    }

    /// 鎖を除いた目数（domain-spec 8）
    public var nonChainCount: Int {
        stitches.count { $0.isCounted && !$0.isExcludedFromNonChainCount }
    }

    /// 鎖を含む段か（目数表で合計と鎖抜きを併記するかの判定に使う）
    public var containsChains: Bool {
        stitches.contains { $0.isCounted && $0.isExcludedFromNonChainCount }
    }

    /// 前段の目のうち、まだ拾っていない数。前段の目数が決まらない段では nil。拾いすぎていれば 0
    public var unpickedCount: Int? {
        previousCount.map { max(0, $0 - pickedCount) }
    }

    /// 次に拾う前段の目の番号（前段の「数える目」の編んだ順）。前段を拾い切っていれば nil。
    /// 逆順に拾う段では前段の最後の目から下がっていく
    public var nextPickIndex: Int? {
        guard let previousCount, pickedCount < previousCount else { return nil }
        return picksReversed ? previousCount - 1 - pickedCount : pickedCount
    }
}

/// 編み図全体を展開した結果
public struct PatternExpansion: Hashable, Sendable {
    /// 段ごとの展開結果。`rows[i]` が `Pattern.rows[i]`（i+1 段目）に対応する
    public var rows: [RowExpansion]

    public init(rows: [RowExpansion] = []) {
        self.rows = rows
    }
}
