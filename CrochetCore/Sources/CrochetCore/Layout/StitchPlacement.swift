import Foundation

/// 段の中で目を1次元に並べる計算（tech-spec 8-1・8-2）。
///
/// 円形図（`CircularLayout`）は「角度」、平面図（`FlatLayout`）は「x」を並べるが、考え方は同じなので
/// ここに1つだけ置く。違い（角度は 2π で1周する・平面は向きが段ごとに反転する）は `Options` で渡す。
/// 以前は同じ処理が2か所にあり、片方だけ直して片方を忘れるバグが起きた（AMIZ-58・72）
enum StitchPlacement {
    /// 図ごとの違い
    struct Options {
        /// 前段の1目分の幅（円形図は角度、平面図は ±1）
        var previousStep: Double
        /// 根元の位置をまとめる方法（円形図は円周上の平均、平面図はただの平均）
        var mean: ([Double]) -> Double
        /// 段の終わりに続く根元のない目（鎖）の並べ方：1つにつきこれだけ先へ進める
        var trailingStep: Double
        /// 段の始まりにある根元のない目の並べ方：全体でこれだけ手前から始める
        var leadingSpan: (_ runLength: Int) -> Double
        /// 閉じた段で最初の目に戻るときの1周分（円形図は 2π。平面図は nil）
        var closedWrap: Double?
        /// 根元のある目が1つもない段の基準
        var fallbackStart: Double
    }

    /// 同じ編み入れ先を共有する続きの目（増し目）のまとまりの大きさ。
    /// 増し目の n 目は根元を共有するので、まとめて1目分の幅に広げる（domain-spec 2・11）
    static func groupSizes(for counted: [ExpandedStitch], bases: [[Double]]) -> [Int] {
        let count = counted.count
        var sizes = [Int](repeating: 1, count: count)
        var start = 0
        while start < count {
            var end = start
            if !bases[start].isEmpty {
                while end + 1 < count, counted[end + 1].picks == counted[start].picks, !bases[end + 1].isEmpty {
                    end += 1
                }
            }
            for index in start...end {
                sizes[index] = end - start + 1
            }
            start = end + 1
        }
        return sizes
    }

    /// 入力中の段：根元のある目を、まとまりごとに前段の1目分の幅の中で均等に広げる。
    /// 根元のない目（鎖）は `fillRunsWithoutBase` で埋める
    static func followingBases(
        bases: [[Double]], groupSizes: [Int], options: Options
    ) -> [Double?] {
        var positions = [Double?](repeating: nil, count: bases.count)
        var index = 0
        while index < bases.count {
            guard !bases[index].isEmpty else {
                index += 1
                continue
            }
            let groupSize = groupSizes[index]
            let end = index + groupSize - 1
            let base = options.mean(bases[index])
            for (position, stitchIndex) in (index...end).enumerated() {
                positions[stitchIndex] = base + options.previousStep * ((Double(position) + 0.5) / Double(groupSize) - 0.5)
            }
            index = end + 1
        }
        return positions
    }

    /// 根元のない目（鎖）を、前後の根元のある目の間に均等に並べる
    static func fillRunsWithoutBase(_ positions: inout [Double?], isClosed: Bool, options: Options) {
        let count = positions.count
        var index = 0
        while index < count {
            guard positions[index] == nil else {
                index += 1
                continue
            }
            var end = index
            while end + 1 < count, positions[end + 1] == nil {
                end += 1
            }
            let runLength = end - index + 1
            let before = index > 0 ? positions[index - 1] : nil
            let after = end + 1 < count ? positions[end + 1] : nil
            let (start, finish): (Double, Double)
            switch (before, after) {
            case (let b?, let a?):
                start = b
                finish = a
            case (let b?, nil):
                // 段の終わり：閉じた段なら最初の目まで均等に。まだ閉じていなければ1つにつき1目分ずつ先へ
                // （1目分に詰めると、アーチの鎖を入力している途中で記号が重なる。AMIZ-58）
                start = b
                if isClosed, let wrap = options.closedWrap, let first = positions.first ?? nil {
                    finish = first + wrap
                } else {
                    finish = b + options.trailingStep * Double(runLength + 1)
                }
            case (nil, let a?):
                start = a - options.leadingSpan(runLength)
                finish = a
            case (nil, nil):
                start = options.fallbackStart
                finish = start + options.previousStep * Double(runLength)
            }
            for (position, stitchIndex) in (index...end).enumerated() {
                positions[stitchIndex] = start + (finish - start) * (Double(position) + 1) / Double(runLength + 1)
            }
            index = end + 1
        }
    }

    /// 終わった段：1目分ずつの等間隔に並べる。全体のずれは「頭と根元のずれの平均が 0」になるように決める
    static func evenlySpaced(
        bases: [[Double]], step: Double, fallbackOffset: Double, mean: ([Double]) -> Double
    ) -> [Double] {
        var offsets: [Double] = []
        for (index, base) in bases.enumerated() where !base.isEmpty {
            offsets.append(mean(base) - step * Double(index))
        }
        let offset = offsets.isEmpty ? fallbackOffset : mean(offsets)
        return (0..<bases.count).map { offset + step * Double($0) }
    }
}

extension ExpandedStitch {
    /// 図に描くときの長さ（鎖○目分）。立ち上がりは鎖の目数、高さのない目は最小の長さ、ピコットは段の高さに含めない
    func drawHeight(lowStitchHeight: Double) -> Double {
        switch role {
        case .turningChain(let chains):
            Double(chains)
        case .closingSlipStitch:
            lowStitchHeight
        case .picot:
            0
        case .regular:
            kind.heightInChains == 0 ? lowStitchHeight : Double(kind.heightInChains)
        }
    }
}
