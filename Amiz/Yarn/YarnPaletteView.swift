import SwiftUI
import CrochetCore

/// 糸パレット（色編集モード。ui-spec U21）。編み目キーボードの代わりに出す。
/// 糸を選び、図の目をタップ／なぞり、または目数表の段をタップして塗る。「完了」で通常の入力に戻る
struct YarnPaletteView: View {
    let model: EditorModel
    var isLarge = false

    @State private var isAddingYarn = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("色編集モード", systemImage: "paintpalette.fill")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppTheme.colorMode)
                Spacer()
                Button("完了") { model.endColorEditing() }
                    .buttonStyle(.borderedProminent)
                    .buttonBorderShape(.roundedRectangle(radius: AppTheme.chipRadius))
                    .tint(AppTheme.colorMode)
                    .accessibilityIdentifier("palette.done")
            }
            Text("糸を選んで、図の目をタップ（なぞると続けて塗れます）。目数表の段をタップすると段全体を塗ります。")
                .font(.caption)
                .foregroundStyle(.secondary)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(model.yarns) { yarn in
                        paletteButton(yarn)
                    }
                    Button {
                        isAddingYarn = true
                    } label: {
                        VStack(spacing: 4) {
                            Image(systemName: "plus.circle")
                                .font(.system(size: isLarge ? 34 : 28))
                            Text("糸を追加")
                                .font(.caption2)
                        }
                        .frame(width: isLarge ? 76 : 64)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.tint)
                    .accessibilityIdentifier("palette.add")
                }
                .padding(.vertical, 4)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.colorMode.opacity(0.1))
        .sheet(isPresented: $isAddingYarn) {
            YarnEditSheet(yarn: Yarn(name: "", color: YarnColor(hex: "#A8C5E2")!), isNew: true, canDelete: false) { yarn in
                model.addYarn(yarn)
                model.paintYarnID = yarn.id
            } onDelete: {}
        }
    }

    /// パレットの1本。選んでいる糸は太い枠
    private func paletteButton(_ yarn: Yarn) -> some View {
        let isSelected = model.paintYarnID == yarn.id
        return Button {
            model.paintYarnID = yarn.id
        } label: {
            VStack(spacing: 4) {
                YarnSwatch(color: yarn.color, size: isLarge ? 34 : 28)
                    .overlay(Circle().stroke(AppTheme.colorMode, lineWidth: isSelected ? 3 : 0).padding(-3))
                Text(yarn.name)
                    .font(.caption2)
                    .lineLimit(1)
            }
            .frame(width: isLarge ? 76 : 64)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(isSelected ? "\(yarn.name)（選択中）" : yarn.name)
        .accessibilityIdentifier("palette.yarn.\(yarn.name)")
    }
}

#Preview {
    let model = EditorModel(pattern: SamplePatterns.bearHead)
    model.beginColorEditing()
    return YarnPaletteView(model: model)
}
