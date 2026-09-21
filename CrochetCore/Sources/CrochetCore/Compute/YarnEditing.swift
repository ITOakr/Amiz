import Foundation

/// 糸リストの編集（domain-spec 29、ui-spec 6-1）
extension PatternInput {
    /// 糸を追加する（末尾）。同じ ID の糸があれば何もしない
    /// - Returns: 追加したか
    @discardableResult
    public static func addYarn(_ yarn: Yarn, to pattern: inout Pattern) -> Bool {
        guard !pattern.yarns.contains(where: { $0.id == yarn.id }) else { return false }
        pattern.yarns.append(yarn)
        return true
    }

    /// 糸の名前・色・メモを変える（ID で探す）
    /// - Returns: 変えたか
    @discardableResult
    public static func updateYarn(_ yarn: Yarn, in pattern: inout Pattern) -> Bool {
        guard let index = pattern.yarns.firstIndex(where: { $0.id == yarn.id }) else { return false }
        pattern.yarns[index] = yarn
        return true
    }

    /// 糸を並べ替える（`from` の糸を `to` の位置へ）。先頭が既定の糸になる
    /// - Returns: 動かしたか
    @discardableResult
    public static func moveYarn(from source: Int, to destination: Int, in pattern: inout Pattern) -> Bool {
        guard pattern.yarns.indices.contains(source), (0...pattern.yarns.count).contains(destination), source != destination else { return false }
        let yarn = pattern.yarns.remove(at: source)
        pattern.yarns.insert(yarn, at: destination > source ? destination - 1 : destination)
        return true
    }

    /// 糸を削除する。その糸で編んだ目は既定の糸に戻す（糸の指定を外す）。最後の1本は削除できない。
    /// 今持っている糸を削除したら既定の糸を持つ
    /// - Returns: 削除したか
    @discardableResult
    public static func deleteYarn(id: UUID, from pattern: inout Pattern) -> Bool {
        guard pattern.yarns.count > 1, let index = pattern.yarns.firstIndex(where: { $0.id == id }) else { return false }
        pattern.yarns.remove(at: index)
        for rowIndex in pattern.rows.indices {
            pattern.rows[rowIndex].steps = pattern.rows[rowIndex].steps.map { clearingYarn(id, in: $0) }
        }
        if pattern.currentYarnID == id {
            pattern.currentYarnID = nil
        }
        return true
    }

    /// 指定した糸の指定を外したコピー（繰り返しの単位の中まで）
    private static func clearingYarn(_ id: UUID, in step: Step) -> Step {
        switch step.kind {
        case .repeatGroup(let unit, let count):
            Step(id: step.id, kind: .repeatGroup(unit: unit.map { clearingYarn(id, in: $0) }, count: count), yarnID: step.yarnID == id ? nil : step.yarnID)
        default:
            step.yarnID == id ? step.withYarn(nil) : step
        }
    }
}
