import Foundation

/// 編み入れ先（domain-spec 3）。
///
/// rawValue は保存形式（JSON）の一部なので変更しない。
public enum Placement: String, Codable, Hashable, Sendable {
    /// 前段の目の頭に編み入れる
    case stitch
    /// 鎖のループや前段のすき間に束で編み入れる
    case chainSpace
}

/// 繰り返しの回数（domain-spec 15・17）。
public enum RepeatCount: Hashable, Sendable {
    /// 回数を固定する（「×6」）
    case times(Int)
    /// 前段の目数に合わせて決める（「段の終わりまで」「残りすべてに」）
    case untilEnd
}

/// 操作の種類（domain-spec 21）。
///
/// 画面のボタン1回＝1つの操作、を原則にする。鎖編みを3回押せば `.stitch(.chain)` が3つ並ぶ。
/// 例外は「n目編み入れる」「n目一度」（先に選ぶボタン＋目ボタンで1操作）と、立ち上がり（鎖の目数を持つ）。
public enum StepKind: Hashable, Sendable {
    /// 立ち上がり。鎖編みとは別の操作として記録する（domain-spec 6）。
    /// `counted` は「1目と数えるか」。標準は鎖1目なら数えず、2目以上なら数える（`StepKind.standardTurningChainCounted`）
    case turningChain(chains: Int, counted: Bool)
    /// 普通の目1目。鎖編みもここに含む（鎖編みは前段を拾わない。domain-spec 4）
    case stitch(StitchKind, into: Placement = .stitch)
    /// n目編み入れる（増し目）。同じ編み入れ先に count 目編む（domain-spec 2）
    case increase(StitchKind, count: Int = 2, into: Placement = .stitch)
    /// n目一度（減らし目）。前段の count 目をまとめて1目にする（domain-spec 2）
    case decrease(StitchKind, count: Int = 2)
    /// 玉編み。同じ編み入れ先に未完成の目を count 本編み、まとめて引き抜いて1目にする（domain-spec 2）。
    /// 目の種類は中長編み・長編み・長々編み
    case cluster(StitchKind, count: Int = 3, into: Placement = .stitch)
    /// ピコット。鎖 chains 目を直前の目の頭に引き抜いた小さな輪。前段を拾わず、目数にも数えない（domain-spec 3・21）
    case picot(chains: Int = 3)
    /// 前段の目を1目飛ばす（domain-spec 22）
    case skip
    /// 残りは編まない（domain-spec 23）
    case leaveRemaining
    /// 段を閉じる引き抜き。「段を終える」で自動的に入る（domain-spec 7）
    case closeRound
    /// 繰り返し。単位（操作の列）と回数（domain-spec 15）。
    /// 「残りすべてに細編み」は、単位が1つで回数が `.untilEnd` の繰り返しとして表す。
    /// 型の上では入れ子にできるが、使わない（検証で禁止する）
    case repeatGroup(unit: [Step], count: RepeatCount)

    /// 立ち上がりを1目と数えるかの標準（domain-spec 6）：鎖1目なら数えない、2目以上なら数える。
    /// 設定で「数える」「数えない」を選んだときは、この標準の代わりにその値を使う
    public static func standardTurningChainCounted(chains: Int) -> Bool {
        chains >= 2
    }

    /// 標準の数え方の立ち上がり（`counted` を省略した書き方）
    public static func turningChain(chains: Int) -> StepKind {
        .turningChain(chains: chains, counted: standardTurningChainCounted(chains: chains))
    }
}

/// 手順の1操作。ID を持つ（tech-spec 5-3）。
///
/// 「操作」の英語は operation だが、Apple の標準ライブラリ Foundation の Operation と
/// 名前が衝突するため Step としている。
public struct Step: Identifiable, Hashable, Sendable {
    public let id: UUID
    public var kind: StepKind
    /// 糸（domain-spec 27）。nil なら既定の糸。繰り返しの中の操作にも付き、全部の回で同じ糸になる。
    /// 繰り返しの操作そのものには付けない（単位の中の操作が持つ）
    public var yarnID: UUID?

    public init(id: UUID = UUID(), kind: StepKind, yarnID: UUID? = nil) {
        self.id = id
        self.kind = kind
        self.yarnID = yarnID
    }

    /// 糸を変えたコピー
    public func withYarn(_ yarnID: UUID?) -> Step {
        Step(id: id, kind: kind, yarnID: yarnID)
    }
}

// MARK: - 組み立て用のショートカット
// 新しい ID を付けた Step を作る。テストや入力処理から `.stitch(.singleCrochet)` のように書ける。

