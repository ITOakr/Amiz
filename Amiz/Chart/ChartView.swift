import SwiftUI
import CrochetCore

/// 記号図（ui-spec 5-3 の A）。レイアウト結果を Canvas で一度に描く（tech-spec 7）。
///
/// 座標の変換：レイアウトは「鎖1目分＝1.0」の単位で持っているので、
/// 画面に収まる倍率（pt/単位）を求め、ズームとドラッグをその倍率と中心のずらしに足し込む。
struct ChartView: View {
    let layout: ChartLayout
    /// 今編んでいる段（完成済みの段と区別して描く）
    var currentRowIndex: Int?
    /// 次に拾う前段の目（ハイライト）
    var highlighted: LaidOutStitch?
    /// 選択中の目（U15）
    var selected: LaidOutStitch?
    var showsRowNumbers = true
    /// 段の境目に区切り線を描く（螺旋編み。立ち上がりも引き抜きもないので境目が分かるように）
    var showsSeamMarks = false
    /// 糸の色で描くための編み図と色替えの位置（domain-spec 30・31）。nil なら単色
    var pattern: Pattern?
    var yarnChanges: [YarnChange] = []
    /// 目をタップしたとき（選択の操作はフェーズ4）
    var onTapStitch: ((LaidOutStitch) -> Void)?
    /// なぞって塗る（色編集モード。ui-spec U21）。指定するとドラッグが移動ではなく塗りになる。
    /// `onPaintStrokeBegan` / `Ended` はなぞりの始まりと終わり
    var onPaint: ((LaidOutStitch) -> Void)?
    var onPaintStrokeBegan: (() -> Void)?
    var onPaintStrokeEnded: (() -> Void)?

    @State private var zoom: CGFloat = 1
    @State private var pan: CGSize = .zero
    @GestureState private var pinching: CGFloat = 1
    @GestureState private var dragging: CGSize = .zero

    var body: some View {
        GeometryReader { geometry in
            let transform = transform(in: geometry.size)
            Canvas { context, _ in
                draw(in: &context, transform: transform)
            }
            .contentShape(Rectangle())
            // ドラッグは通常は移動、色編集モードでは塗り（使わない方は無効にする）。ピンチはどちらでも使える
            .gesture(dragGesture, including: onPaint == nil ? .all : .subviews)
            .gesture(paintGesture(transform), including: onPaint == nil ? .subviews : .all)
            .simultaneousGesture(magnifyGesture)
            .onTapGesture { location in
                let unitPoint = transform.toUnit(location)
                if let stitch = layout.nearestStitch(to: unitPoint, maxDistance: 0.6) {
                    onTapStitch?(stitch)
                }
            }
            .overlay(alignment: .bottomTrailing) {
                fitButton
            }
        }
        .background(Color(.systemBackground))
        .accessibilityIdentifier("chart")
    }

    // MARK: - 描画

    private func draw(in context: inout GraphicsContext, transform: ChartTransform) {
        var painter = ChartPainter(layout: layout, transform: transform)
        painter.currentRowIndex = currentRowIndex
        painter.highlighted = highlighted
        painter.selected = selected
        painter.showsRowNumbers = showsRowNumbers
        painter.showsSeamMarks = showsSeamMarks
        painter.pattern = pattern
        painter.yarnChanges = yarnChanges
        painter.draw(in: &context)
    }

    // MARK: - 変換

    /// 図全体が収まる倍率に、ズームとドラッグを足し込んだ変換
    private func transform(in size: CGSize) -> ChartTransform {
        var transform = ChartTransform.fitting(layout, in: size)
        transform.unit = max(2, transform.unit * zoom * pinching)
        transform.origin = CGPoint(
            x: size.width / 2 + pan.width + dragging.width - layout.center.x * transform.unit,
            y: size.height / 2 + pan.height + dragging.height - layout.center.y * transform.unit
        )
        return transform
    }

    private var dragGesture: some Gesture {
        DragGesture(minimumDistance: 4)
            .updating($dragging) { value, state, _ in state = value.translation }
            .onEnded { value in
                pan.width += value.translation.width
                pan.height += value.translation.height
            }
    }

