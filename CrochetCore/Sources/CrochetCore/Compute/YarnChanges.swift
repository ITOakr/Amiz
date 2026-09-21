import Foundation

/// 色替えの位置（domain-spec 31）。
///
/// 実際の編み方では「前の目の最後の引き抜き」で新しい糸に替えるので、
/// 「新しい糸で編む最初の目」と「その直前の目（ここで持ち替える）」の組で表す。
/// 段の最初の目で替える場合、直前の目は前の段の最後の目
public struct YarnChange: Hashable, Sendable {
    /// 新しい糸で編む最初の目
    public var ref: StitchRef
    /// 持ち替える目（直前の目）。作品の最初の目なら nil
    public var previousRef: StitchRef?
    /// 新しい糸（既定の糸にそろえた ID）
    public var yarnID: UUID
    /// 段の最初の目での替えか（目数表で段の先頭に糸名を付ける判定に使う）
    public var isAtRowStart: Bool

    public init(ref: StitchRef, previousRef: StitchRef?, yarnID: UUID, isAtRowStart: Bool) {
        self.ref = ref
        self.previousRef = previousRef
        self.yarnID = yarnID
        self.isAtRowStart = isAtRowStart
    }
}

extension PatternExpansion {
    /// 色替えの位置をすべて求める。糸の指定がない目は既定の糸として比べる。
    /// 作品の最初の目は「替え」ではない（糸リストの糸で編み始める）
    public func yarnChanges(in pattern: Pattern) -> [YarnChange] {
        var changes: [YarnChange] = []
        var previous: (ref: StitchRef, yarnID: UUID)?

        for row in rows {
            var isRowStart = true
            for stitch in row.stitches {
                let yarnID = pattern.resolvedYarnID(stitch.yarnID)
                if let previous, previous.yarnID != yarnID {
                    changes.append(YarnChange(ref: stitch.ref, previousRef: previous.ref, yarnID: yarnID, isAtRowStart: isRowStart))
                }
                previous = (stitch.ref, yarnID)
                isRowStart = false
            }
        }
        return changes
    }

    /// 段の最後の目の糸（既定の糸にそろえた ID）。目のない段は nil
    public func lastYarnID(inRowAt rowIndex: Int, pattern: Pattern) -> UUID? {
        guard rows.indices.contains(rowIndex), let last = rows[rowIndex].stitches.last else { return nil }
        return pattern.resolvedYarnID(last.yarnID)
    }
}