extension Step {
    /// 立ち上がり（鎖 `chains` 目）。`counted` を省略すると標準（鎖1目は数えない、2目以上は数える）
    public static func turningChain(_ chains: Int, counted: Bool? = nil) -> Step {
        Step(kind: .turningChain(chains: chains, counted: counted ?? StepKind.standardTurningChainCounted(chains: chains)))
    }

    /// 普通の目1目
    public static func stitch(_ kind: StitchKind, into placement: Placement = .stitch) -> Step {
        Step(kind: .stitch(kind, into: placement))
    }

    /// n目編み入れる
    public static func increase(_ kind: StitchKind, count: Int = 2, into placement: Placement = .stitch) -> Step {
        Step(kind: .increase(kind, count: count, into: placement))
    }

    /// n目一度
    public static func decrease(_ kind: StitchKind, count: Int = 2) -> Step {
        Step(kind: .decrease(kind, count: count))
    }

    /// 玉編み（count 本）
    public static func cluster(_ kind: StitchKind, count: Int = 3, into placement: Placement = .stitch) -> Step {
        Step(kind: .cluster(kind, count: count, into: placement))
    }

    /// ピコット（鎖 chains 目）
    public static func picot(_ chains: Int = 3) -> Step {
        Step(kind: .picot(chains: chains))
    }

    /// 前段の目を1目飛ばす
    public static func skip() -> Step {
        Step(kind: .skip)
    }

    /// 残りは編まない
    public static func leaveRemaining() -> Step {
        Step(kind: .leaveRemaining)
    }

    /// 段を閉じる引き抜き
    public static func closeRound() -> Step {
        Step(kind: .closeRound)
    }

    /// 繰り返し（回数固定）
    public static func repeating(_ unit: [Step], times: Int) -> Step {
        Step(kind: .repeatGroup(unit: unit, count: .times(times)))
    }

    /// 繰り返し（段の終わりまで）。「残りすべてに◯」は単位を1つにして使う
    public static func untilEnd(_ unit: [Step]) -> Step {
        Step(kind: .repeatGroup(unit: unit, count: .untilEnd))
    }
}

// MARK: - JSON 変換
// 操作の種類を "type" で見分ける平らな形にする。Swift の自動生成に任せると "_0" のような
// 読めないキーになり、型名の変更で古いデータが読めなくなるため、自分で書く。
//
//   {"id":"…","type":"turningChain","chains":1,"counted":false}   （"counted" が無ければ鎖の目数で決める）
//   {"id":"…","type":"stitch","stitch":"singleCrochet","into":"stitch"}
//   {"id":"…","type":"increase","stitch":"singleCrochet","count":2,"into":"stitch"}
//   {"id":"…","type":"decrease","stitch":"singleCrochet","count":2}
//   {"id":"…","type":"cluster","stitch":"doubleCrochet","count":3,"into":"stitch"}
//   {"id":"…","type":"picot","chains":3}
//   {"id":"…","type":"skip"} / {"type":"leaveRemaining"} / {"type":"closeRound"}
//   {"id":"…","type":"repeat","count":6,"unit":[…]}   （段の終わりまでは "count":"untilEnd"）
//   糸を指定した操作は "yarn":"<糸のID>" が付く（既定の糸なら付かない）

extension Step: Codable {
    private enum CodingKeys: String, CodingKey {
        case id, type, chains, counted, stitch, count, into, unit, yarn
    }

    private enum TypeName: String, Codable {
        case turningChain, stitch, increase, decrease, cluster, picot, skip, leaveRemaining, closeRound
        case repeatGroup = "repeat"
    }

    /// 読み込んだ数が決めた範囲に入っているか確かめる。外れていれば読み込みエラーにする（壊れたデータで落ちないように）
    private static func validate(
        _ value: Int, _ range: ClosedRange<Int>, _ key: CodingKeys, in container: KeyedDecodingContainer<CodingKeys>
    ) throws -> Int {
        guard range.contains(value) else {
            throw DecodingError.dataCorruptedError(
                forKey: key, in: container,
                debugDescription: "\(key.stringValue) は \(range.lowerBound)〜\(range.upperBound) の範囲で保存されます（読み込んだ値：\(value)）"
            )
        }
        return value
    }

    /// 1つの操作で扱える目数の上限（画面からは 3〜5 までしか入らないが、手で書いたデータも読めるよう緩めにする）
    private static let countLimit = 99

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let id = try container.decode(UUID.self, forKey: .id)
        let kind: StepKind

