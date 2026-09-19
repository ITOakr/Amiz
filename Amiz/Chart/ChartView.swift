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
    /// 目をタップしたとき（選択の操作はフェーズ4）
    var onTapStitch: ((LaidOutStitch) -> Void)?

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
            .gesture(dragGesture.simultaneously(with: magnifyGesture))
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
        let style = StitchSymbol.Style(unit: transform.unit, lineWidth: max(1, min(2, transform.unit * 0.11)))

        // 段の輪の補助線
        for ring in layout.rings {
            let radius = ring.outerRadius * transform.unit
            let rect = CGRect(x: transform.origin.x - radius, y: transform.origin.y - radius, width: radius * 2, height: radius * 2)
            context.stroke(Path(ellipseIn: rect), with: .color(.secondary.opacity(0.15)), lineWidth: 0.5)
        }

        // 目。次に拾う前段の目は記号そのものを太い赤で描く（ハイライト）
        let highlightStyle = StitchSymbol.Style(unit: style.unit, lineWidth: style.lineWidth * 2.2)
        for stitch in layout.stitches {
            let scaled = transform.apply(to: stitch)
            if let highlighted, stitch.ref == highlighted.ref {
                StitchSymbol.draw(scaled, in: &context, color: .red, style: highlightStyle)
            } else if let selected, stitch.ref == selected.ref {
                StitchSymbol.draw(scaled, in: &context, color: .orange, style: highlightStyle)
            } else {
                let isCurrent = stitch.rowIndex == currentRowIndex
                StitchSymbol.draw(scaled, in: &context, color: isCurrent ? .accentColor : .primary, style: style)
            }
        }

        // 段番号：段の始まりの空き（立ち上がりの楕円と引き抜きの点の間の高さ）に置く
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

    // MARK: - 変換

    /// 図全体が収まる倍率に、ズームとドラッグを足し込んだ変換
    private func transform(in size: CGSize) -> ChartTransform {
        let inset: CGFloat = 12
        let fit = min(
            (size.width - inset * 2) / max(layout.bounds.width, 1),
            (size.height - inset * 2) / max(layout.bounds.height, 1)
        )
        let unit = max(2, fit * zoom * pinching)
        let origin = CGPoint(
            x: size.width / 2 + pan.width + dragging.width - layout.center.x * unit,
            y: size.height / 2 + pan.height + dragging.height - layout.center.y * unit
        )
        return ChartTransform(unit: unit, origin: origin)
    }

    private var dragGesture: some Gesture {
        DragGesture(minimumDistance: 4)
            .updating($dragging) { value, state, _ in state = value.translation }
            .onEnded { value in
                pan.width += value.translation.width
                pan.height += value.translation.height
            }
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
}

#Preview {
    let pattern = SamplePatterns.bearHead
    return ChartView(layout: pattern.circularLayout(), currentRowIndex: 4)
        .frame(height: 400)
}
