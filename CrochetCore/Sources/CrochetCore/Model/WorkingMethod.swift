/// 編み方（domain-spec 5）。
///
/// rawValue は保存形式（JSON）の一部なので変更しない。
public enum WorkingMethod: String, Codable, CaseIterable, Hashable, Sendable {
    /// 往復編み：段ごとに編み地を返す
    case flat
    /// 輪編み：段の終わりを引き抜きで閉じ、立ち上がってから次の段へ進む
    case joinedRounds
    /// 螺旋編み：段の境目で閉じずに、ぐるぐる編み進める
    case spiral

    /// 立ち上がりを入れる編み方か（domain-spec 5）
    public var usesTurningChain: Bool {
        self != .spiral
    }

    /// 段を閉じる引き抜きを入れる編み方か（domain-spec 5・7）
    public var closesRound: Bool {
        self == .joinedRounds
    }
}
