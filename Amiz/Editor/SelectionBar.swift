import SwiftUI
import CrochetCore

/// 目を選択中の操作メニュー（状態 S6。ui-spec U15）。キーボードの上に出す。
struct SelectionBar: View {
    let model: EditorModel

    var body: some View {
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Text(model.selectionDescription ?? "")
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                    .accessibilityIdentifier("selection.description")
                Text(model.selectedTurningChainCount == nil ? "目ボタンを押すと種類を変えられます" : "鎖の目数を変えられます")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 4)

            if let chains = model.selectedTurningChainCount {
                Menu("鎖\(chains)目") {
                    ForEach(1...4, id: \.self) { count in
                        Button("鎖\(count)目") { model.request(.setTurningChain(count)) }
                    }
                }
                .buttonStyle(.bordered)
                .accessibilityIdentifier("selection.turningChain")
            }
            if model.selectionIsInRepeat {
                Button("繰り返しを解除") { model.request(.unwrapRepeat) }
                    .buttonStyle(.bordered)
                    .accessibilityIdentifier("selection.unwrap")
            }
            Button("削除", role: .destructive) { model.request(.delete) }
                .buttonStyle(.bordered)
                .accessibilityIdentifier("selection.delete")
            Button("閉じる", systemImage: "xmark") { model.clearSelection() }
                .labelStyle(.iconOnly)
                .buttonStyle(.bordered)
                .accessibilityIdentifier("selection.close")
        }
        .font(.caption)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color.orange.opacity(0.12))
    }
}
