import SwiftUI
import CrochetCore

/// 糸の色（`YarnColor`。CrochetCore の RGB）と SwiftUI の `Color` の変換
extension Color {
    init(_ yarnColor: YarnColor) {
        self.init(.sRGB, red: yarnColor.red, green: yarnColor.green, blue: yarnColor.blue)
    }
}

extension YarnColor {
    /// SwiftUI の `Color` から作る。`ColorPicker` で選んだ色を保存するときに使う（環境で解決するので UIKit は不要）
    init(_ color: Color, in environment: EnvironmentValues) {
        let resolved = color.resolve(in: environment)
        self.init(red: Double(resolved.red), green: Double(resolved.green), blue: Double(resolved.blue))
    }
}

/// 糸の色見本（丸）。明るい色は輪郭を付けて背景と見分ける（domain-spec 30）
struct YarnSwatch: View {
    let color: YarnColor
    var size: CGFloat = 22

    var body: some View {
        Circle()
            .fill(Color(color))
            .overlay(Circle().stroke(Color.primary.opacity(color.isLight ? 0.35 : 0.12), lineWidth: 1))
            .frame(width: size, height: size)
    }
}
