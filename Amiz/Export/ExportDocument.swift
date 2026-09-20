import Foundation
import CrochetCore

/// 書き出しの設定（ui-spec 6-2）
struct ExportOptions: Hashable {
    enum Format: String, CaseIterable, Identifiable {
        case pdf = "PDF"
        case image = "画像"

        var id: String { rawValue }
    }

    var format: Format = .pdf
    var includesChart = true
    var includesTable = true
    var includesLegend = true
    /// 糸リストはフェーズ9で対応する
    var includesYarns = false
}

/// 凡例の項目（図で使った記号だけ。domain-spec 13）
enum LegendItem: Hashable, Identifiable {
    case stitch(StitchKind)
    case turningChain
    case closingSlipStitch
    case increase(StitchKind)
    case decrease(StitchKind)

    var id: String {
        switch self {
        case .stitch(let kind): "stitch.\(kind.rawValue)"
        case .turningChain: "turningChain"
        case .closingSlipStitch: "closingSlipStitch"
        case .increase(let kind): "increase.\(kind.rawValue)"
        case .decrease(let kind): "decrease.\(kind.rawValue)"
        }
    }

    var title: String {
        switch self {
        case .stitch(let kind): kind.japaneseName
        case .turningChain: "立ち上がりの鎖"
        case .closingSlipStitch: "段を閉じる引き抜き"
        case .increase(let kind): "\(kind.instructionName)2目編み入れる（増し目）"
        case .decrease(let kind): "\(kind.instructionName)2目一度（減らし目）"
        }
    }

    /// 展開結果から、使われている記号を集める（目の種類の順）
    static func items(in expansion: PatternExpansion) -> [LegendItem] {
        var kinds: Set<StitchKind> = []
        var increases: Set<StitchKind> = []
        var decreases: Set<StitchKind> = []
        var hasTurningChain = false
        var hasClosing = false

        for row in expansion.rows {
            for stitch in row.stitches {
                switch stitch.role {
                case .turningChain:
                    hasTurningChain = true
                case .closingSlipStitch:
                    hasClosing = true
                case .regular:
                    kinds.insert(stitch.kind)
                    // 前段を複数目まとめて拾うのは減らし目。束（アーチの鎖をまとめて拾う）は違う
                    if stitch.picks.count > 1, stitch.into != .chainSpace { decreases.insert(stitch.kind) }
                }
            }
            // 同じ根元を共有する目（増し目）
            let grouped = Dictionary(grouping: row.stitches.filter { $0.role == .regular && !$0.picks.isEmpty }) { $0.picks }
            for (_, stitches) in grouped where stitches.count > 1 {
                for stitch in stitches { increases.insert(stitch.kind) }
            }
        }

        var items: [LegendItem] = StitchKind.allCases.filter { kinds.contains($0) }.map { .stitch($0) }
        if hasTurningChain { items.append(.turningChain) }
        if hasClosing { items.append(.closingSlipStitch) }
        items += StitchKind.allCases.filter { increases.contains($0) }.map { .increase($0) }
        items += StitchKind.allCases.filter { decreases.contains($0) }.map { .decrease($0) }
        return items
    }
}

/// 書き出す1ページ
enum ExportPage: Hashable, Identifiable {
    /// 表紙：作品名、図、凡例
    case cover
    /// 目数表（分割した行）。`pageIndex` は目数表の何ページ目か（0始まり）
    case table(rows: [StitchTableRow], pageIndex: Int)

    var id: String {
        switch self {
        case .cover: "cover"
        case .table(_, let index): "table.\(index)"
        }
    }
}

/// 書き出す内容を A4 のページに組み立てる（tech-spec 10）。描画は `ExportPageView`
struct ExportDocument {
    /// A4（pt）
    static let pageSize = CGSize(width: 595, height: 842)
    /// 目数表の1ページに入れる段の行数
    static let tableRowsPerPage = 28

    let title: String
    let pattern: Pattern
    let expansion: PatternExpansion
    let layout: ChartLayout
    let options: ExportOptions

    init(title: String, pattern: Pattern, options: ExportOptions) {
        self.title = title
        self.pattern = pattern
        self.expansion = pattern.expanded()
        self.layout = pattern.chartLayout(expansion: expansion)
        self.options = options
    }

    /// 凡例の項目（図で使った記号だけ）
    var legendItems: [LegendItem] {
        LegendItem.items(in: expansion)
    }

    /// 目数の警告（書き出し前の確認 7-3 に使う。入力を始めていない末尾の空の段は除く）
    var warnings: [RowWarning] {
        let excluded = (pattern.rows.last?.steps.isEmpty == true) ? pattern.rows.count - 1 : nil
        return expansion.warnings(excludingRowAt: excluded)
    }

    /// 書き出し前の確認の文（ui-spec 7-3）。警告がなければ nil
    var confirmationMessage: String? {
        let numbers = warnings.map(\.rowNumber)
        guard !numbers.isEmpty else { return nil }
        let list = numbers.map(String.init).joined(separator: "・")
        return "目数が合っていない段があります（\(list)段目）。このまま書き出しますか？"
    }

    /// 目数表の行（空の末尾の段は含めない）
    var tableRows: [StitchTableRow] {
        var trimmed = pattern
        var trimmedExpansion = expansion
        while let last = trimmed.rows.last, last.steps.isEmpty {
            trimmed.rows.removeLast()
            trimmedExpansion.rows.removeLast()
        }
        return StitchTableFormatter.tableRows(for: trimmed, expansion: trimmedExpansion, warnings: warnings)
    }

    /// ページの並び
    var pages: [ExportPage] {
        var pages: [ExportPage] = []
        if options.includesChart || options.includesLegend {
            pages.append(.cover)
        }
        if options.includesTable {
            let rows = tableRows
            let perPage = Self.tableRowsPerPage
            if rows.isEmpty {
                pages.append(.table(rows: [], pageIndex: 0))
            } else {
                for (index, start) in stride(from: 0, to: rows.count, by: perPage).enumerated() {
                    pages.append(.table(rows: Array(rows[start..<min(start + perPage, rows.count)]), pageIndex: index))
                }
            }
        }
        return pages
    }
}
