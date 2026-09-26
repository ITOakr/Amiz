import CoreGraphics
import Foundation

/// 円形図（輪編み・螺旋編み）の座標計算（tech-spec 8-1、domain-spec 12）。
///
/// 考え方：
/// - 段ごとの半径は、作り目からの段の高さ（鎖○目分）の累計
/// - 「根元」は拾った前段の目の頭の角度に置く
/// - **終わった段**：数える目の「頭」を円周に等間隔に並べる（実物の編み図と同じ）。並び全体の回転量は、
///   頭と根元のずれの平均が 0 になるように決める。増し目は根元を共有して頭が広がる V字、減らし目は逆V字、
///   増減なしの段は放射状になる。拾いすぎ・拾い残しは記号の傾きとして見える
/// - **入力中の段**（最後の段で、まだ閉じていない）：頭を拾った前段の目の真上に置く。増し目は前段1目分の幅の中で
///   均等に広げ、鎖は前後の目の間に均等に並べる。編んだところまでが前段の上に並び、円周に散らばらない
/// - 角度は3時の位置が 0 で、画面上で反時計回りに進む
public enum CircularLayout {
    public struct Options: Hashable, Sendable {
        /// わの作り目の穴の半径
        public var ringRadius = 0.8
        /// 鎖を輪にした作り目で、1段目の根元を輪からどれだけ外に離すか。
        /// 束に編み入れた目は根元を離して描く（domain-spec 11）。画面側の `Style.chainSpaceGap` と同じ量
        public var chainRingBaseGap = 0.34
        /// 段の高さの下限（鎖○目分）
        public var minRowHeight = 1.0
        /// 高さのない目（鎖・引き抜き）を描くときの長さ
        public var lowStitchHeight = 0.5
        /// 数えない立ち上がり（鎖1目）を描く長さ（根元から。段の高さより短くして隣の目と触れないようにする）
        public var uncountedTurningChainHeight = 0.5
        /// 段を閉じる引き抜きを頭からどれだけ内側に置くか（次の段の立ち上がりと離すため）
        public var closingSlipInset = 0.12
        /// ピコットを頭からどれだけ外に出すか（輪の中心までの距離）
        public var picotOutset = 0.45
        /// 外接矩形の余白
        public var margin = 1.5

        public init() {}
    }

