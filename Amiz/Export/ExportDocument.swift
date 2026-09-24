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
    /// 糸リスト（色見本・名前・メモ）を表紙に載せる
    var includesYarns = true
}

/// 凡例の項目（図で使った記号だけ。domain-spec 13）
enum LegendItem: Hashable, Identifiable {
    case stitch(StitchKind)
    case turningChain
    case closingSlipStitch
    case increase(StitchKind)
    case decrease(StitchKind)
    /// 束に編み入れる（鎖のアーチをすくう。根元を離して描く。domain-spec 11）
    case chainSpace
    /// 玉編み（目の種類と本数）
    case cluster(StitchKind, count: Int)
    /// ピコット（鎖の目数）
    case picot(chains: Int)

    var id: String {
        switch self {
        case .stitch(let kind): "stitch.\(kind.rawValue)"
        case .turningChain: "turningChain"
        case .closingSlipStitch: "closingSlipStitch"
        case .increase(let kind): "increase.\(kind.rawValue)"
        case .decrease(let kind): "decrease.\(kind.rawValue)"
        case .chainSpace: "chainSpace"
        case .cluster(let kind, let count): "cluster.\(kind.rawValue).\(count)"
        case .picot(let chains): "picot.\(chains)"
        }
    }

    var title: String {
        switch self {
        case .stitch(let kind): kind.japaneseName
        case .turningChain: "立ち上がりの鎖"
        case .closingSlipStitch: "段を閉じる引き抜き"
        case .increase(let kind): "\(kind.instructionName)2目編み入れる（増し目）"
        case .decrease(let kind): "\(kind.instructionName)2目一度（減らし目）"
        case .chainSpace: "束に編み入れる（鎖のアーチをすくう）"
        case .cluster(let kind, let count): "\(kind.instructionName)\(count)目の玉編み"
        case .picot(let chains): chains == 3 ? "ピコット（鎖3目）" : "鎖\(chains)目のピコット"
        }
    }

    /// 展開結果から、使われている記号を集める（目の種類の順）
    static func items(in expansion: PatternExpansion) -> [LegendItem] {
        var kinds: Set<StitchKind> = []
        var increases: Set<StitchKind> = []
        var decreases: Set<StitchKind> = []
        var hasTurningChain = false
        var hasClosing = false
        var hasChainSpace = false
        var clusters: Set<ClusterKey> = []
        var picots: Set<Int> = []

        for row in expansion.rows {
            for stitch in row.stitches {
                switch stitch.role {
                case .turningChain:
                    hasTurningChain = true
                case .closingSlipStitch:
                    hasClosing = true
                case .picot(let chains):
                    picots.insert(chains)
                case .regular where stitch.clusterCount > 1:
                    clusters.insert(ClusterKey(kind: stitch.kind, count: stitch.clusterCount))
                    if stitch.into == .chainSpace { hasChainSpace = true }
                case .regular:
                    kinds.insert(stitch.kind)
                    // 前段を複数目まとめて拾うのは減らし目。束（アーチの鎖をまとめて拾う）は違う
                    if stitch.picks.count > 1, stitch.into != .chainSpace { decreases.insert(stitch.kind) }
                    if stitch.into == .chainSpace { hasChainSpace = true }
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
        items += clusters.sorted { ($0.kind.heightInChains, $0.count) < ($1.kind.heightInChains, $1.count) }.map { .cluster($0.kind, count: $0.count) }
        items += picots.sorted().map { .picot(chains: $0) }
        if hasChainSpace { items.append(.chainSpace) }
        return items
    }

    private struct ClusterKey: Hashable {
        let kind: StitchKind
        let count: Int
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
        let trimmed = pattern.trimmingTrailingEmptyRows(expansion: expansion)
        return StitchTableFormatter.tableRows(for: trimmed.pattern, expansion: trimmed.expansion, warnings: warnings)
    }

    /// 表紙に載せる糸リスト（糸が2本以上なら色が意味を持つ。1本でも名前・品番の控えになるので載せる）
    var yarnList: [Yarn] {
        options.includesYarns ? pattern.yarns : []
    }

    /// ページの並び
    var pages: [ExportPage] {
        var pages: [ExportPage] = []
        if options.includesChart || options.includesLegend || !yarnList.isEmpty {
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
