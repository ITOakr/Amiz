/// アプリ全体の設定（ui-spec 6-3）。UserDefaults に保存する（tech-spec 5-5）。
///
/// 画面では `@AppStorage(AppSettings.autoTurningChainKey)` のように使う。
enum AppSettings {
    /// 立ち上がりの鎖の自動入力（既定：オン）
    static let autoTurningChainKey = "autoTurningChain"
    /// 図に段番号を表示（既定：オン）
    static let showsRowNumbersKey = "showsRowNumbers"
}
