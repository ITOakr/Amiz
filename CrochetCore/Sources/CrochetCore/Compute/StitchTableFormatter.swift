import Foundation

/// 目数表の1行（ui-spec 5-4）。同じ内容の段が続く場合は1行にまとめる（domain-spec 18）。
public struct StitchTableRow: Hashable, Sendable {
    /// 段番号の範囲（1始まり）。まとめていなければ 1...1 のように1段分
    public var rowNumbers: ClosedRange<Int>
    /// 含まれる段の ID（段の順）
    public var rowIDs: [UUID]
    /// 手順の文章（「（細編み1目、細編み2目編み入れる）×6」など）
    public var instruction: String
    /// 目数の表記（「6目」「合計36目／鎖抜き12目」）
    public var countText: String
    /// 前の段と目数が同じ「増減なし」の段（のまとまり）か
    public var isUnchangedRun: Bool

    public init(rowNumbers: ClosedRange<Int>, rowIDs: [UUID], instruction: String, countText: String, isUnchangedRun: Bool) {
        self.rowNumbers = rowNumbers
        self.rowIDs = rowIDs
        self.instruction = instruction
        self.countText = countText
        self.isUnchangedRun = isUnchangedRun
    }

    /// まとめた行か
    public var isMerged: Bool {
        rowNumbers.count > 1
    }

    /// 段番号の表記（「3段目」「5〜9段目」）
    public var rowNumberText: String {
        isMerged ? "\(rowNumbers.lowerBound)〜\(rowNumbers.upperBound)段目" : "\(rowNumbers.lowerBound)段目"
    }
}

/// 目数表の文章を作る（ui-spec 5-4・8章、domain-spec 8・16・18・19）。
///
/// 文章の書き方は ui-spec 8章のサンプルに合わせる。
/// - 数えない立ち上がり（鎖1目）と段を閉じる引き抜きは書かない。数える立ち上がりは「立ち上がり鎖3目」と書く
/// - 同じ目が続けば「細編み3目」のようにまとめる。鎖編みは「鎖2目」
/// - 繰り返しは「（…）×6」。単位が1つなら括弧を付けない。「段の終わりまで」は
///   単位が普通の目1つなら「残りの目すべてに細編み」、それ以外の1つなら「…×全目」、複数なら「（…）を段の終わりまで」
/// - 1段目には「わの作り目に」「作り目に」を頭に付ける
public enum StitchTableFormatter {
    /// 段の手順の文章
    public static func instruction(for row: Row, rowIndex: Int, in pattern: Pattern) -> String {
        let body = items(for: row.steps).joined(separator: "、")
        guard rowIndex == 0 else { return body }

        let prefix = switch pattern.foundation {
        case .magicRing: "わの作り目に"
        case .chain: "作り目に"
        }
        return prefix + body
    }

    /// 操作1つの表記。「現在の段」の項目や繰り返し終了の確認に使う（ui-spec 5-5・5-6）。
    /// 目数表の文章と違い、数えない立ち上がりや段を閉じる引き抜きも書く
    public static func label(for step: Step) -> String {
        switch step.kind {
        case .turningChain(let chains, let counted):
            "立ち上がり鎖\(chains)" + turningChainCountNote(chains: chains, counted: counted)
        case .stitch(let kind, let into):
            placementPrefix(into) + kind.japaneseName
        case .increase(let kind, let count, let into):
            placementPrefix(into) + "\(kind.instructionName)\(count)目編み入れる"
        case .decrease(let kind, let count):
            "\(kind.instructionName)\(count)目一度"
        case .skip:
            "1目飛ばす"
        case .leaveRemaining:
            "残りは編まない"
        case .closeRound:
            "引き抜き"
        case .repeatGroup(let unit, let count):
            repeatText(unit: unit, count: count)
        }
    }

    /// 作り目の行の文章（「わの作り目」「作り目：鎖21目」。domain-spec 33）
    public static func foundationText(for pattern: Pattern) -> String {
        switch pattern.foundation {
        case .magicRing:
            "わの作り目"
        case .chain:
            "作り目：鎖\(foundationChainCount(for: pattern) ?? 0)目"
        }
    }

    /// 鎖の作り目で実際に編む鎖の目数：n ＋ 1段目の立ち上がりの鎖の目数 −（1目と数えるなら 1）。
    /// 立ち上がりが決まる前は細編みの段（鎖1目）として仮に計算する。わの作り目では nil
    public static func foundationChainCount(for pattern: Pattern) -> Int? {
        guard case .chain(let stitchCount) = pattern.foundation else { return nil }
        var chains = 1
        var counted = false
        if case .turningChain(let firstRowChains, let firstRowCounted) = pattern.rows.first?.steps.first?.kind {
            chains = firstRowChains
            counted = firstRowCounted
        }
        return stitchCount + chains - (counted ? 1 : 0)
    }

    /// 目数の表記（domain-spec 8）
    public static func countText(for expansion: RowExpansion) -> String {
        if expansion.containsChains {
            "合計\(expansion.totalCount)目／鎖抜き\(expansion.nonChainCount)目"
        } else {
            "\(expansion.totalCount)目"
        }
    }

