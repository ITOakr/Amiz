import Foundation
import Observation
import CrochetCore

/// 編集画面の状態（React の store に当たる）。
///
/// 編み図（`pattern`）とそれから計算する値（`expansion`・`layout`）は、必ず `mutate` を通して変える
/// （元に戻す用のコピーを積み、図を計算し直すため）。画面の状態（選択・先に選ぶ・編集中など）は
/// 役割ごとに分けた `EditorModel+….swift` が直接変える（AMIZ-71）
///
/// 画面はこのオブジェクトを見て描き、ボタンは `press…` を呼ぶ。編み物のルールは CrochetCore の
/// `PatternInput` に任せ、ここでは状態の保持と元に戻す／やり直しだけを扱う（tech-spec 9）。
@Observable
final class EditorModel {
    /// 編み図。変更は必ず `mutate` を通す（元に戻す用のコピーを積むため）
    private(set) var pattern: Pattern
    /// 展開結果。`pattern` が変わるたびに計算し直す（保存はしない。tech-spec 5-1）
    private(set) var expansion: PatternExpansion
    /// 図のレイアウト。`pattern` が変わるたびに計算し直す
    private(set) var layout: ChartLayout
    /// 先に選ぶボタンの状態（状態 S2）
    var modifier = StitchModifier.none
    /// 「繰り返し開始」を押した位置（入力中の段の操作数）。押していなければ nil
    var repeatStartIndex: Int?
    /// 立ち上がりの鎖の自動入力（ui-spec 6-3 の設定。画面側が UserDefaults の値を入れる）
    var autoTurningChain = true
    /// 立ち上がりを1目と数えるか（ui-spec 6-3 の設定。画面側が UserDefaults の値を入れる）
    var turningChainCounting = TurningChainCounting.standard
    /// 「毎回選択」で、立ち上がりを数えるかを聞いている最中（ui-spec 7-4）。答えが来るまで目は入れない
    var pendingTurningChainQuestion: TurningChainQuestion?
    /// 選択中の目（状態 S6。ui-spec U15）
    var selection: StitchRef?
    /// 確認待ちの修正（ui-spec 7-1）。画面がこれを見てダイアログを出す
    var pendingConfirmation: PendingConfirmation?
    /// 過去の段を編集中（状態 S4。ui-spec U16）。作業用のコピーに入力し、「完了」で編み図に反映する
    var editingSession: RowEditingSession?
    /// 色編集モード（状態 S5。ui-spec U21）。キーボードが糸パレットになり、図の目や目数表の段をタップして塗る
    var isColorEditing = false
    /// 色編集モードでパレットから選んでいる糸（塗る色）
    var paintYarnID: UUID?
    /// なぞって塗っている最中（1回のなぞりを元に戻すの1回にまとめるため）
    /// なぞって塗っている最中（1回のなぞりを元に戻すの1回にまとめるため）。分割した extension から触る
    var paintStrokeSnapshot: Pattern?

    /// 過去の段の編集（U16）
    struct RowEditingSession {
        let rowIndex: Int
        /// 作業用のコピー（「完了」までは編み図に反映しない）
        var row: Row
        /// 入力位置（操作の間。0 なら先頭）
        var cursor: Int
        /// 編集中の繰り返し開始の位置
        var repeatStartIndex: Int?
    }

    /// 上の段に影響する修正の確認待ち（ui-spec 7-1）。「上の段を残す」か「ほどく」かで適用の仕方が変わる
    struct PendingConfirmation {
        let impact: EditImpact
        let edit: RowEdit

        /// 7-1 のメッセージ（「2段目の目数が12目から14目に変わりました。3〜5段目に影響があります。」）
        var message: String {
            var text = "\(impact.editedRowNumber)段目"
            switch edit {
            case .replace:
                if let before = impact.countBefore, let after = impact.countAfter {
                    text += "の目数が\(before)目から\(after)目に変わりました。"
                } else {
                    text += "を変更します。"
                }
            case .delete:
                text += "を削除します。"
            case .duplicate(_, let times):
                text += "を\(times)回複製します。"
            }
            if let affected = impact.affectedRowsDescription {
                text += "\(affected)に影響があります。"
            }
            return text
        }
    }

    /// 「立ち上がり鎖3目を1目と数えますか？」の確認待ち（ui-spec 7-4）。答えのあとに続ける操作を覚えておく
    struct TurningChainQuestion {
        enum Action {
            /// 目ボタン（先に選ぶ状態を含む）。立ち上がりを入れてからこの目を入れる
            case stitch(StitchKind, StitchModifier)
            /// 立ち上がりボタン（U23）
            case turningChain
        }

        let chains: Int
        let action: Action

        var message: String {
            "立ち上がり鎖\(chains)目を1目と数えますか？"
        }
    }

    /// 選択した目に対する編集（ui-spec U15）
    enum SelectionEdit {
        case changeKind(StitchKind)
        case delete
        case unwrapRepeat
        case setTurningChain(Int)
        case setTurningChainCounted(Bool)
    }

    /// 元に戻す／やり直しの積み重ね（`EditorModel+Undo.swift` が使う）
    var undoStack: [Pattern] = []
    var redoStack: [Pattern] = []

    init(pattern: Pattern) {
        var pattern = pattern
        // 糸リストのない作品（色に対応する前のデータ）には既定の糸を1本入れる（domain-spec 27・29）
        if pattern.yarns.isEmpty {
            pattern.yarns = [Yarn.fallback]
        }
        self.pattern = pattern
        let expansion = pattern.expanded()
        self.expansion = expansion
        self.layout = pattern.chartLayout(expansion: expansion)
    }

    /// 画面に出す編み図。過去の段を編集中は、その段を作業用のコピーに差し替えたもの
    var displayedPattern: Pattern {
        guard let session = editingSession else { return pattern }
        var preview = pattern
        preview.rows[session.rowIndex] = session.row
        return preview
    }

    /// 今、入力の対象になっている段の位置（編集中ならその段、そうでなければ入力中の段）
    var activeRowIndex: Int? {
        editingSession?.rowIndex ?? currentRowIndex
    }

    /// 今、入力の対象になっている段の展開結果
    var activeRow: RowExpansion? {
        activeRowIndex.map { expansion.rows[$0] }
    }

    /// 新しい作品（わの作り目・輪編み）で始める
    convenience init() {
        self.init(pattern: Pattern(method: .joinedRounds, foundation: .magicRing))
    }

    // MARK: - 編み図の書き換え（状態と一緒に置く。AMIZ-71）

    /// 編み図を変える唯一の入口。元に戻す用のコピーを積み、図を計算し直す
    func mutate(_ change: (inout Pattern) -> Void) {
        let before = pattern
        var after = pattern
        change(&after)
        guard after != before else { return }
        // なぞって塗っている間は、なぞり始めの状態を1回だけ積む（endPaintStroke で）
        if paintStrokeSnapshot == nil {
            undoStack.append(before)
            redoStack.removeAll()
        }
        pattern = after
        recompute()
    }

    /// 元に戻す／やり直しで編み図を差し替える。先に選ぶ状態と繰り返し開始の位置はずれるので解除する
    func replacePattern(with newPattern: Pattern) {
        pattern = newPattern
        editingSession = nil
        recompute()
        modifier = .none
        repeatStartIndex = nil
        selection = nil
    }

    /// 展開結果とレイアウトを計算し直す（編集中は作業用のコピーを差し込んだ編み図から）
    /// 展開結果とレイアウトを計算し直す
    func recompute() {
        let shown = displayedPattern
        expansion = shown.expanded()
        layout = shown.chartLayout(expansion: expansion)
    }
}
