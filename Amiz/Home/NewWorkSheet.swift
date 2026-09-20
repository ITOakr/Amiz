import SwiftUI
import CrochetCore

/// 新規作成（シート。ui-spec 4）。
///
/// 当面選べるのは「わの作り目」「輪編み」だけ。鎖の作り目はフェーズ7、螺旋編み・往復編みはフェーズ6・7で有効にする。
/// 「最初の糸」はフェーズ9。
struct NewWorkSheet: View {
    /// 「作成」で呼ぶ。作った作品を渡す
    let onCreate: (Work) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var foundation: FoundationChoice = .magicRing
    @State private var method: WorkingMethod = .joinedRounds

    private enum FoundationChoice: Hashable {
        case magicRing
        case chain
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("作品名") {
                    TextField("作品名", text: $name, prompt: Text("例：くまの頭"))
                        .accessibilityIdentifier("newWork.name")
                }
                Section("作り目") {
                    Picker("作り目", selection: $foundation) {
                        Text("わの作り目").tag(FoundationChoice.magicRing)
                        Text("鎖の作り目（今後対応）").tag(FoundationChoice.chain)
                    }
                    .pickerStyle(.inline)
                    .labelsHidden()
                }
                Section("編み方") {
                    Picker("編み方", selection: $method) {
                        ForEach(WorkingMethod.allCases, id: \.self) { method in
                            Text(method == .joinedRounds ? method.japaneseName : "\(method.japaneseName)（今後対応）")
                                .tag(method)
                        }
                    }
                    .pickerStyle(.inline)
                    .labelsHidden()
                }
            }
            .navigationTitle("新規作成")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("作成") {
                        let work = Work(
                            name: name.trimmingCharacters(in: .whitespaces).isEmpty ? "新しい作品" : name,
                            pattern: Pattern(method: .joinedRounds, foundation: .magicRing)
                        )
                        onCreate(work)
                        dismiss()
                    }
                    // 当面は わの作り目・輪編み 以外は作れない
                    .disabled(foundation != .magicRing || method != .joinedRounds)
                    .accessibilityIdentifier("newWork.create")
                }
            }
        }
    }
}

#Preview {
    NewWorkSheet { _ in }
}
