import SwiftUI
import CrochetCore

/// 編み目キーボード（ui-spec 5-6 の D）。3つのグループを縦に並べる。
///
/// ボタンは `EditorModel` の `press…` を呼ぶだけで、編み図の変更はモデル側が行う。
/// 目ボタンの記号は `StitchSymbolView` で描く。
struct StitchKeyboardView: View {
    let model: EditorModel
    /// iPad の右レール用に大きく（目ボタン 96pt 角、記号も大きく。ui-spec 5-2）
    var isLarge = false

    /// 「繰り返し終了」の確認と回数入力
    @State private var isRepeatEndPresented = false
    @State private var repeatCountText = "6"
    /// 「段を終える」の確認（ui-spec 7-2）。前段に残っている目の数
    @State private var remainingToConfirm: Int?

    var body: some View {
        VStack(spacing: isLarge ? 12 : 8) {
            stitchGroup
            modifierGroup
            rowOperationGroup
        }
        .environment(\.keyboardButtonHeight, isLarge ? 60 : 48)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(AppTheme.surface)
        .buttonBorderShape(.roundedRectangle(radius: AppTheme.buttonRadius))
        .alert("繰り返し", isPresented: $isRepeatEndPresented) {
            TextField("回数", text: $repeatCountText)
                .keyboardType(.numberPad)
            Button("×\(repeatCount)で繰り返す") {
                model.pressEndRepeat(count: .times(repeatCount))
            }
            if model.canEndRepeatUntilEnd {
                Button("段の終わりまで") {
                    model.pressEndRepeat(count: .untilEnd)
                }
            }
            Button("キャンセル", role: .cancel) {}
        } message: {
            Text("『\(pendingRepeatText)』を繰り返します")
        }
        .alert("段を終えますか？", isPresented: isFinishConfirmPresented) {
            Button("残りは編まない") {
                model.pressFinishRow(leavingRemaining: true)
            }
            Button("このまま終える") {
                model.pressFinishRow()
            }
            Button("戻って続ける", role: .cancel) {}
        } message: {
            if let remaining = remainingToConfirm, let previous = model.currentRow?.previousCount {
                Text("前段\(previous)目のうち、あと\(remaining)目残っています。")
            }
        }
    }

    /// 確認ダイアログの表示状態（残っている目の数があるときだけ出す）
    private var isFinishConfirmPresented: Binding<Bool> {
        Binding(
            get: { remainingToConfirm != nil },
            set: { if !$0 { remainingToConfirm = nil } }
        )
    }

    /// 「段を終える」：前段に目が残っていれば確認を出し、拾いすぎや過不足なしならそのまま終える（ui-spec 5-6・7-2）
    private func finishRow() {
        if let remaining = model.remainingBeforeFinish {
            remainingToConfirm = remaining
        } else {
            model.pressFinishRow()
        }
    }

    // MARK: - グループ1：目ボタン