    /// なぞって塗る：指の下に来た目を順に塗る（同じ目は続けて塗らない）
    private func paintGesture(_ transform: ChartTransform) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                if value.translation == .zero { onPaintStrokeBegan?() }
                let unitPoint = transform.toUnit(value.location)
                if let stitch = layout.nearestStitch(to: unitPoint, maxDistance: 0.6) {
                    onPaint?(stitch)
                }
            }
            .onEnded { _ in onPaintStrokeEnded?() }
    }

    private var magnifyGesture: some Gesture {
        MagnifyGesture()
            .updating($pinching) { value, state, _ in state = value.magnification }
            .onEnded { value in
                zoom = min(8, max(0.5, zoom * value.magnification))
            }
    }

    /// 「全体」：ズームと移動を戻す
    private var fitButton: some View {
        Button("全体") {
            withAnimation {
                zoom = 1
                pan = .zero
            }
        }
        .font(.caption)
        .buttonStyle(.bordered)
        .padding(8)
        .accessibilityIdentifier("chart.fit")
    }
}

/// レイアウトの単位座標と画面座標の変換
struct ChartTransform {
    /// 1単位（鎖1目分）あたりの pt
    var unit: CGFloat
    /// 単位座標の原点が画面のどこに来るか
    var origin: CGPoint

    func toScreen(_ point: CGPoint) -> CGPoint {
        CGPoint(x: origin.x + point.x * unit, y: origin.y + point.y * unit)
    }

    func toUnit(_ point: CGPoint) -> CGPoint {
        CGPoint(x: (point.x - origin.x) / unit, y: (point.y - origin.y) / unit)
    }

    /// 目の座標を画面座標に変えたコピー
    func apply(to stitch: LaidOutStitch) -> LaidOutStitch {
        var scaled = stitch
        scaled.head = toScreen(stitch.head)
        scaled.bases = stitch.bases.map(toScreen)
        return scaled
    }

    /// 図全体が `size` に収まる変換（余白 inset）
    static func fitting(_ layout: ChartLayout, in size: CGSize, inset: CGFloat = 12) -> ChartTransform {
        let fit = min(
            (size.width - inset * 2) / max(layout.bounds.width, 1),
            (size.height - inset * 2) / max(layout.bounds.height, 1)
        )
        let unit = max(2, fit)
        return ChartTransform(
            unit: unit,
            origin: CGPoint(x: size.width / 2 - layout.center.x * unit, y: size.height / 2 - layout.center.y * unit)
        )
    }
}

/// 図の描画（画面の `ChartView` と書き出しで共用）。段の輪、記号、ハイライト、段番号を Canvas に描く
struct ChartPainter {
    let layout: ChartLayout
    let transform: ChartTransform
    /// 今編んでいる段（アクセント色で描く）。書き出しでは nil
    var currentRowIndex: Int?
    /// 次に拾う前段の目（太い赤）。書き出しでは nil
    var highlighted: LaidOutStitch?
    /// 選択中の目（太い橙）。書き出しでは nil
    var selected: LaidOutStitch?
    var showsRowNumbers = true
    /// 段の境目の区切り線（螺旋編み）。段番号の下に薄く描く
    var showsSeamMarks = false
    /// 糸の色で描くための編み図（糸リストを引く）。nil か糸が1本だけなら単色（今編んでいる段はアクセント色）
    var pattern: Pattern?
    /// 色替えの位置（domain-spec 31）。直前の目の頭に新しい色の三角を描く
    var yarnChanges: [YarnChange] = []

    /// 糸の色で描くか（糸が2本以上の作品）
    private var usesYarnColors: Bool {
        (pattern?.yarns.count ?? 0) > 1
    }