    /// 目数表の行。同じ内容で目数が変わらない段が続けば1行にまとめる（domain-spec 18）。
    /// 警告のある段はまとめない（警告が隠れないように）
    public static func tableRows(for pattern: Pattern, expansion: PatternExpansion, warnings: [RowWarning] = []) -> [StitchTableRow] {
        let warnedRows = Set(warnings.map(\.rowIndex))
        var result: [StitchTableRow] = []
        var index = 0

        while index < pattern.rows.count {
            let row = pattern.rows[index]
            let rowExpansion = expansion.rows[index]
            let text = instruction(for: row, rowIndex: index, in: pattern)
            let count = countText(for: rowExpansion)

            // この段から「増減なしのまとまり」がどこまで続くか
            var end = index
            if isUnchanged(at: index, in: expansion), !warnedRows.contains(index) {
                while end + 1 < pattern.rows.count,
                      !warnedRows.contains(end + 1),
                      pattern.rows[end + 1].hasSameSteps(as: row),
                      isUnchanged(at: end + 1, in: expansion) {
                    end += 1
                }
            }

            result.append(StitchTableRow(
                rowNumbers: (index + 1)...(end + 1),
                rowIDs: pattern.rows[index...end].map(\.id),
                instruction: text,
                countText: count,
                isUnchangedRun: isUnchanged(at: index, in: expansion)
            ))
            index = end + 1
        }

        return result
    }

    /// 前の段と目数が同じか（1段目は前段がないので false）
    private static func isUnchanged(at index: Int, in expansion: PatternExpansion) -> Bool {
        guard index > 0 else { return false }
        return expansion.rows[index].totalCount == expansion.rows[index - 1].totalCount
    }

    // MARK: - 操作の文章化

    /// 操作の列を文章の項目にする。続く同じ目と「飛ばす」はまとめる
    static func items(for steps: [Step]) -> [String] {
        var items: [String] = []
        var pendingStitch: (kind: StitchKind, into: Placement, count: Int)?
        var pendingSkips = 0

        func flush() {
            if let stitch = pendingStitch {
                items.append(placementPrefix(stitch.into) + "\(stitch.kind.instructionName)\(stitch.count)目")
                pendingStitch = nil
            }
            if pendingSkips > 0 {
                items.append("\(pendingSkips)目飛ばす")
                pendingSkips = 0
            }
        }

        for step in steps {
            switch step.kind {
            case .stitch(let kind, let into):
                if let stitch = pendingStitch, stitch.kind == kind, stitch.into == into {
                    pendingStitch = (kind, into, stitch.count + 1)
                } else {
                    flush()
                    pendingStitch = (kind, into, 1)
                }
                continue
            case .skip:
                if pendingStitch != nil { flush() }
                pendingSkips += 1
                continue
            default:
                flush()
            }

            switch step.kind {
            case .turningChain(let chains, let counted):
                // 数えない鎖1目の立ち上がりは目数表には書かない（ui-spec 8章のサンプルに合わせる）。
                // 標準と違う数え方なら「（数えない）」「（1目と数える）」を添える（domain-spec 6）
                if chains >= 2 || counted {
                    items.append("立ち上がり鎖\(chains)目" + turningChainCountNote(chains: chains, counted: counted))
                }
            case .increase(let kind, let count, let into):
                items.append(placementPrefix(into) + "\(kind.instructionName)\(count)目編み入れる")
            case .decrease(let kind, let count):
                items.append("\(kind.instructionName)\(count)目一度")
            case .leaveRemaining:
                items.append("残りは編まない")
            case .closeRound:
                // 段を閉じる引き抜きは目数表には書かない
                break
            case .repeatGroup(let unit, let count):
                items.append(repeatText(unit: unit, count: count))
            case .stitch, .skip:
                break  // 上で処理済み
            }
        }
        flush()
        return items
    }

    /// 繰り返しの文章（domain-spec 19）
    private static func repeatText(unit: [Step], count: RepeatCount) -> String {
        let unitItems = items(for: unit)
        let unitText = unitItems.joined(separator: "、")
        let isSingle = unitItems.count == 1

        switch count {
        case .times(let times):
            return isSingle ? "\(unitText)×\(times)" : "（\(unitText)）×\(times)"
        case .untilEnd:
            // 「残りの目すべてに細編み」（domain-spec 17）／「細編み2目編み入れる×全目」（ui-spec 8章）
            if isSingle, unit.count == 1, case .stitch(let kind, let into) = unit[0].kind {
                return "残りの目すべてに" + placementPrefix(into) + kind.instructionName
            }
            return isSingle ? "\(unitText)×全目" : "（\(unitText)）を段の終わりまで"
        }
    }

    /// 立ち上がりの数え方が標準（鎖1目は数えない、2目以上は数える）と違うときの注記
    static func turningChainCountNote(chains: Int, counted: Bool) -> String {
        guard counted != StepKind.standardTurningChainCounted(chains: chains) else { return "" }
        return counted ? "（1目と数える）" : "（数えない）"
    }

    /// 束に編み入れる場合の頭の言葉（束の扱いはフェーズ8で見直す）
    private static func placementPrefix(_ placement: Placement) -> String {
        placement == .chainSpace ? "束に" : ""
    }
}

extension StitchKind {
    /// 日本語の名前（凡例・ボタンなどに使う）
    public var japaneseName: String {
        switch self {
        case .chain: "鎖編み"
        case .slipStitch: "引き抜き編み"
        case .singleCrochet: "細編み"
        case .halfDoubleCrochet: "中長編み"
        case .doubleCrochet: "長編み"
        case .trebleCrochet: "長々編み"
        }
    }

    /// 手順の文章での名前。鎖編みは「鎖2目」のように「鎖」だけにする
    public var instructionName: String {
        self == .chain ? "鎖" : japaneseName
    }
}

extension WorkingMethod {
    /// 日本語の名前（作品一覧・新規作成・ツールバーの副題に使う）
    public var japaneseName: String {
        switch self {
        case .flat: "往復編み"
        case .joinedRounds: "輪編み"
        case .spiral: "螺旋編み"
        }
    }
}

extension FoundationKind {
    /// 日本語の名前
    public var japaneseName: String {
        switch self {
        case .magicRing: "わの作り目"
        case .chain: "鎖の作り目"
        }
    }
}
