import SwiftUI
import CrochetCore

/// JIS の編目記号を Path（線）で描く（domain-spec 10）。画像素材は使わない。
///
/// 記号は「根元 → 頭」の線分に沿って描く。レイアウト結果（`LaidOutStitch`）の根元と頭をそのまま渡せば、
/// 同じ根元を持つ目は根元で集まり（n目編み入れる）、同じ頭を持つ目は頭で集まる（n目一度）。
/// 座標はすべて画面座標（pt）。
enum StitchSymbol {
    /// 記号の大きさと線の太さ
    struct Style: Hashable {
        /// 「鎖1目分」の長さ（pt）
        var unit: CGFloat = 14
        var lineWidth: CGFloat = 1.6

        /// 記号の横幅（×の腕の長さや T の横棒）
        var armLength: CGFloat { unit * 0.32 }
        /// 鎖の楕円の大きさ
        var chainSize: CGSize { CGSize(width: unit * 0.8, height: unit * 0.45) }
        /// 引き抜きの楕円の大きさ
        var slipSize: CGSize { CGSize(width: unit * 0.5, height: unit * 0.3) }
    }

    /// 線で描く部分の Path
    static func strokePath(kind: StitchKind, from root: CGPoint, to head: CGPoint, style: Style) -> Path {
        var path = Path()
        let (d, n) = axes(from: root, to: head)
        let a = style.armLength

        switch kind {
        case .chain:
            path.addEllipse(in: ellipseRect(center: head, size: style.chainSize))
            return rotated(path, around: head, direction: d)

        case .slipStitch:
            return Path()  // 塗りだけ

        case .singleCrochet:
            // ×：根元と頭の中間に、線分に対して45度の腕
            let c = midpoint(root, head)
            path.move(to: c + (d + n) * -a)
            path.addLine(to: c + (d + n) * a)
            path.move(to: c + (d - n) * -a)
            path.addLine(to: c + (d - n) * a)

        case .halfDoubleCrochet, .doubleCrochet, .trebleCrochet:
            // T：根元から頭への縦線と、頭の横棒
            path.move(to: root)
            path.addLine(to: head)
            path.move(to: head + n * -a)
            path.addLine(to: head + n * a)

            // 長編みは斜めの横棒1本、長々編みは2本（縦線の途中に）
            let bars: [CGFloat] = switch kind {
            case .doubleCrochet: [0.5]
            case .trebleCrochet: [0.4, 0.6]
            default: []
            }
            for t in bars {
                let c = root + (head - root) * t
                path.move(to: c + n * -a * 0.8 + d * -a * 0.35)
                path.addLine(to: c + n * a * 0.8 + d * a * 0.35)
            }
        }
        return path
    }

    /// 塗りで描く部分の Path（引き抜き編み）
    static func fillPath(kind: StitchKind, from root: CGPoint, to head: CGPoint, style: Style) -> Path {
        guard kind == .slipStitch else { return Path() }
        let (d, _) = axes(from: root, to: head)
        var path = Path()
        path.addEllipse(in: ellipseRect(center: head, size: style.slipSize))
        return rotated(path, around: head, direction: d)
    }

    /// 立ち上がり：鎖を根元から頭へ縦に並べる
    static func turningChainPath(chains: Int, from root: CGPoint, to head: CGPoint, style: Style) -> Path {
        var path = Path()
        let (d, _) = axes(from: root, to: head)
        let total = distance(root, head)
        let each = total / CGFloat(max(chains, 1))
        for index in 0..<max(chains, 1) {
            let center = root + d * (each * (CGFloat(index) + 0.5))
            var oval = Path()
            oval.addEllipse(in: ellipseRect(center: center, size: CGSize(width: min(each * 0.85, style.chainSize.width), height: style.chainSize.height * 0.8)))
            path.addPath(rotated(oval, around: center, direction: d))
        }
        return path
    }