    func draw(in context: inout GraphicsContext) {
        let style = StitchSymbol.Style(unit: transform.unit, lineWidth: max(1, min(2, transform.unit * 0.11)))

        // 段の輪の補助線（円形図）
        for ring in layout.rings {
            let radius = ring.outerRadius * transform.unit
            let rect = CGRect(x: transform.origin.x - radius, y: transform.origin.y - radius, width: radius * 2, height: radius * 2)
            context.stroke(Path(ellipseIn: rect), with: .color(.secondary.opacity(0.15)), lineWidth: 0.5)
        }

        // 段の帯の補助線（平面図）：段の頭側に横線
        if let first = layout.bands.first {
            let minX = layout.bounds.minX + 1
            let maxX = layout.bounds.maxX - 1
            for band in layout.bands + [RowBand(rowIndex: -1, baseY: first.baseY, topY: first.baseY, direction: 0, seamX: 0)] {
                var line = Path()
                line.move(to: transform.toScreen(CGPoint(x: minX, y: band.topY)))
                line.addLine(to: transform.toScreen(CGPoint(x: maxX, y: band.topY)))
                context.stroke(line, with: .color(.secondary.opacity(0.15)), lineWidth: 0.5)
            }
        }

        // 作り目の鎖（平面図）：横たわる鎖の楕円
        for point in layout.foundationChain {
            let head = transform.toScreen(point)
            let root = CGPoint(x: head.x - transform.unit, y: head.y)
            let path = StitchSymbol.strokePath(kind: .chain, from: root, to: head, style: style)
            context.stroke(path, with: .color(.primary), lineWidth: style.lineWidth)
        }

        // 段の境目の区切り線（螺旋編み）：継ぎ目の角度に、段の内側から外側まで
        if showsSeamMarks {
            for ring in layout.rings {
                let angle = ring.seamAngle
                var path = Path()
                path.move(to: transform.toScreen(CGPoint(x: ring.innerRadius * cos(angle), y: -ring.innerRadius * sin(angle))))
                path.addLine(to: transform.toScreen(CGPoint(x: ring.outerRadius * cos(angle), y: -ring.outerRadius * sin(angle))))
                context.stroke(path, with: .color(.secondary.opacity(0.45)), style: StrokeStyle(lineWidth: max(0.5, style.lineWidth * 0.6), dash: [3, 2]))
            }
        }

        // 目。次に拾う前段の目は記号そのものを太い赤で描く（ハイライト）。
        // 糸が2本以上なら記号の線を糸の色で描き（domain-spec 30）、今編んでいる段はアクセント色の縁取りで区別する
        let highlightStyle = StitchSymbol.Style(unit: style.unit, lineWidth: style.lineWidth * 2.2)
        let outlineStyle = StitchSymbol.Style(unit: style.unit, lineWidth: style.lineWidth * 1.7)
        let haloStyle = StitchSymbol.Style(unit: style.unit, lineWidth: style.lineWidth * 3.2)
        for stitch in layout.stitches {
            let scaled = transform.apply(to: stitch)
            if let highlighted, stitch.ref == highlighted.ref {
                StitchSymbol.draw(scaled, in: &context, color: .red, style: highlightStyle)
            } else if let selected, stitch.ref == selected.ref {
                StitchSymbol.draw(scaled, in: &context, color: .orange, style: highlightStyle)
            } else if usesYarnColors, let pattern {
                let isCurrent = stitch.rowIndex == currentRowIndex
                let yarnColor = pattern.yarn(for: stitch.yarnID).color
                if isCurrent {
                    StitchSymbol.draw(scaled, in: &context, color: .accentColor.opacity(0.35), style: haloStyle)
                }
                // 白など明るい色は暗い輪郭を下に敷いて見分ける（domain-spec 30）
                if yarnColor.isLight {
                    StitchSymbol.draw(scaled, in: &context, color: .primary.opacity(0.45), style: outlineStyle)
                }
                StitchSymbol.draw(scaled, in: &context, color: Color(yarnColor), style: style)
            } else {
                let isCurrent = stitch.rowIndex == currentRowIndex
                StitchSymbol.draw(scaled, in: &context, color: isCurrent ? .accentColor : .primary, style: style)
            }
        }

        // 色替えの位置：持ち替える目（直前の目）の頭の先に、新しい糸の色の小さな三角（domain-spec 31）
        if usesYarnColors, let pattern {
            for change in yarnChanges {
                guard let previousRef = change.previousRef, let previous = layout.stitch(for: previousRef) else { continue }
                let color = pattern.yarn(for: change.yarnID).color
                drawChangeMarker(at: transform.apply(to: previous), color: color, in: &context, style: style)
            }
        }

        drawRowNumbers(in: &context, style: style)
    }

