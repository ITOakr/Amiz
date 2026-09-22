import Foundation

/// 展開後の1目。段の手順（`Row.steps`）から計算する値で、保存しない（tech-spec 5-1）。
///
/// 目数の計算、整合性チェック、図の座標計算、目の選択はすべてこの列を元にする。
public struct ExpandedStitch: Hashable, Sendable {
    /// この目の役割
    public enum Role: Hashable, Sendable {
        /// 普通の目。増し目・減らし目の一部もこれ
        case regular
        /// 立ち上がり。鎖の目数を持つ。展開後は鎖の目数に関わらず「1目」として扱う（domain-spec 6）
        case turningChain(chains: Int)
        /// 段を閉じる引き抜き（domain-spec 7）
        case closingSlipStitch
        /// ピコット（鎖の目数を持つ）。直前の目の頭に付く飾りで、数えない（domain-spec 3・21）
        case picot(chains: Int)
    }

    /// どの操作から生まれたか
    public var ref: StitchRef
    /// 目の種類。立ち上がりは `chain`、段を閉じる引き抜きは `slipStitch`
    public var kind: StitchKind
    /// 役割
    public var role: Role
    /// 編み入れ先
    public var into: Placement
    /// 前段のどの目を拾ったか。前段の「数える目」の並び（編んだ順）での位置（0始まり）。
    /// 鎖編み・数えない立ち上がり・段を閉じる引き抜きは空。n目一度は n 個分の範囲。
    /// 往復編みは前段を逆順に拾うので、段の中で番号が下がっていく（`RowExpansion.picksReversed`）
    public var picks: Range<Int>
    /// 目数に数えるか（domain-spec 6・8）
    public var isCounted: Bool
    /// 糸（操作の糸。nil なら既定の糸。domain-spec 27）
    public var yarnID: UUID?
    /// 玉編みの本数（普通の目は 1。domain-spec 2）
    public var clusterCount: Int

    public init(
        ref: StitchRef,
        kind: StitchKind,
        role: Role = .regular,
        into: Placement = .stitch,
        picks: Range<Int>,
        isCounted: Bool,
        yarnID: UUID? = nil,
        clusterCount: Int = 1
    ) {
        self.ref = ref
        self.kind = kind
        self.role = role
        self.into = into
        self.picks = picks
        self.isCounted = isCounted
        self.yarnID = yarnID
        self.clusterCount = clusterCount
    }

    /// 「鎖を除いた目数」から除く目か。普通の鎖編みだけを除き、数える立ち上がりは含める（domain-spec 8）
    public var isExcludedFromNonChainCount: Bool {
        role == .regular && kind == .chain
    }

    /// 次の段から見て「鎖のアーチ」の一部になる目か（普通の鎖編みだけ。数える立ち上がりは目の代わりなので含めない。domain-spec 21）
    public var isChainSpaceLink: Bool {
        isCounted && role == .regular && kind == .chain
    }
}