    /// レイアウト結果の1目を描く
    static func draw(_ stitch: LaidOutStitch, in context: inout GraphicsContext, color: Color, style: Style) {
        switch stitch.role {
        case .turningChain(let chains):
            let root = stitch.bases.first ?? stitch.head
            let path = turningChainPath(chains: chains, from: root, to: stitch.head, style: style)
            context.stroke(path, with: .color(color), lineWidth: style.lineWidth)

        case .closingSlipStitch:
            let root = virtualRoot(for: stitch, style: style)
            context.fill(fillPath(kind: .slipStitch, from: root, to: stitch.head, style: style), with: .color(color))

        case .regular:
            // 根元ごとに1本描く。n目一度は根元が複数あり、頭で集まる
            let roots = stitch.bases.isEmpty ? [virtualRoot(for: stitch, style: style)] : stitch.bases
            for root in roots {
                let stroke = strokePath(kind: stitch.kind, from: root, to: stitch.head, style: style)
                if !stroke.isEmpty {
                    context.stroke(stroke, with: .color(color), lineWidth: style.lineWidth)
                }
                let fill = fillPath(kind: stitch.kind, from: root, to: stitch.head, style: style)
                if !fill.isEmpty {
                    context.fill(fill, with: .color(color))
                }
            }
        }
    }

    // MARK: - 補助

    /// 根元がない目（鎖など）のために、向きから仮の根元を作る
    private static func virtualRoot(for stitch: LaidOutStitch, style: Style) -> CGPoint {
        let length = CGFloat(stitch.height) * style.unit
        let direction = CGPoint(x: cos(stitch.angle), y: sin(stitch.angle))
        return stitch.head - direction * length
    }

    /// 線分の方向ベクトル d と、それに直交するベクトル n（どちらも長さ1）
    private static func axes(from root: CGPoint, to head: CGPoint) -> (CGPoint, CGPoint) {
        let dx = head.x - root.x
        let dy = head.y - root.y
        let length = max((dx * dx + dy * dy).squareRoot(), 0.0001)
        let d = CGPoint(x: dx / length, y: dy / length)
        return (d, CGPoint(x: -d.y, y: d.x))
    }

    private static func midpoint(_ a: CGPoint, _ b: CGPoint) -> CGPoint {
        CGPoint(x: (a.x + b.x) / 2, y: (a.y + b.y) / 2)
    }

    private static func distance(_ a: CGPoint, _ b: CGPoint) -> CGFloat {
        ((a.x - b.x) * (a.x - b.x) + (a.y - b.y) * (a.y - b.y)).squareRoot()
    }

    private static func ellipseRect(center: CGPoint, size: CGSize) -> CGRect {
        CGRect(x: center.x - size.width / 2, y: center.y - size.height / 2, width: size.width, height: size.height)
    }

    /// 横長に作った Path を、方向 d に向くように中心の周りで回す
    private static func rotated(_ path: Path, around center: CGPoint, direction d: CGPoint) -> Path {
        let angle = atan2(d.y, d.x)
        let transform = CGAffineTransform(translationX: center.x, y: center.y)
            .rotated(by: angle)
            .translatedBy(x: -center.x, y: -center.y)
        return path.applying(transform)
    }
}

// CGPoint の簡単な計算
private func + (lhs: CGPoint, rhs: CGPoint) -> CGPoint { CGPoint(x: lhs.x + rhs.x, y: lhs.y + rhs.y) }
private func - (lhs: CGPoint, rhs: CGPoint) -> CGPoint { CGPoint(x: lhs.x - rhs.x, y: lhs.y - rhs.y) }
private func * (lhs: CGPoint, rhs: CGFloat) -> CGPoint { CGPoint(x: lhs.x * rhs, y: lhs.y * rhs) }

/// 記号1つを上向きに描く小さな View（キーボードのボタン、凡例）
struct StitchSymbolView: View {
    let kind: StitchKind
    var size: CGFloat = 28
    var color: Color = .primary

