import CoreGraphics
import Foundation

/// 平面図（往復編み）の座標計算（tech-spec 8-2、domain-spec 9・12）。
///
/// 考え方は円形図（`CircularLayout`）の角度を x に置き換えたもの：
/// - 段の縦位置は段の高さ（鎖○目分）の累計。作り目の鎖は y = 0 に横一列、段は上（y の負の向き）へ積む
/// - 「根元」は拾った前段の目の頭の x に置く
/// - **終わった段**：数える目の「頭」を 1 目 1.0 の等間隔に並べる。並び全体のずれは、頭と根元のずれの平均が 0 になるように決める
/// - **入力中の段**（最後の段）：頭を拾った前段の目の真上に置く。増し目は前段1目分の幅の中で均等に広げ、鎖は前後の目の間に均等に並べる
/// - 向き：1段目は右から左（立ち上がりが右端）、以降は段ごとに反転する。前段は逆順に拾う（domain-spec 21）ので、
///   前段の頭の x を編んだ順に持っていれば、拾った目の番号でそのまま引ける
/// - 数えない立ち上がりは段の始まりの端（最初の目の半歩手前）に立てる
public enum FlatLayout {
    public struct Options: Hashable, Sendable {
        /// 段の高さの下限（鎖○目分）
        public var minRowHeight = 1.0
        /// 高さのない目（鎖・引き抜き）を描くときの長さ
        public var lowStitchHeight = 0.5
        /// 数えない立ち上がり（鎖1目）を描く長さ
        public var uncountedTurningChainHeight = 0.6
        /// 数えない立ち上がりを段の始まりの端からどれだけ外に出すか
        public var uncountedTurningChainOutset = 0.3
        /// 作り目の鎖を1段目の根元からどれだけ下に描くか（1段目の記号と重ならないように）
        public var foundationChainOffset = 0.45
        /// 外接矩形の余白（段番号と矢印のぶんも含む）
        public var margin = 2.6

        public init() {}
    }

