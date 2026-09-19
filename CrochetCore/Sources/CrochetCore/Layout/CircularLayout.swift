import CoreGraphics
import Foundation

/// 円形図（輪編み・螺旋編み）の座標計算（tech-spec 8-1、domain-spec 12）。
///
/// 考え方：
/// - 段ごとの半径は、作り目からの段の高さ（鎖○目分）の累計
/// - 目の「頭」は拾った前段の目の頭の真上（同じ角度）に置く。同じ目に複数編み入れた場合（増し目）は、
///   前段の1目分の幅の中で均等に広げる。n目一度は拾った目の角度の中間。鎖編みは前後の目の間に均等に並べる
/// - 「根元」は拾った前段の目の頭の角度に置く
/// - これで、増減なしの段は放射状、増し目は左右対称のV字、減らし目は逆V字になり、
///   拾いすぎや拾い残しはそのまま図のずれとして見える
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

            // 前段の1目分の角度（前段がなければ、この段の目数から）
            let previousStep = previousHeadAngles.isEmpty
                ? (2 * Double.pi) / Double(max(counted.count, 1))
                : (2 * Double.pi) / Double(previousHeadAngles.count)

            // 数える目ごとの根元の角度（拾った前段の目の頭の角度。鎖などは空）
            let baseAngles: [[Double]] = counted.map { _, stitch in
                guard rowIndex > 0, !stitch.picks.isEmpty else { return [] }
                return stitch.picks.map { previousAngle(at: $0, in: previousHeadAngles) }
            }

            let headAngles = headAngles(
                for: counted.map(\.element), baseAngles: baseAngles, rowIndex: rowIndex,
                previousStep: previousStep, isClosed: row.stitches.contains { $0.role == .closingSlipStitch }
            )

            var countedIndexByStitchIndex: [Int: Int] = [:]
            for (countedIndex, item) in counted.enumerated() {
                countedIndexByStitchIndex[item.offset] = countedIndex
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
                        angle = (headAngles.first ?? previousHeadAngles.first ?? 0) - previousStep / 2
                    case .closingSlipStitch:
                        angle = (headAngles.last ?? previousHeadAngles.first ?? 0) + previousStep / 2
                    case .regular:
                        angle = headAngles.last ?? previousHeadAngles.first ?? 0
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

            rings.append(RowRing(
                rowIndex: rowIndex, innerRadius: innerRadius, outerRadius: outerRadius,
                startAngle: headAngles.first ?? previousHeadAngles.first ?? 0
            ))
            previousHeadAngles = headAngles
            innerRadius = outerRadius
        }

        let radius = innerRadius + options.margin
        let bounds = CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2)
        return ChartLayout(stitches: stitches, rings: rings, center: center, bounds: bounds)
    }

    // MARK: - 頭の角度

    /// 数える目の頭の角度を決める
    private static func headAngles(
        for counted: [ExpandedStitch], baseAngles: [[Double]], rowIndex: Int,
        previousStep: Double, isClosed: Bool
    ) -> [Double] {
        let count = counted.count
        guard count > 0 else { return [] }

        // 1段目（わの作り目）：等間隔に1周
        if rowIndex == 0 {
            return (0..<count).map { previousStep * Double($0) }
        }

        var angles = [Double?](repeating: nil, count: count)

        // 根元のある目：同じ編み入れ先を共有する続きの目をまとめ、前段の1目分の幅の中で均等に広げる
        var index = 0
        while index < count {
            guard !baseAngles[index].isEmpty else {
                index += 1
                continue
            }
            var end = index
            while end + 1 < count, counted[end + 1].picks == counted[index].picks, !baseAngles[end + 1].isEmpty {
                end += 1
            }
            let groupSize = end - index + 1
            let base = meanAngle(baseAngles[index])
            for (position, stitchIndex) in (index...end).enumerated() {
                angles[stitchIndex] = base + previousStep * ((Double(position) + 0.5) / Double(groupSize) - 0.5)
            }
            index = end + 1
        }

        // 根元のない目（鎖）：前後の根元のある目の間に均等に並べる
        index = 0
        while index < count {
            guard angles[index] == nil else {
                index += 1
                continue
            }
            var end = index
            while end + 1 < count, angles[end + 1] == nil {
                end += 1
            }
            let runLength = end - index + 1
            let before = index > 0 ? angles[index - 1] : nil
            let after = end + 1 < count ? angles[end + 1] : nil
            let (start, finish): (Double, Double)
            switch (before, after) {
            case (let b?, let a?):
                start = b
                finish = a
            case (let b?, nil):
                // 段の終わり：閉じた段なら最初の目まで、入力中なら前段の1目分先まで
                start = b
                if isClosed, let first = angles.first ?? nil {
                    finish = first + 2 * Double.pi
                } else {
                    finish = b + previousStep
                }
            case (nil, let a?):
                start = a - previousStep
                finish = a
            case (nil, nil):
                start = -previousStep / 2
                finish = start + previousStep * Double(runLength)
            }
            for (position, stitchIndex) in (index...end).enumerated() {
                angles[stitchIndex] = start + (finish - start) * (Double(position) + 1) / Double(runLength + 1)
            }
            index = end + 1
        }

        return angles.map { $0 ?? 0 }
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

    /// 角度の平均。円周上で正しく平均し、結果は最初の角度の近く（±π の範囲）に戻す
    /// （前段の頭の角度は 0〜2π で増えていくので、その連続性を保つため）
    static func meanAngle(_ angles: [Double]) -> Double {
        guard let first = angles.first else { return 0 }
        let x = angles.map { cos($0) }.reduce(0, +)
        let y = angles.map { sin($0) }.reduce(0, +)
        let mean = atan2(y, x)
        var difference = (mean - first).truncatingRemainder(dividingBy: 2 * Double.pi)
        if difference > Double.pi { difference -= 2 * Double.pi }
        if difference <= -Double.pi { difference += 2 * Double.pi }
        return first + difference
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
