import CoreGraphics
import Foundation

/// 円形図（輪編み・螺旋編み）の座標計算（tech-spec 8-1、domain-spec 12）。
///
/// 考え方：
/// - 段ごとの半径は、作り目からの段の高さ（鎖○目分）の累計
/// - 数える目の「頭」を段の円周に等間隔に並べ、「根元」は拾った前段の目の頭の角度に置く。
///   これで増し目は根元を共有して頭が広がり（V字）、減らし目は根元が複数で頭が1つ（逆V字）になる
/// - 頭の並び全体の回転量は、頭と根元のずれの平均が 0 になるように決める（V字が左右対称になる）
/// - 角度は3時の位置が 0 で、画面上で反時計回りに進む
public enum CircularLayout {
    public struct Options: Hashable, Sendable {
        /// わの作り目の穴の半径
        public var ringRadius = 0.8
        /// 段の高さの下限（鎖○目分）
        public var minRowHeight = 1.0
        /// 高さのない目（鎖・引き抜き）を描くときの長さ
        public var lowStitchHeight = 0.5
        /// 外接矩形の余白
        public var margin = 1.5

        public init() {}
    }

    /// 編み図全体のレイアウトを計算する
    public static func layout(_ pattern: Pattern, expansion: PatternExpansion, options: Options = Options()) -> ChartLayout {
        let center = CGPoint.zero
        var stitches: [LaidOutStitch] = []
        var rings: [RowRing] = []
        var innerRadius = options.ringRadius
        /// 前段の「数える目」の頭の角度（数える目の順）
        var previousHeadAngles: [Double] = []

        for (rowIndex, row) in expansion.rows.enumerated() {
            let rowHeight = max(options.minRowHeight, row.stitches.map { drawHeight(of: $0, options: options) }.max() ?? 0)
            let outerRadius = innerRadius + rowHeight
            let counted = row.stitches.enumerated().filter { $0.element.isCounted }
            let countedCount = counted.count

            // 数える目ごとの根元の角度（拾った前段の目の頭の角度。鎖などは nil）
            let baseAngles: [[Double]] = counted.map { _, stitch in
                guard rowIndex > 0, !stitch.picks.isEmpty else { return [] }
                return stitch.picks.map { previousAngle(at: $0, in: previousHeadAngles) }
            }

            // 頭の並びの回転量
            let step = countedCount > 0 ? (2 * Double.pi) / Double(countedCount) : 0
            let rotation = headRotation(baseAngles: baseAngles, step: step, fallback: previousHeadAngles.first ?? 0)

            var headAngles: [Double] = []
            var countedIndexByStitchIndex: [Int: Int] = [:]
            for (countedIndex, item) in counted.enumerated() {
                countedIndexByStitchIndex[item.offset] = countedIndex
                headAngles.append(rotation + step * Double(countedIndex))
            }

            for (stitchIndex, stitch) in row.stitches.enumerated() {
                let laidOut: LaidOutStitch
                if let countedIndex = countedIndexByStitchIndex[stitchIndex] {
                    let headAngle = headAngles[countedIndex]
                    let bases: [CGPoint]
                    if rowIndex == 0 {
                        // わの作り目：根元は輪の上、頭と同じ角度
                        bases = [point(center: center, radius: innerRadius, angle: headAngle)]
                    } else {
                        bases = baseAngles[countedIndex].map { point(center: center, radius: innerRadius, angle: $0) }
                    }
                    laidOut = make(
                        stitch, rowIndex: rowIndex, countedIndex: countedIndex,
                        headAngle: headAngle, outerRadius: outerRadius, bases: bases,
                        center: center, options: options
                    )
                } else {
                    // 数えない目：立ち上がり（鎖1目）は段の始めの半歩手前、段を閉じる引き抜きは終わりの半歩後ろ
                    let angle: Double
                    switch stitch.role {
                    case .turningChain:
                        angle = (headAngles.first ?? rotation) - step / 2
                    case .closingSlipStitch:
                        angle = (headAngles.last ?? rotation) + step / 2
                    case .regular:
                        angle = headAngles.last ?? rotation
                    }
                    laidOut = make(
                        stitch, rowIndex: rowIndex, countedIndex: nil,
                        headAngle: angle, outerRadius: outerRadius,
                        bases: stitch.role == .closingSlipStitch ? [] : [point(center: center, radius: innerRadius, angle: angle)],
                        center: center, options: options
                    )
                }
                stitches.append(laidOut)
            }

            rings.append(RowRing(rowIndex: rowIndex, innerRadius: innerRadius, outerRadius: outerRadius, startAngle: headAngles.first ?? rotation))
            previousHeadAngles = headAngles
            innerRadius = outerRadius
        }

        let radius = innerRadius + options.margin
        let bounds = CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2)
        return ChartLayout(stitches: stitches, rings: rings, center: center, bounds: bounds)
    }

    // MARK: - 補助

    /// 1目分の `LaidOutStitch` を作る
    private static func make(
        _ stitch: ExpandedStitch, rowIndex: Int, countedIndex: Int?,
        headAngle: Double, outerRadius: Double, bases: [CGPoint],
        center: CGPoint, options: Options
    ) -> LaidOutStitch {
        let head = point(center: center, radius: outerRadius, angle: headAngle)
        let direction: Double
        if bases.isEmpty {
            // 根元がない目（鎖）は進む方向（接線）を向く。引き抜きも同じ
            direction = tangentDirection(at: headAngle)
        } else {
            let meanBase = CGPoint(
                x: bases.map(\.x).reduce(0, +) / Double(bases.count),
                y: bases.map(\.y).reduce(0, +) / Double(bases.count)
            )
            direction = atan2(head.y - meanBase.y, head.x - meanBase.x)
        }
        return LaidOutStitch(
            ref: stitch.ref, kind: stitch.kind, role: stitch.role, into: stitch.into, isCounted: stitch.isCounted,
            rowIndex: rowIndex, countedIndex: countedIndex, head: head, bases: bases,
            angle: direction, height: drawHeight(of: stitch, options: options),
            polarAngle: headAngle, polarRadius: outerRadius
        )
    }

    /// 描くときの長さ（鎖○目分）。立ち上がりは鎖の目数、高さのない目は最小の長さ
    static func drawHeight(of stitch: ExpandedStitch, options: Options) -> Double {
        switch stitch.role {
        case .turningChain(let chains):
            Double(chains)
        case .closingSlipStitch:
            options.lowStitchHeight
        case .regular:
            stitch.kind.heightInChains == 0 ? options.lowStitchHeight : Double(stitch.kind.heightInChains)
        }
    }

    /// 前段の目の頭の角度。拾いすぎで前段の範囲を超えたら、同じ間隔で回り続けたとみなす
    private static func previousAngle(at index: Int, in headAngles: [Double]) -> Double {
        guard !headAngles.isEmpty else { return 0 }
        if index < headAngles.count { return headAngles[index] }
        let step = (2 * Double.pi) / Double(headAngles.count)
        return headAngles[0] + step * Double(index)
    }

    /// 頭の並びの回転量：根元との角度差の平均が 0 になる回転。根元のある目がなければ fallback
    private static func headRotation(baseAngles: [[Double]], step: Double, fallback: Double) -> Double {
        var offsets: [Double] = []
        for (index, bases) in baseAngles.enumerated() where !bases.isEmpty {
            let base = circularMean(bases)
            offsets.append(base - step * Double(index))
        }
        guard !offsets.isEmpty else { return fallback }
        return circularMean(offsets)
    }

    /// 角度の平均（円周上で正しく平均する）
    static func circularMean(_ angles: [Double]) -> Double {
        let x = angles.map { cos($0) }.reduce(0, +)
        let y = angles.map { sin($0) }.reduce(0, +)
        return atan2(y, x)
    }

    /// 極座標から画面座標へ（3時が 0、画面上で反時計回りが正 → y は上向きに減る）
    static func point(center: CGPoint, radius: Double, angle: Double) -> CGPoint {
        CGPoint(x: center.x + radius * cos(angle), y: center.y - radius * sin(angle))
    }

    /// 円周上で反時計回りに進む方向（画面座標のラジアン）
    static func tangentDirection(at angle: Double) -> Double {
        atan2(-cos(angle), -sin(angle))
    }
}

extension Pattern {
    /// 円形図のレイアウトを計算する（`CircularLayout.layout` の省略形）
    public func circularLayout(expansion: PatternExpansion? = nil) -> ChartLayout {
        CircularLayout.layout(self, expansion: expansion ?? expanded())
    }
}
