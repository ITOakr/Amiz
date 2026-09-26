import SwiftUI
import UniformTypeIdentifiers

/// 書き出し用のページを PDF・画像に変換してファイルに書く（tech-spec 10）。
///
/// ImageRenderer は1回の描画で1ページを作るので、PDF は CGContext の PDF に1ページずつ描く。
/// 画像は全ページを縦に並べた1枚の PNG（2倍の解像度）。
/// ImageRenderer はメインスレッドで使う必要がある。
@MainActor
enum ExportRenderer {
    enum Failure: Error {
        case cannotCreatePDF
        case cannotRenderImage
        case cannotWriteFile
    }

    /// 書き出したファイルの置き場所（一時フォルダ）。共有が終われば消えてよい
    static func outputURL(title: String, format: ExportOptions.Format) -> URL {
        let ext = format == .pdf ? "pdf" : "png"
        return FileManager.default.temporaryDirectory.appending(path: "\(safeFileName(from: title)).\(ext)")
    }

    /// 作品名からファイル名を作る（AMIZ-73）。
    /// 使えない文字を `-` に置き換え、先頭の `.`（隠しファイル）を避け、長すぎる名前を切り詰める
    static func safeFileName(from title: String) -> String {
        let forbidden = CharacterSet(charactersIn: "/\\:?%*|\"<>").union(.controlCharacters).union(.newlines)
        var name = title.components(separatedBy: forbidden).joined(separator: "-")
        // 「..」は上の階層を指す書き方なので残さない
        while name.contains("..") { name = name.replacingOccurrences(of: "..", with: "-") }
        // 先頭の点（隠しファイル）と、置き換えでできた先頭の「-」や空白を落とす
        name = name.trimmingCharacters(in: CharacterSet(charactersIn: ".-").union(.whitespaces))
        if name.count > 60 { name = String(name.prefix(60)) }
        return name.isEmpty ? "編み図" : name
    }

    /// 設定に応じて PDF か PNG を書き出し、ファイルの URL を返す
    static func export(_ document: ExportDocument) throws -> URL {
        let url = outputURL(title: document.title, format: document.options.format)
        switch document.options.format {
        case .pdf:
            try writePDF(document, to: url)
        case .image:
            try writePNG(document, to: url)
        }
        return url
    }

    /// A4 の PDF を1ページずつ描く
    static func writePDF(_ document: ExportDocument, to url: URL) throws {
        let pages = document.pages
        var mediaBox = CGRect(origin: .zero, size: ExportDocument.pageSize)
        try? FileManager.default.removeItem(at: url)
        guard let context = CGContext(url as CFURL, mediaBox: &mediaBox, nil) else {
            throw Failure.cannotCreatePDF
        }

        for (index, page) in pages.enumerated() {
            let view = ExportPageView(document: document, page: page, pageNumber: index + 1, pageCount: pages.count)
            let renderer = ImageRenderer(content: view)
            renderer.proposedSize = ProposedViewSize(ExportDocument.pageSize)
            renderer.render { _, render in
                context.beginPDFPage(nil)
                // 上下の反転（SwiftUI は左上原点、PDF は左下原点）は render が面倒を見る
                render(context)
                context.endPDFPage()
            }
        }
        context.closePDF()

        guard FileManager.default.fileExists(atPath: url.path) else { throw Failure.cannotWriteFile }
    }

    /// 全ページを縦に並べた1枚の PNG
    static func writePNG(_ document: ExportDocument, to url: URL) throws {
        let pages = document.pages
        let content = VStack(spacing: 0) {
            ForEach(Array(pages.enumerated()), id: \.element.id) { index, page in
                ExportPageView(document: document, page: page, pageNumber: index + 1, pageCount: pages.count)
            }
        }
        let renderer = ImageRenderer(content: content)
        renderer.scale = 2
        guard let image = renderer.uiImage, let data = image.pngData() else {
            throw Failure.cannotRenderImage
        }
        do {
            try data.write(to: url, options: .atomic)
        } catch {
            throw Failure.cannotWriteFile
        }
    }

    /// PDF のページ数（テストと確認用）
    static func pdfPageCount(at url: URL) -> Int {
        guard let pdf = CGPDFDocument(url as CFURL) else { return 0 }
        return pdf.numberOfPages
    }
}
