import Foundation
import Testing
import SwiftData
import CrochetCore
@testable import Amiz

// SwiftData の mainContext はメインスレッド専用なので、テストもメインで動かす
@MainActor
@Suite("作品の保存（SwiftData）")
struct WorkPersistenceTests {
    /// テストごとにメモリ上の保存先を作る（ファイルに残さない）
    private func makeContainer() throws -> ModelContainer {
        try ModelContainer(for: Work.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
    }

    @Test("保存 → 読み込みで編み図が等しい")
    func saveAndLoad() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let original = SamplePatterns.bearHead

        let work = Work(name: "くまの頭", pattern: original)
        context.insert(work)
        try context.save()

        let loaded = try context.fetch(FetchDescriptor<Work>())
        #expect(loaded.count == 1)
        #expect(loaded.first?.name == "くまの頭")
        #expect(loaded.first?.method == .joinedRounds)
        #expect(loaded.first?.loadPattern() == original)
    }

    @Test("save(pattern:) で編み図と更新日が更新される")
    func update() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let work = Work(name: "作品", pattern: Pattern(method: .joinedRounds, foundation: .magicRing))
        context.insert(work)
        let before = work.updatedAt

        var pattern = work.loadPattern()!
        PatternInput.addStitch(.singleCrochet, to: &pattern)
        work.save(pattern: pattern)
        try context.save()

        #expect(work.loadPattern()?.rows.count == 1)
        #expect(work.updatedAt >= before)
    }

    @Test("壊れた JSON は nil になる（クラッシュしない）")
    func corruptedData() {
        let work = Work(name: "壊れた作品", pattern: Pattern(method: .joinedRounds, foundation: .magicRing))
        work.patternData = Data("not json".utf8)
        #expect(work.loadPattern() == nil)
    }
}
