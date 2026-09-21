import SwiftUI
import CrochetCore

/// 糸リスト（ui-spec 6-1、U17）。作品で使う糸の一覧。
/// タップした糸に持ち替え、右の「i」で名前・色・メモを編集する。「追加」で新しい糸、編集モードで並べ替えと削除
struct YarnListSheet: View {
    let model: EditorModel

    @Environment(\.dismiss) private var dismiss
    /// 編集中の糸（新規なら `isNew`）
    @State private var editing: EditingYarn?

    private struct EditingYarn: Identifiable {
        var yarn: Yarn
        var isNew: Bool
        var id: UUID { yarn.id }
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(model.yarns) { yarn in
                        row(yarn)
                    }
                    .onMove { source, destination in
                        model.moveYarns(fromOffsets: source, toOffset: destination)
                    }
                    .onDelete { offsets in
                        for index in offsets.sorted(by: >) {
                            model.deleteYarn(id: model.yarns[index].id)
                        }
                    }
                } footer: {
                    Text("タップした糸に持ち替えます。先頭の糸が既定の糸です。糸を削除すると、その糸で編んだ目は既定の糸に戻ります。")
                }
            }
            .navigationTitle("糸リスト")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("閉じる") { dismiss() }
                        .accessibilityIdentifier("yarns.close")
                }
                ToolbarItemGroup(placement: .primaryAction) {
                    EditButton()
                    Button("追加", systemImage: "plus") {
                        editing = EditingYarn(yarn: Yarn(name: "", color: YarnColor(hex: "#A8C5E2")!), isNew: true)
                    }
                    .accessibilityIdentifier("yarns.add")
                }
            }
            .sheet(item: $editing) { item in
                YarnEditSheet(yarn: item.yarn, isNew: item.isNew, canDelete: model.yarns.count > 1) { edited in
                    if item.isNew {
                        model.addYarn(edited)
                    } else {
                        model.updateYarn(edited)
                    }
                } onDelete: {
                    model.deleteYarn(id: item.yarn.id)
                }
            }
        }
    }

    /// 1本の糸の行：色見本、名前、メモ、持っている印、編集ボタン
    private func row(_ yarn: Yarn) -> some View {
        HStack(spacing: 12) {
            Button {
                model.changeYarn(to: yarn.id)
            } label: {
                HStack(spacing: 12) {
                    YarnSwatch(color: yarn.color, size: 28)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(yarn.name.isEmpty ? "（名前なし）" : yarn.name)
                        if !yarn.memo.isEmpty {
                            Text(yarn.memo)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    Spacer()
                    if model.currentYarn.id == yarn.id {
                        Image(systemName: "checkmark")
                            .foregroundStyle(.tint)
                            .accessibilityLabel("持っている")
                    }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("yarns.row.\(yarn.name)")

            Button("編集", systemImage: "info.circle") {
                editing = EditingYarn(yarn: yarn, isNew: false)
            }
            .labelStyle(.iconOnly)
            .buttonStyle(.borderless)
            .accessibilityIdentifier("yarns.edit.\(yarn.name)")
        }
    }
}

/// 糸の追加・編集（名前・色・メモ）
struct YarnEditSheet: View {
    @State var yarn: Yarn
    let isNew: Bool
    let canDelete: Bool
    let onSave: (Yarn) -> Void
    let onDelete: () -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.self) private var environment
    @State private var pickedColor: Color

    init(yarn: Yarn, isNew: Bool, canDelete: Bool, onSave: @escaping (Yarn) -> Void, onDelete: @escaping () -> Void) {
        _yarn = State(initialValue: yarn)
        _pickedColor = State(initialValue: Color(yarn.color))
        self.isNew = isNew
        self.canDelete = canDelete
        self.onSave = onSave
        self.onDelete = onDelete
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("名前", text: $yarn.name, prompt: Text("例：生成り、こげ茶"))
                        .accessibilityIdentifier("yarn.name")
                    ColorPicker("色", selection: $pickedColor, supportsOpacity: false)
                        .accessibilityIdentifier("yarn.color")
                    TextField("メモ", text: $yarn.memo, prompt: Text("品番など（任意）"))
                        .accessibilityIdentifier("yarn.memo")
                }
                if !isNew, canDelete {
                    Section {
                        Button("この糸を削除", role: .destructive) {
                            onDelete()
                            dismiss()
                        }
                        .accessibilityIdentifier("yarn.delete")
                    } footer: {
                        Text("この糸で編んだ目は既定の糸に戻ります。")
                    }
                }
            }
            .navigationTitle(isNew ? "糸を追加" : "糸を編集")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(isNew ? "追加" : "保存") {
                        var saved = yarn
                        saved.color = YarnColor(pickedColor, in: environment)
                        if saved.name.trimmingCharacters(in: .whitespaces).isEmpty {
                            saved.name = "糸"
                        }
                        onSave(saved)
                        dismiss()
                    }
                    .accessibilityIdentifier("yarn.save")
                }
            }
        }
    }
}

#Preview {
    let model = EditorModel(pattern: SamplePatterns.bearHead)
    return YarnListSheet(model: model)
}
