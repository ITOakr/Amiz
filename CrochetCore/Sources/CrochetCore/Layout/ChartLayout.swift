import CoreGraphics
import Foundation

/// 図に置かれた1目。座標の単位は「鎖1目分」＝1.0（描画側で倍率をかける）。
///
/// 画面座標（右が +x、下が +y）で持つ。`polarAngle` は 3時の位置を 0 とし、画面上で反時計回りに増える。
public struct LaidOutStitch: Hashable, Sendable {
    /// どの操作から生まれたか
    public var ref: StitchRef
    public var kind: StitchKind
    public var role: ExpandedStitch.Role
    public var into: Placement
    public var isCounted: Bool
    /// 段の位置（0始まり）
    public var rowIndex: Int
    /// 段の中で何番目の「数える目」か（0始まり）。数えない目は nil
    public var countedIndex: Int?
    /// 記号の頭（先端）の位置
    public var head: CGPoint
    /// 記号の根元の位置。鎖編みなど前段を拾わない目は空、普通の目は1つ、n目一度は n 個
    public var bases: [CGPoint]
    /// 同じ根元を共有する目の数（n目編み入れるなら n。普通の目は 1）。記号の描き分けに使う（domain-spec 11）
    public var sharedBaseCount: Int
    /// 記号の向き（画面座標のラジアン。根元から頭へ向かう方向。根元がなければ放射方向）
    public var angle: Double
    /// 記号の長さ（鎖何目分か）
    public var height: Double
    /// 頭の極座標：角度（3時が 0、画面上で反時計回りが正）
    public var polarAngle: Double
    /// 頭の極座標：半径
    public var polarRadius: Double
    /// 糸（nil は既定の糸。domain-spec 27・30）
    public var yarnID: UUID?

    public init(
        ref: StitchRef, kind: StitchKind, role: ExpandedStitch.Role, into: Placement, isCounted: Bool,
        rowIndex: Int, countedIndex: Int?, head: CGPoint, bases: [CGPoint], sharedBaseCount: Int = 1,
        angle: Double, height: Double, polarAngle: Double, polarRadius: Double, yarnID: UUID? = nil
    ) {
        self.ref = ref
        self.kind = kind
        self.role = role
        self.into = into
        self.isCounted = isCounted
        self.rowIndex = rowIndex
        self.countedIndex = countedIndex
        self.head = head
        self.bases = bases
        self.sharedBaseCount = sharedBaseCount
        self.angle = angle
        self.height = height
        self.polarAngle = polarAngle
        self.polarRadius = polarRadius
        self.yarnID = yarnID
    }
}

/// 段の輪。段番号の表示や補助線に使う
public struct RowRing: Hashable, Sendable {
    public var rowIndex: Int
    /// 根元側の半径
    public var innerRadius: Double
    /// 頭側の半径
    public var outerRadius: Double
    /// 段の最初の目の頭の角度
    public var startAngle: Double
    /// 段の始まりの空き（最初の目の半歩手前）の角度。立ち上がり・段を閉じる引き抜き・段番号を置く
    public var seamAngle: Double

    public init(rowIndex: Int, innerRadius: Double, outerRadius: Double, startAngle: Double, seamAngle: Double) {
        self.rowIndex = rowIndex
        self.innerRadius = innerRadius
        self.outerRadius = outerRadius
        self.startAngle = startAngle
        self.seamAngle = seamAngle
    }
}

/// 平面図（往復編み）の段の帯。段番号と方向の矢印、補助線に使う
public struct RowBand: Hashable, Sendable {
    public var rowIndex: Int
    /// 根元側の y（画面座標。下が +）
    public var baseY: Double
    /// 頭側の y
    public var topY: Double
    /// 手順を進める方向（+1 なら左から右、-1 なら右から左）
    public var direction: Double
    /// 段の始まりの端の x（立ち上がりを置く位置。段番号と矢印はこの外側に置く）
    public var seamX: Double

    public init(rowIndex: Int, baseY: Double, topY: Double, direction: Double, seamX: Double) {
        self.rowIndex = rowIndex
        self.baseY = baseY
        self.topY = topY
        self.direction = direction
        self.seamX = seamX
    }
}

/// 図全体のレイアウト結果。保存せず、展開結果から毎回計算する（tech-spec 5-1）。
///
/// 円形図（輪編み・螺旋編み）は `rings`、平面図（往復編み）は `bands` と `foundationChain` を持つ。目の座標の持ち方は共通
public struct ChartLayout: Hashable, Sendable {
    /// すべての目（段の順、段の中は編む順）
    public var stitches: [LaidOutStitch]
    /// 段ごとの輪（円形図）
    public var rings: [RowRing]
    /// 段ごとの帯（平面図）
    public var bands: [RowBand]
    /// 作り目の鎖の位置（平面図。鎖の作り目の n 目を編んだ順に）
    public var foundationChain: [CGPoint]
    /// 図の中心（円形図は輪の中心、平面図は外接矩形の中心。画面に収めるときの基準）
    public var center: CGPoint
    /// 図全体を含む矩形（記号の余白込み）
    public var bounds: CGRect

    private var indexByRef: [StitchRef: Int]
    private var indexByCounted: [CountedKey: Int]

    private struct CountedKey: Hashable {
        let rowIndex: Int
        let countedIndex: Int
    }

    public init(
        stitches: [LaidOutStitch], rings: [RowRing] = [], bands: [RowBand] = [], foundationChain: [CGPoint] = [],
        center: CGPoint, bounds: CGRect
    ) {
        self.stitches = stitches
        self.rings = rings
        self.bands = bands
        self.foundationChain = foundationChain
        self.center = center
        self.bounds = bounds
        var byRef: [StitchRef: Int] = [:]
        var byCounted: [CountedKey: Int] = [:]
        for (index, stitch) in stitches.enumerated() {
            byRef[stitch.ref] = index
            if let counted = stitch.countedIndex {
                byCounted[CountedKey(rowIndex: stitch.rowIndex, countedIndex: counted)] = index
            }
        }
        indexByRef = byRef
        indexByCounted = byCounted
    }

    /// 操作から目を探す（目の選択に使う）
    public func stitch(for ref: StitchRef) -> LaidOutStitch? {
        indexByRef[ref].map { stitches[$0] }
    }

    /// 段の何番目の「数える目」かで探す（次に拾う目のハイライトに使う）
    public func countedStitch(rowIndex: Int, countedIndex: Int) -> LaidOutStitch? {
        indexByCounted[CountedKey(rowIndex: rowIndex, countedIndex: countedIndex)].map { stitches[$0] }
    }

    /// タップした位置に一番近い目（頭の位置で比べる。tech-spec 7）
    /// - Parameter maxDistance: これより遠ければ nil
    public func nearestStitch(to point: CGPoint, maxDistance: Double = .infinity) -> LaidOutStitch? {
        var best: (stitch: LaidOutStitch, distance: Double)?
        for stitch in stitches {
            let dx = Double(stitch.head.x - point.x)
            let dy = Double(stitch.head.y - point.y)
            let distance = (dx * dx + dy * dy).squareRoot()
            if distance <= maxDistance, best == nil || distance < best!.distance {
                best = (stitch, distance)
            }
        }
        return best?.stitch
    }
}
