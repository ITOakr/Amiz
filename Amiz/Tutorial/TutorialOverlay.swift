import SwiftUI

/// 案内が光らせるボタンの位置を集める（AMIZ-85）。
/// ボタン側は `.tutorialTarget("op.finishRow")` のように付ける
struct TutorialTargetKey: PreferenceKey {
    static var defaultValue: [String: Anchor<CGRect>] { [:] }

    static func reduce(value: inout [String: Anchor<CGRect>], nextValue: () -> [String: Anchor<CGRect>]) {
        value.merge(nextValue()) { _, new in new }
    }
}

extension View {
    /// このボタンを案内で光らせられるようにする（`accessibilityIdentifier` と同じ文字列を渡す）
    func tutorialTarget(_ id: String) -> some View {
        anchorPreference(key: TutorialTargetKey.self, value: .bounds) { [id: $0] }
    }

    /// 案内のハイライトと説明の帯を重ねる。画面の一番外側に付ける
    func tutorialOverlay(_ tutorial: TutorialModel) -> some View {
        modifier(TutorialOverlayModifier(tutorial: tutorial))
    }
}

/// 光っているボタンの縁取りと、説明の帯（ui-spec 7-5）。
///
/// 画面は覆わない。他のボタンも押せるままにして、案内と違う操作をしても止めない
private struct TutorialOverlayModifier: ViewModifier {
    /// ナビゲーションバー（題と元に戻す）の高さ。説明の帯を上に出すときに避ける
    private static let navigationBarHeight: CGFloat = 44

    let tutorial: TutorialModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isPulsing = false

    func body(content: Content) -> some View {
        content.overlayPreferenceValue(TutorialTargetKey.self) { anchors in
            GeometryReader { proxy in
                if let step = tutorial.currentStep {
                    let target = step.target.flatMap { anchors[$0] }.map { proxy[$0] }
                    ZStack {
                        if let target {
                            highlight(target)
                        }
                        // 説明の帯は、光っているボタンと反対側に置いて重ならないようにする。
                        // 上に出すときは、ナビゲーションバーの下に来るようずらす
                        let atTop = isTargetLow(target, in: proxy.size)
                        messageBar(step)
                            .padding(.top, atTop ? Self.navigationBarHeight : 0)
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: atTop ? .top : .bottom)
                    }
                }
            }
        }
        .onAppear { isPulsing = true }
    }

    /// 光っているボタンが画面の下半分にあるか（説明の帯を上に逃がす）
    private func isTargetLow(_ target: CGRect?, in size: CGSize) -> Bool {
        guard let target else { return false }
        return target.midY > size.height / 2
    }

    /// ボタンの縁取り。ゆっくり脈打たせる（「動きを減らす」設定では止める）
    private func highlight(_ rect: CGRect) -> some View {
        let padded = rect.insetBy(dx: -6, dy: -6)
        return RoundedRectangle(cornerRadius: AppTheme.buttonRadius + 6)
            .strokeBorder(AppTheme.accent, lineWidth: 3)
            .frame(width: padded.width, height: padded.height)
            .position(x: padded.midX, y: padded.midY)
            .opacity(reduceMotion || !isPulsing ? 1 : 0.45)
            .animation(
                reduceMotion ? nil : .easeInOut(duration: 0.9).repeatForever(autoreverses: true),
                value: isPulsing
            )
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }

    /// 説明・進み具合・スキップ
    private func messageBar(_ step: TutorialStep) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(step.message)
                .font(.callout)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("tutorial.message")
            HStack {
                Text(tutorial.progressText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
                Spacer()
                if tutorial.isOnLastStep {
                    Button("終わる") { tutorial.finish() }
                        .buttonStyle(.borderedProminent)
                        .accessibilityIdentifier("tutorial.finish")
                } else {
                    Button("スキップ") { tutorial.skip() }
                        .accessibilityIdentifier("tutorial.skip")
                }
            }
        }
        .padding(14)
        .background(AppTheme.card, in: RoundedRectangle(cornerRadius: AppTheme.cardRadius))
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.cardRadius).strokeBorder(AppTheme.hairline)
        )
        .shadow(color: AppTheme.shadow, radius: 10, y: 4)
        .padding(16)
        // 説明が画面を占領しないように、文字サイズの上限を付ける（AMIZ-81 と同じ考え方）
        .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
    }
}
