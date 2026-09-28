import Foundation
import CrochetCore

/// 案内が今どの画面にいるか（ui-spec 7-5）
enum TutorialScreen: Hashable {
    /// 作品一覧
    case home
    /// 新規作成のシート
    case newWork
    /// 編集画面
    case editor
}

/// 案内が「次へ進んでよいか」を判断するための、今の状態。
///
/// ボタンが押されたかどうかではなく、**編み図と画面の状態**で判断する（AMIZ-84）。
/// こうすると、案内と違う操作をされても破綻せず、判定だけをテストで確かめられる
struct TutorialState: Hashable {
    var screen: TutorialScreen = .home
    /// 終わった段の目数（編んだ順）
    var finishedRowCounts: [Int] = []
    /// 入力中の段の目数（段がなければ nil）
    var currentRowCount: Int?
    /// 先に選ぶボタンの状態
    var modifier = StitchModifier.none
    /// 繰り返しの入力中か
    var isInRepeat = false
    /// 目数表を見ているか
    var showsTable = false

    /// 終わった段の数
    var finishedRowCount: Int { finishedRowCounts.count }

    /// 増し目を選んでいるか
    var hasIncrease: Bool {
        if case .increase = modifier.group { true } else { false }
    }
}

/// 案内の1ステップ
struct TutorialStep: Identifiable {
    let id: String
    /// 画面に出す説明
    let message: String
    /// 光らせるボタン（`accessibilityIdentifier` と同じ文字列）。光らせないステップは nil
    let target: String?
    /// 次へ進む条件
    let isDone: (TutorialState) -> Bool
}

extension TutorialStep {
    /// わ編みのコースター（3段・6→12→18目）を一緒に作る案内（AMIZ-83）。
    ///
    /// 目数は前段をちょうど拾い切るので、途中で「前段に目が残っています」の確認は出ない
    static let coaster: [TutorialStep] = [
        TutorialStep(
            id: "newWork",
            message: "まず作品を作ります。「新規作成」を押してください。",
            target: "home.new"
        ) { $0.screen == .newWork },

        TutorialStep(
            id: "create",
            message: "コースターは中心から丸く編みます。「わの作り目」「輪編み」のまま「作成」を押してください。",
            target: "newWork.create"
        ) { $0.screen == .editor },

        TutorialStep(
            id: "firstRow",
            message: "1段目です。細編みのボタンを6回押してください。立ち上がりの鎖は自動で入ります。",
            target: "stitch.singleCrochet"
        ) { ($0.currentRowCount ?? 0) >= 6 },

        TutorialStep(
            id: "finishRow1",
            message: "6目編めました。「段を終える」を押すと、輪を閉じて次の段に進みます。",
            target: "op.finishRow"
        ) { $0.finishedRowCount >= 1 },

        TutorialStep(
            id: "untilEnd",
            message: "2段目は、前の段のすべての目に2目ずつ編んで広げます。まず「全目に」を押してください。",
            target: "modifier.untilEnd"
        ) { $0.modifier.untilEnd },

        TutorialStep(
            id: "increase",
            message: "続けて「増し目」を押します。これで「1目に2目編み入れる」という意味になります。",
            target: "modifier.increase"
        ) { $0.hasIncrease },

        TutorialStep(
            id: "row2Stitch",
            message: "最後に細編みを押してください。残りの目すべてに、細編みが2目ずつ入ります。",
            target: "stitch.singleCrochet"
        ) { ($0.currentRowCount ?? 0) >= 12 },

        TutorialStep(
            id: "finishRow2",
            message: "12目になりました。「段を終える」を押してください。",
            target: "op.finishRow"
        ) { $0.finishedRowCount >= 2 },

        TutorialStep(
            id: "beginRepeat",
            message: "3段目は「細編み1目、増し目」を6回くり返します。「繰り返し開始」を押してください。",
            target: "op.beginRepeat"
        ) { $0.isInRepeat },

        TutorialStep(
            id: "repeatStitch1",
            message: "くり返す1組ぶんを入力します。まず細編みを1回押してください。",
            target: "stitch.singleCrochet"
        ) { ($0.currentRowCount ?? 0) >= 1 },

        TutorialStep(
            id: "repeatIncrease",
            message: "次に「増し目」を押します。",
            target: "modifier.increase"
        ) { $0.hasIncrease },

        TutorialStep(
            id: "repeatStitch2",
            message: "もう一度細編みを押してください。同じ目に2目入り、これで1組（3目）です。",
            target: "stitch.singleCrochet"
        ) { ($0.currentRowCount ?? 0) >= 3 },

        TutorialStep(
            id: "endRepeat",
            message: "「繰り返し終了」を押し、回数を6にして「この回数で繰り返す」を押してください。",
            target: "op.endRepeat"
        ) { ($0.currentRowCount ?? 0) >= 18 },

        TutorialStep(
            id: "finishRow3",
            message: "18目になりました。「段を終える」を押してください。",
            target: "op.finishRow"
        ) { $0.finishedRowCount >= 3 },

        TutorialStep(
            id: "table",
            message: "「目数表」を見てみましょう。段ごとの目数と手順が、文章でも出ます。",
            target: "editor.tabs"
        ) { $0.showsTable },

        TutorialStep(
            id: "done",
            message: "コースターの編み図ができました。あとは同じように、編む順にボタンを押していくだけです。",
            target: nil
        ) { _ in false },
    ]
}