    /// 編み図全体のレイアウトを計算する
    public static func layout(_ pattern: Pattern, expansion: PatternExpansion, options: Options = Options()) -> ChartLayout {
        let center = CGPoint.zero
        var stitches: [LaidOutStitch] = []
        var rings: [RowRing] = []
        // 穴の半径。鎖を輪にした作り目は、輪にした鎖が1目ぶんずつ並ぶ大きさにする（domain-spec 33）
        let holeRadius = holeRadius(for: pattern.foundation, options: options)
        var innerRadius = holeRadius
        let isChainRing = if case .chainRing = pattern.foundation { true } else { false }
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

            // 数える目ごとの根元の角度（拾った前段の目の頭の角度。鎖などは空）。
            // 束に編み入れた目は、拾ったアーチ（鎖のまとまり）の中央に根元を1つ置く（domain-spec 11）
            let baseAngles: [[Double]] = counted.map { _, stitch in
                guard rowIndex > 0, !stitch.picks.isEmpty else { return [] }
                let angles = stitch.picks.map { previousAngle(at: $0, in: previousHeadAngles) }
                return stitch.into == .chainSpace ? [meanAngle(angles)] : angles
            }

            let isClosed = row.stitches.contains { $0.role == .closingSlipStitch }
            let isLastRow = rowIndex == expansion.rows.count - 1
            let (headAngles, groupSizes) = headAngles(
                for: counted.map(\.element), baseAngles: baseAngles, rowIndex: rowIndex,
                previousStep: previousStep, isClosed: isClosed,
                followsBases: isLastRow && !isClosed, previousFirstHead: previousHeadAngles.first
            )

            var countedIndexByStitchIndex: [Int: Int] = [:]
            for (countedIndex, item) in counted.enumerated() {
                countedIndexByStitchIndex[item.offset] = countedIndex
            }

            // 段の始まりの空き：最初の目の半歩手前（等間隔ならこの段の1目分、入力中なら前段の1目分の半分）
            let ownStep = headAngles.count > 1 ? headAngles[1] - headAngles[0] : previousStep
            let seamAngle = (headAngles.first ?? previousHeadAngles.first ?? 0) - ownStep / 2

            /// 直前に置いた数える目（ピコットを付ける相手）
            var lastCountedIndex: Int?
            for (stitchIndex, stitch) in row.stitches.enumerated() {
                let laidOut: LaidOutStitch
                if let countedIndex = countedIndexByStitchIndex[stitchIndex] {
                    lastCountedIndex = countedIndex
                    let headAngle = headAngles[countedIndex]
                    let bases: [CGPoint]
                    if rowIndex == 0 {
                        // 作り目：根元は輪の上、頭と同じ角度。
                        // 鎖を輪にした作り目は輪の中に束に編み入れるので、根元を輪から少し離す（domain-spec 11）
                        let gap = isChainRing ? options.chainRingBaseGap : 0
                        bases = [point(center: center, radius: innerRadius + gap, angle: headAngle)]
                    } else {
                        bases = baseAngles[countedIndex].map { point(center: center, radius: innerRadius, angle: $0) }
                    }
                    laidOut = make(
                        stitch, rowIndex: rowIndex, countedIndex: countedIndex,
                        headAngle: headAngle, outerRadius: outerRadius, bases: bases,
                        sharedBaseCount: groupSizes[countedIndex],
                        center: center, options: options
                    )
                } else {
                    // 数えない目は段の始まりの空き（seam）に置く。同じ角度でも高さで分ける：
                    // 立ち上がり（鎖1目）は根元寄りの小さな楕円、段を閉じる引き抜きは頭の近くの点
                    // （×は中ほどが幅広く根元と頭の近くは細いので、隣の目と触れない）。
                    // 数えない立ち上がりが鎖2目以上なら、鎖の目数ぶんの高さ（引き抜きに触れない範囲）で描く
                    let angle: Double
                    let radius: Double
                    switch stitch.role {
                    case .turningChain(let chains):
                        angle = seamAngle
                        radius = chains == 1
                            ? innerRadius + options.uncountedTurningChainHeight
                            : innerRadius + min(Double(chains), rowHeight - options.closingSlipInset - 0.25)
                    case .closingSlipStitch:
                        angle = seamAngle
                        radius = outerRadius - options.closingSlipInset
                    case .regular:
                        angle = headAngles.last ?? previousHeadAngles.first ?? 0
                        radius = outerRadius
                    case .picot:
                        // 直前の目の頭の外側に小さな輪（根元はその目の頭）
                        angle = lastCountedIndex.map { headAngles[$0] } ?? previousHeadAngles.first ?? 0
                        radius = outerRadius + options.picotOutset
                    }
                    let bases: [CGPoint] = switch stitch.role {
                    case .closingSlipStitch: []
                    case .picot: [point(center: center, radius: outerRadius, angle: angle)]
                    default: [point(center: center, radius: innerRadius, angle: angle)]
                    }
                    laidOut = make(
                        stitch, rowIndex: rowIndex, countedIndex: nil,
                        headAngle: angle, outerRadius: radius,
                        bases: bases,
                        center: center, options: options
                    )
                }
                stitches.append(laidOut)
            }

            rings.append(RowRing(
                rowIndex: rowIndex, innerRadius: innerRadius, outerRadius: outerRadius,
                startAngle: headAngles.first ?? previousHeadAngles.first ?? 0, seamAngle: seamAngle
            ))
            previousHeadAngles = headAngles
            innerRadius = outerRadius
        }