    var body: some View {
        Canvas { context, canvasSize in
            let style = StitchSymbol.Style(unit: canvasSize.height * 0.7, lineWidth: 1.8)
            let centerX = canvasSize.width / 2
            // 高さのある目は下から上へ。高さのない目（鎖・引き抜き）は中央に置く
            let (root, head) = kind.heightInChains == 0
                ? (CGPoint(x: centerX, y: canvasSize.height / 2 + 1), CGPoint(x: centerX, y: canvasSize.height / 2))
                : (CGPoint(x: centerX, y: canvasSize.height * 0.9), CGPoint(x: centerX, y: canvasSize.height * 0.15))
            var stroke = StitchSymbol.strokePath(kind: kind, from: root, to: head, style: style)
            if kind == .chain {
                // 鎖は進む方向に沿って置かれるので、横向きに見せる
                stroke = stroke.applying(rotation(around: head))
            }
            context.stroke(stroke, with: .color(color), lineWidth: style.lineWidth)
            context.fill(StitchSymbol.fillPath(kind: kind, from: root, to: head, style: style), with: .color(color))
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }

    private func rotation(around center: CGPoint) -> CGAffineTransform {
        CGAffineTransform(translationX: center.x, y: center.y)
            .rotated(by: .pi / 2)
            .translatedBy(x: -center.x, y: -center.y)
    }
}

/// すべての記号を並べたプレビュー（フェーズ3-2 の確認用）
struct StitchSymbolCatalogView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("記号一覧").font(.headline)
            HStack(spacing: 16) {
                ForEach(StitchKind.allCases, id: \.self) { kind in
                    VStack {
                        StitchSymbolView(kind: kind, size: 40)
                        Text(kind.japaneseName).font(.caption2)
                    }
                }
            }
            Text("組み合わせ").font(.headline)
            Canvas { context, size in
                let style = StitchSymbol.Style(unit: 28, lineWidth: 1.8)
                let baseline = size.height * 0.85
                let top = baseline - style.unit
                var x: CGFloat = 30
                // 細編み2目編み入れる（根元を共有）
                for dx in [-10.0, 10.0] {
                    context.stroke(StitchSymbol.strokePath(kind: .singleCrochet, from: CGPoint(x: x, y: baseline), to: CGPoint(x: x + dx, y: top), style: style), with: .color(.primary), lineWidth: style.lineWidth)
                }
                x += 60
                // 細編み2目一度（頭で集まる）
                for dx in [-10.0, 10.0] {
                    context.stroke(StitchSymbol.strokePath(kind: .singleCrochet, from: CGPoint(x: x + dx, y: baseline), to: CGPoint(x: x, y: top), style: style), with: .color(.primary), lineWidth: style.lineWidth)
                }
                x += 60
                // 長編み3目編み入れる
                let dcTop = baseline - style.unit * 3
                for dx in [-16.0, 0.0, 16.0] {
                    context.stroke(StitchSymbol.strokePath(kind: .doubleCrochet, from: CGPoint(x: x, y: baseline), to: CGPoint(x: x + dx, y: dcTop), style: style), with: .color(.primary), lineWidth: style.lineWidth)
                }
                x += 70
                // 立ち上がり鎖3目
                context.stroke(StitchSymbol.turningChainPath(chains: 3, from: CGPoint(x: x, y: baseline), to: CGPoint(x: x, y: dcTop), style: style), with: .color(.primary), lineWidth: style.lineWidth)
                x += 50
                // 長々編み2目一度
                let trTop = baseline - style.unit * 4
                for dx in [-14.0, 14.0] {
                    context.stroke(StitchSymbol.strokePath(kind: .trebleCrochet, from: CGPoint(x: x + dx, y: baseline), to: CGPoint(x: x, y: trTop), style: style), with: .color(.primary), lineWidth: style.lineWidth)
                }
            }
            .frame(height: 150)
        }
        .padding()
    }
}

#Preview {
    StitchSymbolCatalogView()
}