    /// 色替えの三角：頭の先（記号の向きに少し進んだ位置）に、頭の方を向いた小さな三角。明るい色は輪郭付き
    private func drawChangeMarker(at stitch: LaidOutStitch, color: YarnColor, in context: inout GraphicsContext, style: StitchSymbol.Style) {
        let size = style.unit * 0.22
        let (dx, dy) = (cos(stitch.angle), sin(stitch.angle))
        let tip = CGPoint(x: stitch.head.x + dx * size * 0.6, y: stitch.head.y + dy * size * 0.6)
        let base = CGPoint(x: tip.x + dx * size * 1.5, y: tip.y + dy * size * 1.5)
        var path = Path()
        path.move(to: tip)
        path.addLine(to: CGPoint(x: base.x - dy * size, y: base.y + dx * size))
        path.addLine(to: CGPoint(x: base.x + dy * size, y: base.y - dx * size))
        path.closeSubpath()
        context.fill(path, with: .color(Color(color)))
        context.stroke(path, with: .color(.primary.opacity(color.isLight ? 0.7 : 0.35)), lineWidth: max(0.5, style.lineWidth * 0.5))
    }

    private func drawRowNumbers(in context: inout GraphicsContext, style: StitchSymbol.Style) {
        // 段番号と方向の矢印（平面図）：立ち上がり側の外に置く（domain-spec 9）
        if showsRowNumbers {
            for band in layout.bands {
                let outward = -band.direction  // 段の始まりの端から外へ向かう向き
                let y = (band.baseY + band.topY) / 2
                let numberPoint = transform.toScreen(CGPoint(x: band.seamX + outward * 1.9, y: y))
                let text = Text("\(band.rowIndex + 1)").font(.system(size: max(7, transform.unit * 0.36), weight: .semibold)).foregroundStyle(.secondary)
                context.draw(context.resolve(text), at: numberPoint)

                // 矢印：段番号と始まりの端の間で、進む方向を指す
                let tail = transform.toScreen(CGPoint(x: band.seamX + outward * 1.5, y: y))
                let tip = transform.toScreen(CGPoint(x: band.seamX + outward * 0.8, y: y))
                var arrow = Path()
                arrow.move(to: tail)
                arrow.addLine(to: tip)
                let headSize = transform.unit * 0.18
                arrow.move(to: CGPoint(x: tip.x - band.direction * headSize, y: tip.y - headSize))
                arrow.addLine(to: tip)
                arrow.addLine(to: CGPoint(x: tip.x - band.direction * headSize, y: tip.y + headSize))
                context.stroke(arrow, with: .color(.secondary), lineWidth: max(0.8, style.lineWidth * 0.7))
            }
        }

        // 段番号（円形図）：段の始まりの空き（立ち上がりの楕円と引き抜きの点の間の高さ）に置く
        if showsRowNumbers {
            for ring in layout.rings {
                let angle = ring.seamAngle
                let radius = ring.innerRadius + 0.62 + max(0, (ring.outerRadius - ring.innerRadius - 1)) / 2
                let point = transform.toScreen(CGPoint(x: radius * cos(angle), y: -radius * sin(angle)))
                let text = Text("\(ring.rowIndex + 1)").font(.system(size: max(7, transform.unit * 0.36), weight: .semibold)).foregroundStyle(.secondary)
                let resolved = context.resolve(text)
                let size = resolved.measure(in: CGSize(width: 100, height: 100))
                let background = CGRect(x: point.x - size.width / 2 - 1, y: point.y - size.height / 2, width: size.width + 2, height: size.height)
                context.fill(Path(roundedRect: background, cornerRadius: 2), with: .color(Color(.systemBackground).opacity(0.8)))
                context.draw(resolved, at: point)
            }
        }
    }
}

#Preview {
    let pattern = SamplePatterns.bearHead
    return ChartView(layout: pattern.chartLayout(), currentRowIndex: 4)
        .frame(height: 400)
}

#Preview("往復編み") {
    let pattern = SamplePatterns.blanketEdge
    return ChartView(layout: pattern.chartLayout(), currentRowIndex: 6)
        .frame(height: 400)
}
