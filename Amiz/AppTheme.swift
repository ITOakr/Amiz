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

/// 編み目キーボードのボタンの見た目（ui-spec 1章「柔らかい印象」）：白い面に薄い影、押すと少し沈む。
/// 選択中はアクセントの薄い面、無効は面を地に近づけて文字を薄く
struct SoftButtonStyle: ButtonStyle {
    var isSelected = false
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(isEnabled ? (isSelected ? AppTheme.accent : AppTheme.ink) : AppTheme.ink.opacity(0.3))
            .background(fill, in: RoundedRectangle(cornerRadius: AppTheme.buttonRadius))
            .overlay(
                RoundedRectangle(cornerRadius: AppTheme.buttonRadius)
                    .stroke(isSelected ? AppTheme.accent.opacity(0.6) : AppTheme.hairline, lineWidth: isSelected ? 1.5 : 1)
            )
            .shadow(color: isEnabled ? AppTheme.shadow : .clear, radius: 4, y: 2)
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .opacity(configuration.isPressed ? 0.85 : 1)
            .animation(.easeOut(duration: 0.08), value: configuration.isPressed)
    }

    private var fill: Color {
        if !isEnabled { return AppTheme.surface }
        return isSelected ? AppTheme.accent.opacity(0.18) : AppTheme.card
    }
}

extension ButtonStyle where Self == SoftButtonStyle {
    /// `.buttonStyle(.soft)` / `.buttonStyle(.soft(selected: true))`
    static var soft: SoftButtonStyle { SoftButtonStyle() }
    static func soft(selected: Bool) -> SoftButtonStyle { SoftButtonStyle(isSelected: selected) }
}