    /// 編み図全体のレイアウトを計算する
    public static func layout(_ pattern: Pattern, expansion: PatternExpansion, options: Options = Options()) -> ChartLayout {
        var stitches: [LaidOutStitch] = []
        var bands: [RowBand] = []

        // 作り目の鎖：x = 0, 1, 2, … に横一列（最初に編んだ鎖が左。1段目は右端から拾い始める）。
        // 1段目の根元は y = 0 で、鎖はその少し下に描く
        var foundationChain: [CGPoint] = []
        /// 前段の「数える目」の頭の x（編んだ順）
        var previousXs: [Double] = []
        /// 前段の最後に編んだ目の x（この段の始まりの端）
        var previousEndX = 0.0
        if case .chain(let stitchCount) = pattern.foundation {
            for index in 0..<stitchCount {
                foundationChain.append(CGPoint(x: CGFloat(index), y: options.foundationChainOffset))
                previousXs.append(Double(index))
            }
            previousEndX = previousXs.last ?? 0
        }
        var baseY = 0.0
        var minX: Double = foundationChain.first.map { Double($0.x) } ?? 0
        var maxX: Double = foundationChain.last.map { Double($0.x) } ?? 0

        for (rowIndex, row) in expansion.rows.enumerated() {
            // 1段目は右から左、以降は交互
            let direction: Double = rowIndex % 2 == 0 ? -1 : 1
            let rowHeight = max(options.minRowHeight, row.stitches.map { drawHeight(of: $0, options: options) }.max() ?? 0)
            let topY = baseY - rowHeight
            let counted = row.stitches.enumerated().filter { $0.element.isCounted }

            // 数える目ごとの根元の x（拾った前段の目の頭）。鎖などは空。
            // 束に編み入れた目は、拾ったアーチ（鎖のまとまり）の中央に根元を1つ置く（domain-spec 11）
            let baseXs: [[Double]] = counted.map { _, stitch in
                let xs = stitch.picks.map { previousX(at: $0, in: previousXs, direction: direction) }
                return stitch.into == .chainSpace ? [mean(xs)] : xs
            }

            let isLastRow = rowIndex == expansion.rows.count - 1
            let (headXs, groupSizes) = headXs(
                for: counted.map(\.element), baseXs: baseXs, direction: direction,
                followsBases: isLastRow, startX: previousEndX
            )

            var countedIndexByStitchIndex: [Int: Int] = [:]
            for (countedIndex, item) in counted.enumerated() {
                countedIndexByStitchIndex[item.offset] = countedIndex
            }

            // 段の始まりの端：最初の目の半歩手前（まだ目がなければ前段の終わりの端）
            let seamX = (headXs.first ?? previousEndX) - direction * 0.5

            for (stitchIndex, stitch) in row.stitches.enumerated() {
                let laidOut: LaidOutStitch
                if let countedIndex = countedIndexByStitchIndex[stitchIndex] {
                    let bases = baseXs[countedIndex].map { CGPoint(x: $0, y: baseY) }
                    laidOut = make(
                        stitch, rowIndex: rowIndex, countedIndex: countedIndex,
                        head: CGPoint(x: headXs[countedIndex], y: topY), bases: bases,
                        sharedBaseCount: groupSizes[countedIndex], direction: direction, options: options
                    )
                } else {
                    // 数えない目：立ち上がり（鎖1目）は始まりの端の少し外に立てる（隣の目の脚と触れないように）。
                    // 引き抜きは往復編みでは入らないが、念のため段の終わりに置く
                    let x: Double
                    let height: Double
                    switch stitch.role {
                    case .turningChain(let chains):
                        x = seamX - direction * options.uncountedTurningChainOutset
                        height = chains == 1 ? options.uncountedTurningChainHeight : min(Double(chains), rowHeight)
                    case .closingSlipStitch, .regular:
                        x = (headXs.last ?? previousEndX) + direction * 0.5
                        height = options.lowStitchHeight
                    }
                    laidOut = make(
                        stitch, rowIndex: rowIndex, countedIndex: nil,
                        head: CGPoint(x: x, y: baseY - height), bases: [CGPoint(x: x, y: baseY)],
                        direction: direction, options: options
                    )
                }
                stitches.append(laidOut)
                minX = min(minX, Double(laidOut.head.x))
                maxX = max(maxX, Double(laidOut.head.x))
            }

            bands.append(RowBand(rowIndex: rowIndex, baseY: baseY, topY: topY, direction: direction, seamX: seamX))
            minX = min(minX, seamX)
            maxX = max(maxX, seamX)

            if !headXs.isEmpty {
                previousXs = headXs
                previousEndX = headXs.last ?? previousEndX
            }
            baseY = topY
        }

        let bounds = CGRect(
            x: minX - options.margin, y: baseY - options.margin,
            width: (maxX - minX) + options.margin * 2, height: -baseY + options.margin * 2
        )
        // 図の中心は外接矩形の中心（画面に収めるときの基準）
        return ChartLayout(
            stitches: stitches, bands: bands, foundationChain: foundationChain,
            center: CGPoint(x: bounds.midX, y: bounds.midY), bounds: bounds
        )
    }

    // MARK: - 頭の x

