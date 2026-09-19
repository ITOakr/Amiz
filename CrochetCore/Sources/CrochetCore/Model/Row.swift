import Foundation

/// 段。「前段の目を順に拾っていく手順」として記録する（domain-spec 21）。
///
/// 目数・警告・図の座標は持たない（表示のたびに `steps` から計算する。tech-spec 5-1）。
public struct Row: Identifiable, Hashable, Sendable, Codable {
    public let id: UUID
    /// 手順（操作の列）。立ち上がりがあれば先頭、段を閉じる引き抜きがあれば末尾に置く
    public var steps: [Step]

    public init(id: UUID = UUID(), steps: [Step] = []) {
        self.id = id
        self.steps = steps
    }

    /// 同じ手順で、段と操作の ID をすべて新しくした複製を作る（段の複製に使う。domain-spec 18）
    public func duplicated() -> Row {
        Row(steps: steps.map { $0.duplicated() })
    }

    /// ID を無視して手順が同じか（同じ内容の段のまとめ表示などに使う。domain-spec 18）
    public func hasSameSteps(as other: Row) -> Bool {
        Step.haveSameShape(steps, other.steps)
    }
}

extension Step {
    /// 同じ内容で ID を新しくした複製を作る。繰り返しの単位の中の操作も新しい ID にする
    public func duplicated() -> Step {
        switch kind {
        case .repeatGroup(let unit, let count):
            Step(kind: .repeatGroup(unit: unit.map { $0.duplicated() }, count: count))
        default:
            Step(kind: kind)
        }
    }

    /// ID を無視して内容が同じか。繰り返しは単位の中まで比べる
    public func hasSameShape(as other: Step) -> Bool {
        switch (kind, other.kind) {
        case (.repeatGroup(let unit, let count), .repeatGroup(let otherUnit, let otherCount)):
            count == otherCount && Step.haveSameShape(unit, otherUnit)
        default:
            kind == other.kind
        }
    }

    /// 操作の列どうしを ID を無視して比べる
    public static func haveSameShape(_ lhs: [Step], _ rhs: [Step]) -> Bool {
        lhs.count == rhs.count && zip(lhs, rhs).allSatisfy { $0.hasSameShape(as: $1) }
    }
}