    private var stitchGroup: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 3), spacing: 8) {
            ForEach(StitchKind.allCases, id: \.self) { kind in
                Button {
                    model.pressStitch(kind)
                } label: {
                    VStack(spacing: 4) {
                        StitchSymbolView(kind: kind, size: isLarge ? 44 : 30)
                        Text(kind.japaneseName)
                            .font(isLarge ? .subheadline : .caption)
                    }
                    .frame(maxWidth: .infinity, minHeight: isLarge ? 96 : 64)
                }
                .buttonStyle(.bordered)
                .tint(.primary)
                .accessibilityIdentifier("stitch.\(kind.rawValue)")
            }
        }
    }

    // MARK: - グループ2：先に選ぶボタン

    private var modifierGroup: some View {
        HStack(spacing: 8) {
            ModifierButton(title: increaseTitle, isSelected: isIncreaseSelected) {
                model.toggleIncrease()
            }
            .accessibilityIdentifier("modifier.increase")
            ModifierButton(title: decreaseTitle, isSelected: isDecreaseSelected) {
                model.toggleDecrease()
            }
            .accessibilityIdentifier("modifier.decrease")
            // 束に編み入れる（鎖のアーチをすくう。domain-spec 21）。「2目一度」とは同時に選べない
            ModifierButton(title: "束に", isSelected: model.modifier.chainSpace) {
                model.toggleChainSpace()
            }
            .accessibilityIdentifier("modifier.chainSpace")
            ModifierButton(title: "飛ばす", isSelected: false) {
                model.pressSkip()
            }
            .accessibilityIdentifier("modifier.skip")
            ModifierButton(title: "残りすべてに", isSelected: model.modifier.untilEnd) {
                model.toggleUntilEnd()
            }
            .accessibilityIdentifier("modifier.untilEnd")
        }
    }

    private var isIncreaseSelected: Bool {
        if case .increase = model.modifier.group { true } else { false }
    }

    private var isDecreaseSelected: Bool {
        if case .decrease = model.modifier.group { true } else { false }
    }

    private var increaseTitle: String {
        if case .increase(let count) = model.modifier.group { "\(count)目編み入れる" } else { "2目編み入れる" }
    }

    private var decreaseTitle: String {
        if case .decrease(let count) = model.modifier.group { "\(count)目一度" } else { "2目一度" }
    }

    // MARK: - グループ3：段の操作

    private var rowOperationGroup: some View {
        HStack(spacing: 8) {
            OperationButton(title: "繰り返し開始") {
                model.pressBeginRepeat()
            }
            .disabled(model.isRepeating)
            .accessibilityIdentifier("op.beginRepeat")

            OperationButton(title: "繰り返し終了") {
                isRepeatEndPresented = true
            }
            .disabled(!(model.pendingRepeatUnit?.isEmpty == false))
            .accessibilityIdentifier("op.endRepeat")

            OperationButton(title: "段を終える") {
                finishRow()
            }
            .disabled(model.editingSession != nil)
            .accessibilityIdentifier("op.finishRow")

            OperationButton(title: "1目削除") {
                model.pressDeleteLast()
            }
            .accessibilityIdentifier("op.deleteLast")

            Menu {
                ForEach(1...4, id: \.self) { chains in
                    Button("鎖\(chains)目") {
                        model.pressTurningChain(chains: chains)
                    }
                }
            } label: {
                OperationLabel(title: "立ち上がり")
            }
            .buttonStyle(.bordered)
            .tint(.primary)
            .disabled(!model.pattern.method.usesTurningChain)
            .accessibilityIdentifier("op.turningChain")
        }
    }

    // MARK: - 補助

    private var repeatCount: Int {
        max(1, Int(repeatCountText) ?? 1)
    }

    private var pendingRepeatText: String {
        (model.pendingRepeatUnit ?? []).map(StitchTableFormatter.label).joined(separator: "・")
    }
}

/// 先に選ぶボタン。選択中は色を付けて状態 S2 を示す
private struct ModifierButton: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    @Environment(\.keyboardButtonHeight) private var height

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.caption)
                .lineLimit(2)
                .minimumScaleFactor(0.8)
                .frame(maxWidth: .infinity, minHeight: height)
        }
        .buttonStyle(.bordered)
        .tint(isSelected ? AppTheme.accent : .primary)
        .background(isSelected ? AppTheme.accent.opacity(0.2) : .clear, in: RoundedRectangle(cornerRadius: AppTheme.buttonRadius))
    }
}

/// 段の操作ボタン
private struct OperationButton: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            OperationLabel(title: title)
        }
        .buttonStyle(.bordered)
        .tint(.primary)
    }
}

private struct OperationLabel: View {
    let title: String
    @Environment(\.keyboardButtonHeight) private var height

    var body: some View {
        Text(title)
            .font(.caption)
            .lineLimit(2)
            .minimumScaleFactor(0.8)
            .frame(maxWidth: .infinity, minHeight: height)
    }
}

/// 先に選ぶボタン・段の操作ボタンの高さ（iPad の右レールでは大きくする）
private struct KeyboardButtonHeightKey: EnvironmentKey {
    static let defaultValue: CGFloat = 48
}

extension EnvironmentValues {
    fileprivate var keyboardButtonHeight: CGFloat {
        get { self[KeyboardButtonHeightKey.self] }
        set { self[KeyboardButtonHeightKey.self] = newValue }
    }
}

#Preview {
    StitchKeyboardView(model: EditorModel())
}
