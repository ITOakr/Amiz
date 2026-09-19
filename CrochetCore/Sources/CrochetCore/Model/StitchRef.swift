import Foundation

/// 展開後の1目を指す（tech-spec 5-3）。
///
/// 繰り返しは展開せずに保存するため、繰り返しの中の目には ID がない。
/// そこで「どの段の、どの操作の、何回目の繰り返しの、操作の中の何目め」の組で目を指す。
/// 目の選択・ハイライト・（将来の）目ごとの色で使う。
public struct StitchRef: Hashable, Sendable, Codable {
    /// 段の ID
    public var rowID: UUID
    /// 操作の ID。繰り返しの中の目なら、繰り返し（`repeatGroup`）ではなく単位の中の操作の ID
    public var stepID: UUID
    /// 繰り返しの何回目か（0始まり）。繰り返しの外の操作では 0
    public var repetition: Int
    /// 操作の中の何目めか（0始まり）。「3目編み入れる」の2目めなら 1。1目しか生まれない操作では 0
    public var ordinal: Int

    public init(rowID: UUID, stepID: UUID, repetition: Int = 0, ordinal: Int = 0) {
        self.rowID = rowID
        self.stepID = stepID
        self.repetition = repetition
        self.ordinal = ordinal
    }
}
