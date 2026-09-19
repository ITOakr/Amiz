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
    /// 記号の向き（画面座標のラジアン。根元から頭へ向かう方向。根元がなければ放射方向）
    public var angle: Double
    /// 記号の長さ（鎖何目分か）
    public var height: Double
    /// 頭の極座標：角度（3時が 0、画面上で反時計回りが正）
    public var polarAngle: Double
    /// 頭の極座標：半径
    public var polarRadius: Double

    public init(
        ref: StitchRef, kind: StitchKind, role: ExpandedStitch.Role, into: Placement, isCounted: Bool,
        rowIndex: Int, countedIndex: Int?, head: CGPoint, bases: [CGPoint], angle: Double, height: Double,
        polarAngle: Double, polarRadius: Double
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
        self.angle = angle
        self.height = height
        self.polarAngle = polarAngle
        self.polarRadius = polarRadius
    }
}

/// 段の輪。段番号の表示や補助線に使う
public struct RowRing: Hashable, Sendable {
    public var rowIndex: Int
    /// 根元側の半径
    public var innerRadius: Double
    /// 頭側の半径
    public var outerRadius: Double
    /// 段の始まりの角度（段番号を置く位置の目安）
    public var startAngle: Double

    public init(rowIndex: Int, innerRadius: Double, outerRadius: Double, startAngle: Double) {
        self.rowIndex = rowIndex
        self.innerRadius = innerRadius
        self.outerRadius = outerRadius
        self.startAngle = startAngle
    }
}

/// 図全体のレイアウト結果。保存せず、展開結果から毎回計算する（tech-spec 5-1）。
public struct ChartLayout: Hashable, Sendable {
    /// すべての目（段の順、段の中は編む順）
    public var stitches: [LaidOutStitch]
    /// 段ごとの輪
    public var rings: [RowRing]
    /// 図の中心
    public var center: CGPoint
    /// 図全体を含む矩形（記号の余白込み）
    public var bounds: CGRect

    private var indexByRef: [StitchRef: Int]
    private var indexByCounted: [CountedKey: Int]

    private struct CountedKey: Hashable {
        let rowIndex: Int
        let countedIndex: Int
    }

    public init(stitches: [LaidOutStitch], rings: [RowRing], center: CGPoint, bounds: CGRect) {
        self.stitches = stitches
        self.rings = rings
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
