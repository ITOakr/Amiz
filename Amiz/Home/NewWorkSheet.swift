import SwiftUI
import CrochetCore

/// 新規作成（シート。ui-spec 4）。
///
/// 作り目と編み方の組み合わせは、「わの作り目 × 輪編み／螺旋編み」「鎖の作り目 × 往復編み」
/// 「鎖を輪にする × 輪編み／螺旋編み」（AMIZ-75）。鎖を1目ずつ拾って輪に編む形は AMIZ-79。
struct NewWorkSheet: View {
    /// 「作成」で呼ぶ。作った作品を渡す
    let onCreate: (Work) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var foundation: FoundationChoice = .magicRing
    @State private var method: WorkingMethod = .joinedRounds
    /// 鎖の作り目の「1段目に編む目数」（domain-spec 33）
    @State private var stitchCountText = "20"
    /// 鎖を輪にする作り目の「輪にする鎖の目数」（domain-spec 33）
    @State private var ringChainCountText = "6"
    /// 最初の糸（ui-spec 4）
    @State private var yarnName = "生成り"
    @State private var yarnColor = Color(Yarn.fallback.color)
    @Environment(\.self) private var environment

    private enum FoundationChoice: Hashable {
        case magicRing
        case chain
        /// 鎖を輪にして、その中に1段目を編み入れる（domain-spec 33）
        case chainRing
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
                        Text("鎖を輪にする").tag(FoundationChoice.chainRing)
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
                    if foundation == .chainRing {
                        HStack {
                            Text("輪にする鎖の目数")
                            Spacer()
                            TextField("目数", text: $ringChainCountText)
                                .keyboardType(.numberPad)
                                .multilineTextAlignment(.trailing)
                                .frame(width: 80)
                                .accessibilityIdentifier("newWork.ringChainCount")
                        }
                    }
                } header: {
                    Text("作り目")
                } footer: {
                    if let hint = foundationHint {
                        Text(hint)
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
                    if let reason = unavailableReason {
                        Text(reason)
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
                    .disabled(unavailableReason != nil || countIsInvalid)
                    .accessibilityIdentifier("newWork.create")
                }
            }
            // 作り目を変えたら、合う編み方に切り替える（わ・鎖を輪にする → 輪編み、鎖 → 往復編み）
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

    /// 入力中の「輪にする鎖の目数」（1 以上の整数でなければ nil）
    private var ringChainCount: Int? {
        guard let count = Int(ringChainCountText.trimmingCharacters(in: .whitespaces)), count >= 1 else { return nil }
        return count
    }

    /// 目数の入力が足りているか
    private var countIsInvalid: Bool {
        (foundation == .chain && stitchCount == nil) || (foundation == .chainRing && ringChainCount == nil)
    }

    private var foundationKind: FoundationKind {
        switch foundation {
        case .magicRing: .magicRing
        case .chain: .chain(stitchCount: stitchCount ?? 1)
        case .chainRing: .chainRing(chainCount: ringChainCount ?? 1)
        }
    }

    /// 作り目の説明（domain-spec 33）
    private var foundationHint: String? {
        switch foundation {
        case .magicRing:
            nil
        case .chain:
            if let count = stitchCount {
                "実際に編む鎖は、細編みなら鎖\(count + 1)目、長編みなら鎖\(count + 2)目（立ち上がりを含む）。"
            } else {
                "1以上の目数を入れてください。"
            }
        case .chainRing:
            if let count = ringChainCount {
                "鎖\(count)目を輪にして、その中に1段目を編み入れます。1段目は何目でも編み入れられます。"
            } else {
                "1以上の目数を入れてください。"
            }
        }
    }

    /// 作れない組み合わせの理由（作れるなら nil）
    private var unavailableReason: String? {
        guard !Self.isAvailable(foundation: foundationKind, method: method) else { return nil }
        if foundation == .chain, method != .flat {
            return "鎖を1目ずつ拾って輪に編むのは今後対応します。鎖を輪にして中に編み入れるなら「鎖を輪にする」を選んでください。"
        }
        return "この組み合わせは今後対応します。わの作り目と鎖を輪にする作り目は輪編み・螺旋編みと、鎖の作り目は往復編みと組み合わせてください。"
    }
}

extension NewWorkSheet {
    /// いま作れる作り目と編み方の組み合わせ
    static func isAvailable(foundation: FoundationKind, method: WorkingMethod) -> Bool {
        switch (foundation, method) {
        case (.magicRing, .joinedRounds), (.magicRing, .spiral), (.chain, .flat),
             (.chainRing, .joinedRounds), (.chainRing, .spiral): true
        default: false
        }
    }
}

#Preview {
    NewWorkSheet { _ in }
}
