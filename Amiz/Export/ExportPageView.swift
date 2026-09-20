import SwiftUI
import CrochetCore

/// 書き出し用の1ページ（A4）。画面表示とは別のレイアウト（tech-spec 10）。
/// 色は白地に黒で固定する（印刷・共有先で見え方が変わらないように）。
struct ExportPageView: View {
    let document: ExportDocument
    let page: ExportPage
    let pageNumber: Int
    let pageCount: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            switch page {
            case .cover:
                cover
            case .table(let rows, _):
                table(rows)
            }
            Spacer(minLength: 0)
            footer
        }
        .padding(36)
        .frame(width: ExportDocument.pageSize.width, height: ExportDocument.pageSize.height)
        .background(Color.white)
        .foregroundStyle(.black)
        .environment(\.colorScheme, .light)
    }

    // MARK: - 共通

    private var header: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(document.title)
                .font(.title2.weight(.bold))
            Text("\(document.pattern.method.japaneseName)・\(document.pattern.foundation.japaneseName)")
                .font(.caption)
                .foregroundStyle(.gray)
        }
        .padding(.bottom, 12)
    }

    private var footer: some View {
        HStack {
            Spacer()
            Text("\(pageNumber) / \(pageCount)")
                .font(.caption2)
                .foregroundStyle(.gray)
        }
        .padding(.top, 8)
    }

    // MARK: - 表紙：図と凡例

    private var cover: some View {
        VStack(alignment: .leading, spacing: 12) {
            if document.options.includesChart {
                chart
                    .frame(maxWidth: .infinity)
                    .frame(height: document.options.includesLegend ? 470 : 660)
            }
            if document.options.includesLegend {
                legend
            }
        }
    }

    /// 図（ハイライトなし、全段を黒で）
    private var chart: some View {
        Canvas { context, size in
            let transform = ChartTransform.fitting(document.layout, in: size, inset: 8)
            var painter = ChartPainter(layout: document.layout, transform: transform)
            painter.showsRowNumbers = true
            painter.showsSeamMarks = document.pattern.method == .spiral
            painter.draw(in: &context)
        }
        .accessibilityIdentifier("export.chart")
    }

    /// 凡例：図で使った記号だけ（domain-spec 13）
    private var legend: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("記号")
                .font(.headline)
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 160), spacing: 8, alignment: .leading)], alignment: .leading, spacing: 6) {
                ForEach(document.legendItems) { item in
                    HStack(spacing: 8) {
                        LegendSymbolView(item: item)
                        Text(item.title)
                            .font(.caption)
                    }
                }
            }
        }
    }

    // MARK: - 目数表

    private func table(_ rows: [StitchTableRow]) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("目数表")
                .font(.headline)
                .padding(.bottom, 6)
            tableRow(number: "段", instruction: "手順", count: "目数", isHeader: true)
            if case .table(_, 0) = page {
                tableRow(number: "作り目", instruction: StitchTableFormatter.foundationText(for: document.pattern), count: "")
            }
            ForEach(rows, id: \.rowNumbers) { row in
                tableRow(
                    number: row.rowNumberText,
                    instruction: row.instruction,
                    count: row.countText + (row.isUnchangedRun ? "（増減なし）" : ""),
                    warning: row.rowIDs.count == 1 ? document.warnings.first { $0.rowIndex == row.rowNumbers.lowerBound - 1 }?.message : nil
                )
            }
        }
    }

    private func tableRow(number: String, instruction: String, count: String, isHeader: Bool = false, warning: String? = nil) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(number)
                    .frame(width: 64, alignment: .leading)
                Text(instruction)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text(count)
                    .frame(width: 120, alignment: .trailing)
            }
            .font(isHeader ? .caption.weight(.semibold) : .caption)
            .foregroundStyle(isHeader ? .gray : .black)
            if let warning {
                Text("⚠ " + warning)
                    .font(.caption2)
                    .foregroundStyle(.red)
                    .padding(.leading, 72)
            }
        }
        .padding(.vertical, 3)
        .overlay(alignment: .bottom) {
            Rectangle().fill(Color.gray.opacity(0.3)).frame(height: 0.5)
        }
    }
}

/// 凡例の記号
private struct LegendSymbolView: View {
    let item: LegendItem

    var body: some View {
        Canvas { context, size in
            let style = StitchSymbol.Style(unit: 16, lineWidth: 1.4)
            let bottom = CGPoint(x: size.width / 2, y: size.height - 4)
            let color = Color.black
            switch item {
            case .stitch(let kind):
                let top = CGPoint(x: size.width / 2, y: kind.heightInChains == 0 ? size.height / 2 : 4)
                let root = kind.heightInChains == 0 ? CGPoint(x: size.width / 2, y: size.height / 2 + 1) : bottom
                var stroke = StitchSymbol.strokePath(kind: kind, from: root, to: top, style: style)
                if kind == .chain {
                    stroke = stroke.applying(CGAffineTransform(translationX: top.x, y: top.y).rotated(by: .pi / 2).translatedBy(x: -top.x, y: -top.y))
                }
                context.stroke(stroke, with: .color(color), lineWidth: style.lineWidth)
                context.fill(StitchSymbol.fillPath(kind: kind, from: root, to: top, style: style), with: .color(color))
            case .turningChain:
                context.stroke(StitchSymbol.turningChainPath(chains: 3, from: bottom, to: CGPoint(x: size.width / 2, y: 4), style: style), with: .color(color), lineWidth: style.lineWidth)
            case .closingSlipStitch:
                let center = CGPoint(x: size.width / 2, y: size.height / 2)
                context.fill(StitchSymbol.fillPath(kind: .slipStitch, from: CGPoint(x: center.x, y: center.y + 1), to: center, style: style), with: .color(color))
            case .increase(let kind):
                for dx in [-7.0, 7.0] {
                    context.stroke(StitchSymbol.strokePath(kind: kind, from: bottom, to: CGPoint(x: size.width / 2 + dx, y: 4), style: style, cross: .nearHead), with: .color(color), lineWidth: style.lineWidth)
                }
            case .decrease(let kind):
                for dx in [-7.0, 7.0] {
                    context.stroke(StitchSymbol.strokePath(kind: kind, from: CGPoint(x: size.width / 2 + dx, y: size.height - 4), to: CGPoint(x: size.width / 2, y: 4), style: style, cross: .nearRoot), with: .color(color), lineWidth: style.lineWidth)
                }
            }
        }
        .frame(width: 32, height: 32)
    }
}

#Preview("表紙") {
    let document = ExportDocument(title: "くまの頭", pattern: SamplePatterns.bearHead, options: ExportOptions())
    return ExportPageView(document: document, page: .cover, pageNumber: 1, pageCount: 2)
}

#Preview("目数表") {
    let document = ExportDocument(title: "くまの頭", pattern: SamplePatterns.bearHead, options: ExportOptions())
    return ExportPageView(document: document, page: document.pages[1], pageNumber: 2, pageCount: 2)
}
