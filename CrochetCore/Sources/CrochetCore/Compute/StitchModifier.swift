import Foundation

/// 先に選ぶボタンの状態（ui-spec 5-6 グループ2）。
///
/// 「2目編み入れる」「2目一度」「束に」「残りすべてに」を先に押してから目ボタンを押すと、
/// この状態が1つの操作（`Step`）に変換され、状態は解除される。
public struct StitchModifier: Hashable, Sendable {
    /// n目編み入れる／n目一度／玉編み。同時には選べない
    public enum Group: Hashable, Sendable {
        case increase(count: Int)
        case decrease(count: Int)
        /// 玉編み（count 本）。中長編み・長編み・長々編みを押したときだけ効く
        case cluster(count: Int)
    }

    /// 玉編みの本数の順（押すたびに 3 → 4 → 5 → 2 → 解除。ui-spec 5-6）
    public static let clusterCounts = [3, 4, 5, 2]

    /// 画面で選べる目数の上限（ui-spec 5-6。データ上は n目に一般化されている）
    public static let maxGroupCount = 3

    public var group: Group?
    /// 束に編み入れる
    public var chainSpace = false
    /// 残りすべてに（段の終わりまで）
    public var untilEnd = false

    public init(group: Group? = nil, chainSpace: Bool = false, untilEnd: Bool = false) {
        self.group = group
        self.chainSpace = chainSpace
        self.untilEnd = untilEnd
    }

    /// 何も選んでいない状態
    public static let none = StitchModifier()

    /// 何か選んでいるか（状態 S2）
    public var isActive: Bool {
        group != nil || chainSpace || untilEnd
    }

    /// 目ボタンを押したときの操作を作る。`yarnID` は目の糸（繰り返しの操作そのものには付けず、単位の中の目に付ける）
    public func step(for kind: StitchKind, yarnID: UUID? = nil) -> Step {
        let placement: Placement = chainSpace ? .chainSpace : .stitch
        let inner: Step = switch group {
        case .increase(let count): .increase(kind, count: count, into: placement)
        case .decrease(let count): .decrease(kind, count: count)
        // 玉編みにできない目（鎖・引き抜き・細編み）は普通の目として入る
        case .cluster(let count): kind.canBeClustered ? .cluster(kind, count: count, into: placement) : .stitch(kind, into: placement)
        case nil: .stitch(kind, into: placement)
        }
        let colored = inner.withYarn(yarnID)
        return untilEnd ? .untilEnd([colored]) : colored
    }

    // MARK: - ボタンの切り替え（ui-spec 5-6）

    /// 「2目編み入れる」：押すたびに 2目 → 3目 → 解除
    public mutating func toggleIncrease() {
        group = Self.nextCount(after: group, isIncrease: true).map { .increase(count: $0) }
    }

    /// 「2目一度」：押すたびに 2目 → 3目 → 解除。「束に」とは同時に選べないので解除する
    public mutating func toggleDecrease() {
        group = Self.nextCount(after: group, isIncrease: false).map { .decrease(count: $0) }
        if group != nil {
            chainSpace = false
        }
    }

    /// 「束に」：「2目一度」とは同時に選べないので解除する
    public mutating func toggleChainSpace() {
        chainSpace.toggle()
        if chainSpace, case .decrease = group {
            group = nil
        }
    }

    /// 「残りすべてに」
    public mutating func toggleUntilEnd() {
        untilEnd.toggle()
    }

    /// 「玉編み」：押すたびに 3目 → 4目 → 5目 → 2目 → 解除。「n目編み入れる」「n目一度」とは同時に選べない
    public mutating func toggleCluster() {
        if case .cluster(let count) = group, let index = Self.clusterCounts.firstIndex(of: count) {
            let next = index + 1
            group = next < Self.clusterCounts.count ? .cluster(count: Self.clusterCounts[next]) : nil
        } else {
            group = .cluster(count: Self.clusterCounts[0])
        }
    }

    /// 同じ種類なら 2 → 3 → nil、違う種類（または未選択）なら 2
    private static func nextCount(after group: Group?, isIncrease: Bool) -> Int? {
        switch group {
        case .increase(let count) where isIncrease, .decrease(let count) where !isIncrease:
            count < maxGroupCount ? count + 1 : nil
        default:
            2
        }
    }
}
