import SwiftUI
import CrochetCore

/// 新規作成（シート。ui-spec 4）。
///
/// 作り目と編み方の組み合わせは、当面「わの作り目 × 輪編み／螺旋編み」と「鎖の作り目 × 往復編み」だけ
/// （鎖を輪にして編み始める作品は AMIZ-36）。「最初の糸」はフェーズ9。
struct NewWorkSheet: View {
    /// 「作成」で呼ぶ。作った作品を渡す
    let onCreate: (Work) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var foundation: FoundationChoice = .magicRing
    @State private var method: WorkingMethod = .joinedRounds
    /// 鎖の作り目の「1段目に編む目数」（domain-spec 33）
    @State private var stitchCountText = "20"
    /// 最初の糸（ui-spec 4）
    @State private var yarnName = "生成り"
    @State private var yarnColor = Color(Yarn.fallback.color)
    @Environment(\.self) private var environment

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
                Section {
                    Picker("作り目", selection: $foundation) {
                        Text("わの作り目").tag(FoundationChoice.magicRing)
                        Text("鎖の作り目").tag(FoundationChoice.chain)
                    }
                    .pickerStyle(.inline)
                    .labelsHidden()
                    if foundation == .chain {
                        HStack {
                            Text("1段目に編む目数")
                            Spacer()
                            TextField("目数", text: $stitchCountText)
                                .keyboardType(.numberPad)
                                .multilineTextAlignment(.trailing)
                                .frame(width: 80)
                                .accessibilityIdentifier("newWork.stitchCount")
                        }
                    }
                } header: {
                    Text("作り目")
                } footer: {
                    if foundation == .chain {
                        Text(chainHint)
                    }
                }
                Section {
                    Picker("編み方", selection: $method) {
                        ForEach(WorkingMethod.allCases, id: \.self) { method in
                            Text(method.japaneseName).tag(method)
                        }
                    }
                    .pickerStyle(.inline)
                    .labelsHidden()
                } header: {
                    Text("編み方")
                } footer: {
                    if !Self.isAvailable(foundation: foundationKind, method: method) {
                        Text("この組み合わせは今後対応します。鎖の作り目は往復編みと、わの作り目は輪編み・螺旋編みと組み合わせてください。")
                    }
                }
                Section {
                    TextField("名前", text: $yarnName, prompt: Text("例：生成り"))
                        .accessibilityIdentifier("newWork.yarnName")
                    ColorPicker("色", selection: $yarnColor, supportsOpacity: false)
                } header: {
                    Text("最初の糸")
                } footer: {
                    Text("糸は編集画面の糸リストで後から追加・変更できます。")
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
                        let yarn = Yarn(
                            name: yarnName.trimmingCharacters(in: .whitespaces).isEmpty ? "糸" : yarnName,
                            color: YarnColor(yarnColor, in: environment)
                        )
                        let work = Work(
                            name: name.trimmingCharacters(in: .whitespaces).isEmpty ? "新しい作品" : name,
                            pattern: Pattern(method: method, foundation: foundationKind, yarns: [yarn])
                        )
                        onCreate(work)
                        dismiss()
                    }
                    .disabled(!Self.isAvailable(foundation: foundationKind, method: method) || (foundation == .chain && stitchCount == nil))
                    .accessibilityIdentifier("newWork.create")
                }
            }
            // 作り目を変えたら、合う編み方に切り替える（わ → 輪編み、鎖 → 往復編み）
            .onChange(of: foundation) { _, choice in
                method = choice == .chain ? .flat : .joinedRounds
            }
        }
    }

    /// 入力中の「1段目に編む目数」（1 以上の整数でなければ nil）
    private var stitchCount: Int? {
        guard let count = Int(stitchCountText.trimmingCharacters(in: .whitespaces)), count >= 1 else { return nil }
        return count
    }

    private var foundationKind: FoundationKind {
        switch foundation {
        case .magicRing: .magicRing
        case .chain: .chain(stitchCount: stitchCount ?? 1)
        }
    }

    /// 「細編みなら鎖21目、長編みなら鎖22目」（domain-spec 33）
    private var chainHint: String {
        guard let count = stitchCount else { return "1以上の目数を入れてください。" }
        return "実際に編む鎖は、細編みなら鎖\(count + 1)目、長編みなら鎖\(count + 2)目（立ち上がりを含む）。"
    }
}

extension NewWorkSheet {
    /// いま作れる作り目と編み方の組み合わせ
    static func isAvailable(foundation: FoundationKind, method: WorkingMethod) -> Bool {
        switch (foundation, method) {
        case (.magicRing, .joinedRounds), (.magicRing, .spiral), (.chain, .flat): true
        default: false
        }
    }
}

#Preview {
    NewWorkSheet { _ in }
}
