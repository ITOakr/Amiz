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
        var armLength: CGFloat { unit * 0.27 }
        /// 鎖の楕円の大きさ
        var chainSize: CGSize { CGSize(width: unit * 0.7, height: unit * 0.42) }
        /// 引き抜きの楕円の大きさ
        var slipSize: CGSize { CGSize(width: unit * 0.45, height: unit * 0.26) }
        /// 束に編み入れた目の根元を編み入れ先から離す距離
        var chainSpaceGap: CGFloat { unit * 0.34 }
    }

    /// 細編みの×をどこに置くか（domain-spec 11 の描き分け）
    enum CrossPlacement {
        /// 普通の目：根元と頭の中間に×だけ
        case middle
        /// n目編み入れる：×を頭側に置き、共有する根元から脚を伸ばす（V字）
        case nearHead
        /// n目一度：×を根元側に置き、共有する頭へ脚を集める（逆V字）
        case nearRoot
    }

    /// 線で描く部分の Path
    static func strokePath(
        kind: StitchKind, from root: CGPoint, to head: CGPoint, style: Style, cross: CrossPlacement = .middle
    ) -> Path {
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
            // ×：線分に対して45度の腕。置き場所は増し目・減らし目で変える
            let c: CGPoint
            switch cross {
            case .middle:
                c = midpoint(root, head)
            case .nearHead:
                c = head - d * a
                // 根元から×の下端まで脚
                path.move(to: root)
                path.addLine(to: c - d * a)
            case .nearRoot:
                c = root + d * a
                // ×の上端から頭まで脚
                path.move(to: c + d * a)
                path.addLine(to: head)
            }
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

        case .picot(let chains):
            // 直前の目の頭（根元）の外側に、鎖 n 目の小さな輪
            let anchor = stitch.bases.first ?? stitch.head
            context.stroke(picotPath(chains: chains, from: anchor, to: stitch.head, style: style), with: .color(color), lineWidth: style.lineWidth)

        case .regular where stitch.clusterCount > 1:
            // 玉編み：根元1点から n 本の脚が上の短い横棒に向かって開く（JIS）。束なら根元を離す
            var root = stitch.bases.first ?? virtualRoot(for: stitch, style: style)
            if stitch.into == .chainSpace {
                root = detached(root, toward: stitch.head, by: style.chainSpaceGap)
            }
            context.stroke(clusterPath(kind: stitch.kind, count: stitch.clusterCount, from: root, to: stitch.head, style: style), with: .color(color), lineWidth: style.lineWidth)

        case .regular:
            // 根元ごとに1本描く。n目一度は根元が複数あり、頭で集まる。
            // 束に編み入れた目は、根元を編み入れ先（アーチの中央）から少し離す（domain-spec 11）
            var roots = stitch.bases.isEmpty ? [virtualRoot(for: stitch, style: style)] : stitch.bases
            if stitch.into == .chainSpace {
                roots = roots.map { detached($0, toward: stitch.head, by: style.chainSpaceGap) }
            }
            let cross: CrossPlacement = if stitch.bases.count > 1 {
                .nearRoot
            } else if stitch.sharedBaseCount > 1 {
                .nearHead
            } else {
                .middle
            }
            for root in roots {
                let stroke = strokePath(kind: stitch.kind, from: root, to: stitch.head, style: style, cross: cross)
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
    /// 玉編み：根元1点から count 本の脚を、頭の短い横棒の上に等間隔に開いて描く。脚には目の種類の横棒が付く
    static func clusterPath(kind: StitchKind, count: Int, from root: CGPoint, to head: CGPoint, style: Style) -> Path {
        var path = Path()
        let (d, n) = axes(from: root, to: head)
        let spread = style.unit * 0.24
        let half = CGFloat(count - 1) / 2
        var headPoints: [CGPoint] = []
        for index in 0..<count {
            let offset = (CGFloat(index) - half) * spread
            let top = head + n * offset
            headPoints.append(top)
            // 脚：横棒付きの縦線（中長は T、長は斜め1本、長々は2本）。頭の横棒は下でまとめて描く
            path.addPath(legPath(kind: kind, from: root, to: top, style: style))
        }
        // 頭の横棒（脚の頭をつなぐ）
        let bar = style.armLength * 0.6
        if let first = headPoints.first, let last = headPoints.last {
            path.move(to: first - n * bar)
            path.addLine(to: last + n * bar)
        }
        _ = d
        return path
    }

    /// 脚1本（縦線と、目の種類に応じた斜めの横棒。頭の横棒は付けない）
    private static func legPath(kind: StitchKind, from root: CGPoint, to head: CGPoint, style: Style) -> Path {
        var path = Path()
        let (d, n) = axes(from: root, to: head)
        path.move(to: root)
        path.addLine(to: head)
        let ticks: Int = switch kind {
        case .doubleCrochet: 1
        case .trebleCrochet: 2
        default: 0
        }
        let length = distance(root, head)
        let tick = style.armLength * 0.7
        for index in 0..<ticks {
            let center = root + d * (length * (0.45 + CGFloat(index) * 0.18))
            path.move(to: center - n * tick + d * (tick * 0.5))
            path.addLine(to: center + n * tick - d * (tick * 0.5))
        }
        return path
    }

    /// ピコット：根元（直前の目の頭）から先端へ向かう小さな輪。鎖 n 目ぶんの楕円を輪の上に並べる
    static func picotPath(chains: Int, from anchor: CGPoint, to tip: CGPoint, style: Style) -> Path {
        var path = Path()
        let (d, _) = axes(from: anchor, to: tip)
        let radius = style.unit * 0.2
        let center = tip - d * radius
        // 根元から輪の下端まで短い線
        path.move(to: anchor)
        path.addLine(to: center + d * (-radius))
        // 輪の上に楕円を等間隔に（根元側を空けて）
        let baseAngle = atan2(-d.y, -d.x)  // 根元の方向
        for index in 0..<max(chains, 2) {
            let angle = baseAngle + (CGFloat(index) + 1) * (2 * .pi / CGFloat(chains + 1))
            let ovalCenter = CGPoint(x: center.x + cos(angle) * radius, y: center.y + sin(angle) * radius)
            var oval = Path()
            oval.addEllipse(in: ellipseRect(center: ovalCenter, size: CGSize(width: style.chainSize.width * 0.55, height: style.chainSize.height * 0.55)))
            let tangent = CGPoint(x: -sin(angle), y: cos(angle))
            path.addPath(rotated(oval, around: ovalCenter, direction: tangent))
        }
        return path
    }

    /// 根元を頭の方へ `gap` だけ離した点（束に編み入れた目の根元）
    private static func detached(_ root: CGPoint, toward head: CGPoint, by gap: CGFloat) -> CGPoint {
        let d = distance(root, head)
        guard d > gap * 2 else { return root }
        return root + (head - root) * (gap / d)
    }

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
    var color: Color = AppTheme.ink

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
                // 細編み2目編み入れる（根元を共有、×は頭側）
                for dx in [-10.0, 10.0] {
                    context.stroke(StitchSymbol.strokePath(kind: .singleCrochet, from: CGPoint(x: x, y: baseline), to: CGPoint(x: x + dx, y: top), style: style, cross: .nearHead), with: .color(.primary), lineWidth: style.lineWidth)
                }
                x += 60
                // 細編み2目一度（頭で集まる、×は根元側）
                for dx in [-10.0, 10.0] {
                    context.stroke(StitchSymbol.strokePath(kind: .singleCrochet, from: CGPoint(x: x + dx, y: baseline), to: CGPoint(x: x, y: top), style: style, cross: .nearRoot), with: .color(.primary), lineWidth: style.lineWidth)
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
            Text("玉編みとピコット").font(.headline)
            Canvas { context, size in
                let style = StitchSymbol.Style(unit: 28, lineWidth: 1.8)
                let baseline = size.height * 0.85
                var x: CGFloat = 30
                // 中長編み3目の玉編み
                context.stroke(StitchSymbol.clusterPath(kind: .halfDoubleCrochet, count: 3, from: CGPoint(x: x, y: baseline), to: CGPoint(x: x, y: baseline - style.unit * 2), style: style), with: .color(.primary), lineWidth: style.lineWidth)
                x += 60
                // 長編み3目の玉編み
                context.stroke(StitchSymbol.clusterPath(kind: .doubleCrochet, count: 3, from: CGPoint(x: x, y: baseline), to: CGPoint(x: x, y: baseline - style.unit * 3), style: style), with: .color(.primary), lineWidth: style.lineWidth)
                x += 60
                // 長編み5目の玉編み
                context.stroke(StitchSymbol.clusterPath(kind: .doubleCrochet, count: 5, from: CGPoint(x: x, y: baseline), to: CGPoint(x: x, y: baseline - style.unit * 3), style: style), with: .color(.primary), lineWidth: style.lineWidth)
                x += 70
                // 長々編み2目の玉編み
                context.stroke(StitchSymbol.clusterPath(kind: .trebleCrochet, count: 2, from: CGPoint(x: x, y: baseline), to: CGPoint(x: x, y: baseline - style.unit * 4), style: style), with: .color(.primary), lineWidth: style.lineWidth)
                x += 60
                // 細編みの上にピコット（鎖3目）
                let scTop = CGPoint(x: x, y: baseline - style.unit)
                context.stroke(StitchSymbol.strokePath(kind: .singleCrochet, from: CGPoint(x: x, y: baseline), to: scTop, style: style), with: .color(.primary), lineWidth: style.lineWidth)
                context.stroke(StitchSymbol.picotPath(chains: 3, from: scTop, to: CGPoint(x: x, y: scTop.y - style.unit * 0.55), style: style), with: .color(.primary), lineWidth: style.lineWidth)
                x += 50
                // 鎖5目のピコット
                let scTop2 = CGPoint(x: x, y: baseline - style.unit)
                context.stroke(StitchSymbol.strokePath(kind: .singleCrochet, from: CGPoint(x: x, y: baseline), to: scTop2, style: style), with: .color(.primary), lineWidth: style.lineWidth)
                context.stroke(StitchSymbol.picotPath(chains: 5, from: scTop2, to: CGPoint(x: x, y: scTop2.y - style.unit * 0.55), style: style), with: .color(.primary), lineWidth: style.lineWidth)
            }
            .frame(height: 150)
        }
        .padding()
    }
}

#Preview {
    StitchSymbolCatalogView()
}
