import SwiftUI

/// 過去の段を編集中の操作バー（状態 S4。ui-spec U16）。「完了」で修正を反映し、目数が変われば確認（7-1）を出す
struct EditingBar: View {
    let model: EditorModel

    var body: some View {
        HStack(spacing: 8) {
            if let session = model.editingSession {
                Text("\(session.rowIndex + 1)段目を編集中")
                    .font(.subheadline.weight(.semibold))
                Text("項目の間をタップして入力位置を動かせます")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            Spacer(minLength: 4)
            Button("キャンセル") { model.cancelEditingRow() }
                .buttonStyle(.bordered)
                .accessibilityIdentifier("editing.cancel")
            Button("完了") { model.finishEditingRow() }
                .buttonStyle(.borderedProminent)
                .accessibilityIdentifier("editing.done")
        }
        .font(.caption)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color.accentColor.opacity(0.12))
    }
}
