import Foundation
import Testing
import CrochetCore
@testable import Amiz

@Suite("書き出し用のページ（ExportDocument）")
struct ExportDocumentTests {
    @Test("凡例は図で使った記号だけ：くまの頭は 細編み・立ち上がり・引き抜き・細編みの増し目")
    func legendForBearHead() {
        let document = ExportDocument(title: "くまの頭", pattern: SamplePatterns.bearHead, options: ExportOptions())
        #expect(document.legendItems == [.stitch(.singleCrochet), .turningChain, .closingSlipStitch, .increase(.singleCrochet)])
    }

    @Test("凡例：長編みと鎖のモチーフ（3段目は束に細編み3目）、減らし目のある作品")
    func legendForOthers() {
        let motif = ExportDocument(title: "花", pattern: SamplePatterns.flowerMotif, options: ExportOptions())
        #expect(motif.legendItems == [.stitch(.chain), .stitch(.singleCrochet), .stitch(.doubleCrochet), .turningChain, .closingSlipStitch, .increase(.singleCrochet), .chainSpace])

        var pattern = SamplePatterns.bearHead
        pattern.rows[4] = Row(steps: [.turningChain(1), .untilEnd([.decrease(.singleCrochet)]), .closeRound()])
        let decreasing = ExportDocument(title: "減らし", pattern: pattern, options: ExportOptions())
        #expect(decreasing.legendItems.contains(.decrease(.singleCrochet)))
    }

    @Test("螺旋編み（うさぎの胴体）：凡例に立ち上がり・引き抜きは出ず、目数表は12段で警告なし")
    func spiralRabbitBody() {
        let document = ExportDocument(title: "うさぎの胴体", pattern: SamplePatterns.rabbitBody, options: ExportOptions())
        #expect(document.legendItems == [.stitch(.singleCrochet), .increase(.singleCrochet), .decrease(.singleCrochet)])
        #expect(document.warnings.isEmpty)
        #expect(document.tableRows.map(\.rowNumberText).last == "12段目")
        #expect(document.tableRows.contains { $0.rowNumberText == "6〜9段目" })
        #expect(document.pages.map(\.id) == ["cover", "table.0"])
    }

    @Test("糸リスト：含めると表紙に糸が載る。外すと載らず、図も凡例もなければ表紙自体がない")
    func yarnList() {
        let colored = ExportDocument(title: "くま", pattern: SamplePatterns.bearHeadColored, options: ExportOptions())
        #expect(colored.yarnList.map(\.name) == ["生成り", "こげ茶", "白"])
        #expect(colored.pages.first?.id == "cover")

        var without = ExportOptions()
        without.includesYarns = false
        #expect(ExportDocument(title: "くま", pattern: SamplePatterns.bearHeadColored, options: without).yarnList.isEmpty)

        var onlyYarns = ExportOptions()
        onlyYarns.includesChart = false
        onlyYarns.includesLegend = false
        onlyYarns.includesTable = false
        #expect(ExportDocument(title: "くま", pattern: SamplePatterns.bearHeadColored, options: onlyYarns).pages.map(\.id) == ["cover"])
        onlyYarns.includesYarns = false
        #expect(ExportDocument(title: "くま", pattern: SamplePatterns.bearHeadColored, options: onlyYarns).pages.isEmpty)
    }