        switch try container.decode(TypeName.self, forKey: .type) {
        case .turningChain:
            let chains = try Step.validate(try container.decode(Int.self, forKey: .chains), 1...Step.countLimit, .chains, in: container)
            kind = .turningChain(
                chains: chains,
                counted: try container.decodeIfPresent(Bool.self, forKey: .counted) ?? StepKind.standardTurningChainCounted(chains: chains)
            )
        case .stitch:
            kind = .stitch(
                try container.decode(StitchKind.self, forKey: .stitch),
                into: try container.decodeIfPresent(Placement.self, forKey: .into) ?? .stitch
            )
        case .increase:
            kind = .increase(
                try container.decode(StitchKind.self, forKey: .stitch),
                count: try Step.validate(try container.decode(Int.self, forKey: .count), 2...Step.countLimit, .count, in: container),
                into: try container.decodeIfPresent(Placement.self, forKey: .into) ?? .stitch
            )
        case .decrease:
            kind = .decrease(
                try container.decode(StitchKind.self, forKey: .stitch),
                count: try Step.validate(try container.decode(Int.self, forKey: .count), 2...Step.countLimit, .count, in: container)
            )
        case .cluster:
            kind = .cluster(
                try container.decode(StitchKind.self, forKey: .stitch),
                count: try Step.validate(try container.decode(Int.self, forKey: .count), 2...Step.countLimit, .count, in: container),
                into: try container.decodeIfPresent(Placement.self, forKey: .into) ?? .stitch
            )
        case .picot:
            kind = .picot(chains: try Step.validate(try container.decode(Int.self, forKey: .chains), 1...Step.countLimit, .chains, in: container))
        case .skip:
            kind = .skip
        case .leaveRemaining:
            kind = .leaveRemaining
        case .closeRound:
            kind = .closeRound
        case .repeatGroup:
            kind = .repeatGroup(
                unit: try container.decode([Step].self, forKey: .unit),
                count: try container.decode(RepeatCount.self, forKey: .count)
            )
        }

        self.init(id: id, kind: kind, yarnID: try container.decodeIfPresent(UUID.self, forKey: .yarn))
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encodeIfPresent(yarnID, forKey: .yarn)

        switch kind {
        case .turningChain(let chains, let counted):
            try container.encode(TypeName.turningChain, forKey: .type)
            try container.encode(chains, forKey: .chains)
            try container.encode(counted, forKey: .counted)
        case .stitch(let stitchKind, let placement):
            try container.encode(TypeName.stitch, forKey: .type)
            try container.encode(stitchKind, forKey: .stitch)
            try container.encode(placement, forKey: .into)
        case .increase(let stitchKind, let count, let placement):
            try container.encode(TypeName.increase, forKey: .type)
            try container.encode(stitchKind, forKey: .stitch)
            try container.encode(count, forKey: .count)
            try container.encode(placement, forKey: .into)
        case .decrease(let stitchKind, let count):
            try container.encode(TypeName.decrease, forKey: .type)
            try container.encode(stitchKind, forKey: .stitch)
            try container.encode(count, forKey: .count)
        case .cluster(let stitchKind, let count, let placement):
            try container.encode(TypeName.cluster, forKey: .type)
            try container.encode(stitchKind, forKey: .stitch)
            try container.encode(count, forKey: .count)
            try container.encode(placement, forKey: .into)
        case .picot(let chains):
            try container.encode(TypeName.picot, forKey: .type)
            try container.encode(chains, forKey: .chains)
        case .skip:
            try container.encode(TypeName.skip, forKey: .type)
        case .leaveRemaining:
            try container.encode(TypeName.leaveRemaining, forKey: .type)
        case .closeRound:
            try container.encode(TypeName.closeRound, forKey: .type)
        case .repeatGroup(let unit, let count):
            try container.encode(TypeName.repeatGroup, forKey: .type)
            try container.encode(count, forKey: .count)
            try container.encode(unit, forKey: .unit)
        }
    }
}

// 回数は整数（"count":6）か文字列（"count":"untilEnd"）で保存する。
extension RepeatCount: Codable {
    private static let untilEndValue = "untilEnd"

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let times = try? container.decode(Int.self) {
            guard times >= 0 else {
                throw DecodingError.dataCorrupted(
                    .init(codingPath: decoder.codingPath, debugDescription: "繰り返しの回数は 0 以上で保存されます（読み込んだ値：\(times)）")
                )
            }
            self = .times(times)
        } else if try container.decode(String.self) == Self.untilEndValue {
            self = .untilEnd
        } else {
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "繰り返しの回数は整数か \"\(Self.untilEndValue)\" で指定する"
            )
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .times(let times):
            try container.encode(times)
        case .untilEnd:
            try container.encode(Self.untilEndValue)
        }
    }
}
