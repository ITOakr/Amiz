import SwiftUI
import ImageIO
import UniformTypeIdentifiers
import CrochetCore

/// 作品カードのサムネイル（ui-spec 3）。図を小さく描いた PNG を作る／PNG から表示用の画像に戻す。
/// 保存時に作って `Work.thumbnail` に入れる（tech-spec 6）。UIKit は使わず ImageIO で PNG にする
@MainActor
enum ThumbnailRenderer {
    /// サムネイルの一辺（pt）。表示は 2 倍で描く
    static let side: CGFloat = 160
    /// これ以上の目があれば間引いて描く（小さい画像なので形は分かる。AMIZ-70）
    static let thinningThreshold = 1200

    /// 目の数に応じた間引きの間隔（1 なら全部描く）
    static func stride(forStitchCount count: Int) -> Int {
        count <= thinningThreshold ? 1 : Int((Double(count) / Double(thinningThreshold)).rounded(.up))
    }

    /// 編み図からサムネイルの PNG を作る。目がなければ nil
    static func png(for pattern: Pattern) -> Data? {
        let layout = pattern.chartLayout()
        guard !layout.stitches.isEmpty || !layout.foundationChain.isEmpty else { return nil }
        let renderer = ImageRenderer(content: ThumbnailView(
            pattern: pattern, layout: layout, stitchStride: stride(forStitchCount: layout.stitches.count)
        ))
        renderer.scale = 2
        guard let image = renderer.cgImage else { return nil }
        let data = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(data, UTType.png.identifier as CFString, 1, nil) else { return nil }
        CGImageDestinationAddImage(destination, image, nil)
        guard CGImageDestinationFinalize(destination) else { return nil }
        return data as Data
    }

    /// PNG から表示用の画像にする
    nonisolated static func image(from data: Data) -> Image? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let cgImage = CGImageSourceCreateImageAtIndex(source, 0, nil) else { return nil }
        return Image(decorative: cgImage, scale: 2)
    }
}

/// サムネイルの中身：白地に図だけ（ハイライトなし、段番号なし、糸の色付き）
private struct ThumbnailView: View {
    let pattern: Pattern
    let layout: ChartLayout
    let stitchStride: Int

    var body: some View {
        Canvas { context, size in
            let transform = ChartTransform.fitting(layout, in: size, inset: 10)
            var painter = ChartPainter(layout: layout, transform: transform)
            painter.showsRowNumbers = false
            painter.pattern = pattern
            painter.stitchStride = stitchStride
            painter.showsGuides = false
            painter.draw(in: &context)
        }
        .frame(width: ThumbnailRenderer.side, height: ThumbnailRenderer.side)
        .background(Color.white)
        .environment(\.colorScheme, .light)
    }
}
