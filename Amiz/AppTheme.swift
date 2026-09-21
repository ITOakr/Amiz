import SwiftUI

/// 見た目の共通の値（ui-spec 1章「柔らかい印象」）。色はアセットカタログでライト・ダーク両方を定義し、ここから参照する。
/// 画面ごとに色や角丸を直書きせず、ここを通す（React でいうテーマのトークン）
enum AppTheme {
    // MARK: 色

    /// アクセント（テラコッタ）：今編んでいる段、選択中のボタン、リンク
    static let accent = Color.accentColor
    /// 記号の線（こげ茶）。糸が1本の作品の図と、ボタンの記号
    static let ink = Color("Ink")
    /// 画面の地（生成りがかった白）
    static let canvas = Color("Canvas")
    /// 面（キーボード・現在の段の帯など。地より少し濃い）
    static let surface = Color("Surface")
    /// 浮かせる面（作品カード・ボタン。白）
    static let card = Color("Card")
    /// 警告（落ち着いた赤）
    static let warning = Color("Warning")
    /// 選択中の目（橙）
    static let selection = Color.orange
    /// 色編集モード（くすんだ藤色）
    static let colorMode = Color("ColorMode")
    /// 段の輪や帯の補助線
    static var guide: Color { accent.opacity(0.18) }
    /// 面の縁取り（生成りの地に白い面が溶けないように）
    static var hairline: Color { ink.opacity(0.08) }

    // MARK: 形

    static let buttonRadius: CGFloat = 16
    static let chipRadius: CGFloat = 10
    static let cardRadius: CGFloat = 18
    /// 浮かせる面の影
    static let shadow = Color.black.opacity(0.07)
}
