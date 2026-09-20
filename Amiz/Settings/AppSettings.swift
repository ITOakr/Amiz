import CrochetCore

/// アプリ全体の設定（ui-spec 6-3）。UserDefaults に保存する（tech-spec 5-5）。
///
/// 画面では `@AppStorage(AppSettings.autoTurningChainKey)` のように使う。
enum AppSettings {
    /// 立ち上がりの鎖の自動入力（既定：オン）
    static let autoTurningChainKey = "autoTurningChain"
    /// 図に段番号を表示（既定：オン）
    static let showsRowNumbersKey = "showsRowNumbers"
    /// 立ち上がりを1目と数えるか（既定：標準）
    static let turningChainCountingKey = "turningChainCounting"
}

/// 立ち上がりを1目と数えるかの設定（ui-spec 6-3、domain-spec 6）。
/// 新しく入れる立ち上がりの初期値を決めるだけで、入力済みの立ち上がりは変えない
enum TurningChainCounting: String, CaseIterable, Identifiable {
    /// 鎖1目は数えない、2目以上は数える
    case standard
    case counted
    case notCounted
    /// 立ち上がりが入るたびに聞く
    case askEveryTime

    var id: String { rawValue }

    var japaneseName: String {
        switch self {
        case .standard: "標準"
        case .counted: "数える"
        case .notCounted: "数えない"
        case .askEveryTime: "毎回選択"
        }
    }

    /// 設定画面の説明
    var detail: String {
        switch self {
        case .standard: "鎖1目は数えない、鎖2目以上は1目と数える"
        case .counted: "どの立ち上がりも1目と数える"
        case .notCounted: "どの立ち上がりも数えない"
        case .askEveryTime: "立ち上がりが入るたびに聞く"
        }
    }

    /// 鎖 `chains` 目の立ち上がりを数えるか。「毎回選択」なら nil（聞いてから決める）
    func resolve(chains: Int) -> Bool? {
        switch self {
        case .standard: StepKind.standardTurningChainCounted(chains: chains)
        case .counted: true
        case .notCounted: false
        case .askEveryTime: nil
        }
    }
}
