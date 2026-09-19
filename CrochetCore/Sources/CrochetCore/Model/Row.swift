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
}