    @Test("ページ：くまの頭は表紙＋目数表1ページ。60段なら目数表が複数ページ。含める内容で変わる")
    func pages() {
        let bear = ExportDocument(title: "くまの頭", pattern: SamplePatterns.bearHead, options: ExportOptions())
        #expect(bear.pages.map(\.id) == ["cover", "table.0"])
        // 入力中の5段目（4目）は目数表に含める（空ではないため）
        if case .table(let rows, _) = bear.pages[1] {
            #expect(rows.count == 5)
        } else {
            Issue.record("2ページ目は目数表のはず")
        }

        // 60段（毎段増し目なので同じ内容の段はまとまらない）→ 28行ずつで3ページ
        let big = ExportDocument(title: "大", pattern: SamplePatterns.largeDisc(rows: 60), options: ExportOptions())
        #expect(big.pages.count == 1 + 3)

        var tableOnly = ExportOptions()
        tableOnly.includesChart = false
        tableOnly.includesLegend = false
        #expect(ExportDocument(title: "", pattern: SamplePatterns.bearHead, options: tableOnly).pages.map(\.id) == ["table.0"])

        var chartOnly = ExportOptions()
        chartOnly.includesTable = false
        #expect(ExportDocument(title: "", pattern: SamplePatterns.bearHead, options: chartOnly).pages.map(\.id) == ["cover"])
    }

    @Test("末尾の空の段は目数表に含めず、警告の対象にもしない")
    func trailingEmptyRow() {
        var pattern = SamplePatterns.bearHead
        pattern.rows[4] = Row(steps: [.turningChain(1), .untilEnd([.stitch(.singleCrochet)]), .closeRound()])
        pattern.rows.append(Row())
        let document = ExportDocument(title: "", pattern: pattern, options: ExportOptions())
        #expect(document.tableRows.count == 5)
        #expect(document.warnings.isEmpty)
        #expect(document.confirmationMessage == nil)
    }

    @Test("警告のある段が複数なら「3・4・5段目」のように並べる")
    func confirmationMessageForMultipleRows() {
        var pattern = SamplePatterns.bearHead
        // 3段目を前段を拾い切らない手順にする → 3段目の目数が減り、4段目・5段目も合わなくなる
        pattern.rows[2] = Row(steps: [.turningChain(1), .stitch(.singleCrochet), .closeRound()])
        let document = ExportDocument(title: "", pattern: pattern, options: ExportOptions())
        #expect(document.confirmationMessage == "目数が合っていない段があります（3・4・5段目）。このまま書き出しますか？")
    }

    @Test("入力途中の最後の段が空でなければ、書き出しでは警告の対象になる（7-3 の確認が出る）")
    func unfinishedLastRowWarns() {
        let document = ExportDocument(title: "", pattern: SamplePatterns.bearHead, options: ExportOptions())
        #expect(document.warnings.map(\.rowNumber) == [5])
        #expect(document.confirmationMessage == "目数が合っていない段があります（5段目）。このまま書き出しますか？")
    }
}

/// 書き出しのファイル名（AMIZ-73）
@Suite("書き出しのファイル名")
@MainActor
struct ExportFileNameTests {
    @Test("使えない文字は置き換え、先頭の点と長すぎる名前を避ける")
    func safeFileName() {
        #expect(ExportRenderer.safeFileName(from: "くまの頭") == "くまの頭")
        #expect(ExportRenderer.safeFileName(from: "赤/青の帽子") == "赤-青の帽子")
        #expect(ExportRenderer.safeFileName(from: "../../秘密") == "秘密")
        #expect(ExportRenderer.safeFileName(from: "..") == "編み図")
        #expect(ExportRenderer.safeFileName(from: ".隠し") == "隠し")
        #expect(ExportRenderer.safeFileName(from: "   ") == "編み図")
        #expect(ExportRenderer.safeFileName(from: "改行\nあり") == "改行-あり")
        #expect(ExportRenderer.safeFileName(from: String(repeating: "あ", count: 300)).count == 60)
        #expect(ExportRenderer.outputURL(title: "赤/青", format: .pdf).lastPathComponent == "赤-青.pdf")
    }

    @Test("変な名前でも書き出せる")
    func exportsWithOddTitle() throws {
        var options = ExportOptions()
        options.includesTable = false
        let document = ExportDocument(title: "../*?:危険", pattern: SamplePatterns.bearHead, options: options)
        let url = try ExportRenderer.export(document)
        #expect(FileManager.default.fileExists(atPath: url.path))
        #expect(url.path.contains("tmp"))
        try? FileManager.default.removeItem(at: url)
    }
}
