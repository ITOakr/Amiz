import Foundation
import Testing
import UIKit
@testable import Amiz

// ImageRenderer はメインスレッドで使う
@MainActor
@Suite("PDF・画像への変換（ExportRenderer）")
struct ExportRendererTests {
    @Test("くまの頭を PDF にすると2ページ（表紙＋目数表）のファイルができる")
    func pdf() throws {
        let document = ExportDocument(title: "くまの頭", pattern: SamplePatterns.bearHead, options: ExportOptions())
        let url = try ExportRenderer.export(document)

        #expect(url.lastPathComponent == "くまの頭.pdf")
        #expect(FileManager.default.fileExists(atPath: url.path))
        #expect(ExportRenderer.pdfPageCount(at: url) == 2)
        try? FileManager.default.removeItem(at: url)
    }

    @Test("60段の作品は PDF が4ページになる")
    func multiPagePDF() throws {
        let document = ExportDocument(title: "大", pattern: SamplePatterns.largeDisc(rows: 60), options: ExportOptions())
        let url = try ExportRenderer.export(document)
        #expect(ExportRenderer.pdfPageCount(at: url) == 4)
        try? FileManager.default.removeItem(at: url)
    }

    @Test("画像にすると、A4 の幅の2倍で全ページを縦に並べた PNG ができる")
    func png() throws {
        var options = ExportOptions()
        options.format = .image
        let document = ExportDocument(title: "くまの頭", pattern: SamplePatterns.bearHead, options: options)
        let url = try ExportRenderer.export(document)

        #expect(url.lastPathComponent == "くまの頭.png")
        // ファイルから読むと scale は 1 で、size がピクセル数になる
        let image = try #require(UIImage(contentsOfFile: url.path))
        #expect(image.size.width * image.scale == ExportDocument.pageSize.width * 2)
        #expect(image.size.height * image.scale == ExportDocument.pageSize.height * 2 * 2)
        try? FileManager.default.removeItem(at: url)
    }

    @Test("作品名に / が含まれてもファイル名にできる")
    func fileName() {
        let url = ExportRenderer.outputURL(title: "赤/青の帽子", format: .pdf)
        #expect(url.lastPathComponent == "赤-青の帽子.pdf")
        #expect(ExportRenderer.outputURL(title: "  ", format: .image).lastPathComponent == "編み図.png")
    }
}
