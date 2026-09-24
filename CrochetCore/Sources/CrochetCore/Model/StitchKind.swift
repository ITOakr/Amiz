/// 目の種類（domain-spec 1）。初期バージョンは6種類。
///
/// rawValue は保存形式（JSON）の一部なので変更しない。
public enum StitchKind: String, Codable, CaseIterable, Hashable, Sendable {
    /// 鎖編み
    case chain
    /// 引き抜き編み
    case slipStitch
    /// 細編み
    case singleCrochet
    /// 中長編み
    case halfDoubleCrochet
    /// 長編み
    case doubleCrochet
    /// 長々編み
    case trebleCrochet

    /// 図での高さ（鎖何目分か。domain-spec 1）
    public var heightInChains: Int {
        switch self {
        case .chain, .slipStitch: 0
        case .singleCrochet: 1
        case .halfDoubleCrochet: 2
        case .doubleCrochet: 3
        case .trebleCrochet: 4
        }
    }

    /// 玉編みにできる目か（中長編み・長編み・長々編み。domain-spec 2）
    public var canBeClustered: Bool {
        switch self {
        case .halfDoubleCrochet, .doubleCrochet, .trebleCrochet: true
        case .chain, .slipStitch, .singleCrochet: false
        }
    }

    /// 前段の目を拾うか（domain-spec 1・4）。鎖編みだけは前段に編み入れない
    public var takesPreviousStitch: Bool {
        self != .chain
    }

    /// この目で段を始めるときに自動で入れる立ち上がりの鎖の目数（domain-spec 6）。
    /// nil は立ち上がりを入れない（鎖編み・引き抜き編み）
    public var defaultTurningChains: Int? {
        switch self {
        case .chain, .slipStitch: nil
        case .singleCrochet: 1
        case .halfDoubleCrochet: 2
        case .doubleCrochet: 3
        case .trebleCrochet: 4
        }
    }
}