        let radius = innerRadius + options.margin
        let bounds = CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2)
        return ChartLayout(
            stitches: stitches, rings: rings,
            foundationChain: foundationChain(for: pattern.foundation, center: center, radius: holeRadius),
            center: center, bounds: bounds
        )
    }

    // MARK: - 頭の角度

    /// 数える目の頭の角度と、同じ根元を共有する目の数を決める（並べ方の本体は `StitchPlacement`）
    /// - Parameters:
    ///   - followsBases: true なら入力中の段として前段の真上に置く。false なら終わった段として等間隔に並べる
    private static func headAngles(
        for counted: [ExpandedStitch], baseAngles: [[Double]], rowIndex: Int,
        previousStep: Double, isClosed: Bool, followsBases: Bool, previousFirstHead: Double?
    ) -> (angles: [Double], groupSizes: [Int]) {
        let count = counted.count
        guard count > 0 else { return ([], []) }

        let groupSizes = StitchPlacement.groupSizes(for: counted, bases: baseAngles)
        let options = placementOptions(previousStep: previousStep)

        // 1段目（わの作り目）：等間隔に1周
        if rowIndex == 0 {
            return ((0..<count).map { previousStep * Double($0) }, groupSizes)
        }

        // 終わった段：等間隔に1周。回転量は頭と根元のずれの平均が 0 になるように
        if !followsBases {
            let angles = StitchPlacement.evenlySpaced(
                bases: baseAngles, step: (2 * Double.pi) / Double(count),
                fallbackOffset: previousFirstHead ?? 0, mean: meanAngle
            )
            return (angles, groupSizes)
        }

        // 入力中の段：根元のある目は前段の真上、鎖は前後の目の間に
        var angles = StitchPlacement.followingBases(bases: baseAngles, groupSizes: groupSizes, options: options)
        StitchPlacement.fillRunsWithoutBase(&angles, isClosed: isClosed, options: options)
        return (angles.map { $0 ?? 0 }, groupSizes)
    }

    /// 円形図での並べ方（角度。1周は 2π）
    private static func placementOptions(previousStep: Double) -> StitchPlacement.Options {
        StitchPlacement.Options(
            previousStep: previousStep,
            mean: meanAngle,
            trailingStep: previousStep,
            leadingSpan: { _ in previousStep },
            closedWrap: 2 * Double.pi,
            fallbackStart: -previousStep / 2
        )
    }

    // MARK: - 補助

    /// 1目分の `LaidOutStitch` を作る
    private static func make(
        _ stitch: ExpandedStitch, rowIndex: Int, countedIndex: Int?,
        headAngle: Double, outerRadius: Double, bases: [CGPoint], sharedBaseCount: Int = 1,
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
            rowIndex: rowIndex, countedIndex: countedIndex, head: head, bases: bases, sharedBaseCount: sharedBaseCount,
            angle: direction, height: drawHeight(of: stitch, options: options),
            polarAngle: headAngle, polarRadius: outerRadius, yarnID: stitch.yarnID, clusterCount: stitch.clusterCount
        )
    }

    /// 穴（一番内側）の半径。鎖を輪にした作り目は、鎖 n 目が1目ぶんずつ並ぶ円の大きさ（円周 ≒ n）にする。
    /// わの作り目より小さくはしない
    static func holeRadius(for foundation: FoundationKind, options: Options) -> Double {
        switch foundation {
        case .chainRing(let chainCount):
            max(options.ringRadius, Double(chainCount) / (2 * Double.pi))
        case .magicRing, .chain:
            options.ringRadius
        }
    }

    /// 作り目の鎖の位置（鎖を輪にした作り目のみ）。一番内側の輪の上に、編む向き（反時計回り）に等間隔で並べる
    static func foundationChain(
        for foundation: FoundationKind, center: CGPoint, radius: Double
    ) -> [FoundationChainLink] {
        guard case .chainRing(let chainCount) = foundation else { return [] }
        let step = (2 * Double.pi) / Double(max(chainCount, 1))
        return (0..<chainCount).map { index in
            let head = Double(index) * step
            return FoundationChainLink(
                root: point(center: center, radius: radius, angle: head - step),
                head: point(center: center, radius: radius, angle: head)
            )
        }
    }

    /// 描くときの長さ（鎖○目分）
    static func drawHeight(of stitch: ExpandedStitch, options: Options) -> Double {
        stitch.drawHeight(lowStitchHeight: options.lowStitchHeight)
    }

    /// 前段の目の頭の角度。拾いすぎで前段の範囲を超えたら、同じ間隔で回り続けたとみなす
    private static func previousAngle(at index: Int, in headAngles: [Double]) -> Double {
        guard !headAngles.isEmpty else { return 0 }
        if headAngles.indices.contains(index) { return headAngles[index] }
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