    /// 数える目の頭の x と、同じ根元を共有する目の数を決める
    /// - Parameters:
    ///   - followsBases: true なら入力中の段として前段の真上に置く。false なら終わった段として等間隔に並べる
    ///   - startX: 前段の終わりの端（根元のある目が1つもないときの並びの基準）
    private static func headXs(
        for counted: [ExpandedStitch], baseXs: [[Double]], direction: Double, followsBases: Bool, startX: Double
    ) -> (xs: [Double], groupSizes: [Int]) {
        let count = counted.count
        guard count > 0 else { return ([], []) }

        // 同じ編み入れ先を共有する続きの目（増し目）のまとまりの大きさ
        var groupSizes = [Int](repeating: 1, count: count)
        var groupStart = 0
        while groupStart < count {
            var end = groupStart
            if !baseXs[groupStart].isEmpty {
                while end + 1 < count, counted[end + 1].picks == counted[groupStart].picks, !baseXs[end + 1].isEmpty {
                    end += 1
                }
            }
            for stitchIndex in groupStart...end {
                groupSizes[stitchIndex] = end - groupStart + 1
            }
            groupStart = end + 1
        }

        // 終わった段：等間隔。ずれは頭と根元のずれの平均が 0 になるように
        if !followsBases {
            var offsets: [Double] = []
            for (index, bases) in baseXs.enumerated() where !bases.isEmpty {
                offsets.append(mean(bases) - direction * Double(index))
            }
            let offset = offsets.isEmpty ? startX : mean(offsets)
            return ((0..<count).map { offset + direction * Double($0) }, groupSizes)
        }

        var xs = [Double?](repeating: nil, count: count)

        // 入力中の段：根元のある目は、まとまりごとに前段の1目分の幅の中で均等に広げる
        var index = 0
        while index < count {
            guard !baseXs[index].isEmpty else {
                index += 1
                continue
            }
            let groupSize = groupSizes[index]
            let end = index + groupSize - 1
            let base = mean(baseXs[index])
            for (position, stitchIndex) in (index...end).enumerated() {
                xs[stitchIndex] = base + direction * ((Double(position) + 0.5) / Double(groupSize) - 0.5)
            }
            index = end + 1
        }

        // 根元のない目（鎖）：前後の根元のある目の間に均等に並べる
        index = 0
        while index < count {
            guard xs[index] == nil else {
                index += 1
                continue
            }
            var end = index
            while end + 1 < count, xs[end + 1] == nil {
                end += 1
            }
            let runLength = end - index + 1
            let before = index > 0 ? xs[index - 1] : nil
            let after = end + 1 < count ? xs[end + 1] : nil
            let (start, finish): (Double, Double)
            switch (before, after) {
            case (let b?, let a?):
                start = b
                finish = a
            case (let b?, nil):
                start = b
                finish = b + direction * Double(runLength)
            case (nil, let a?):
                start = a - direction * Double(runLength)
                finish = a
            case (nil, nil):
                start = startX - direction * 0.5
                finish = start + direction * Double(runLength)
            }
            for (position, stitchIndex) in (index...end).enumerated() {
                xs[stitchIndex] = start + (finish - start) * (Double(position) + 1) / Double(runLength + 1)
            }
            index = end + 1
        }

        return (xs.map { $0 ?? 0 }, groupSizes)
    }

    // MARK: - 補助

    /// 1目分の `LaidOutStitch` を作る
    private static func make(
        _ stitch: ExpandedStitch, rowIndex: Int, countedIndex: Int?,
        head: CGPoint, bases: [CGPoint], sharedBaseCount: Int = 1, direction: Double, options: Options
    ) -> LaidOutStitch {
        let angle: Double
        if bases.isEmpty {
            // 根元がない目（鎖）は進む方向を向いて横たわる
            angle = direction > 0 ? 0 : Double.pi
        } else {
            let meanBase = CGPoint(
                x: bases.map(\.x).reduce(0, +) / Double(bases.count),
                y: bases.map(\.y).reduce(0, +) / Double(bases.count)
            )
            angle = atan2(head.y - meanBase.y, head.x - meanBase.x)
        }
        return LaidOutStitch(
            ref: stitch.ref, kind: stitch.kind, role: stitch.role, into: stitch.into, isCounted: stitch.isCounted,
            rowIndex: rowIndex, countedIndex: countedIndex, head: head, bases: bases, sharedBaseCount: sharedBaseCount,
            angle: angle, height: drawHeight(of: stitch, options: options),
            polarAngle: atan2(-head.y, head.x), polarRadius: hypot(head.x, head.y), yarnID: stitch.yarnID
        )
    }

    /// 描くときの長さ（鎖○目分）
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

    /// 前段の目の頭の x。拾いすぎ（範囲外・負の番号）は同じ間隔で先へ続いたとみなす
    private static func previousX(at index: Int, in xs: [Double], direction: Double) -> Double {
        guard let first = xs.first else { return Double(index) }
        if xs.indices.contains(index) { return xs[index] }
        // 前段はこの段と逆向きに編んだので、番号が増える向きは -direction
        let step = xs.count >= 2 ? (xs[xs.count - 1] - first) / Double(xs.count - 1) : -direction
        return first + step * Double(index)
    }

    private static func mean(_ values: [Double]) -> Double {
        values.isEmpty ? 0 : values.reduce(0, +) / Double(values.count)
    }
}

extension Pattern {
    /// 平面図のレイアウトを計算する（`FlatLayout.layout` の省略形）
    public func flatLayout(expansion: PatternExpansion? = nil) -> ChartLayout {
        FlatLayout.layout(self, expansion: expansion ?? expanded())
    }

    /// 編み方に応じた図のレイアウト：往復編みは平面図、輪編み・螺旋編みは円形図
    public func chartLayout(expansion: PatternExpansion? = nil) -> ChartLayout {
        switch method {
        case .flat: flatLayout(expansion: expansion)
        case .joinedRounds, .spiral: circularLayout(expansion: expansion)
        }
    }
}
