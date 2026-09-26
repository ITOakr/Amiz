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
        #expect(try loaded.first?.loadPattern() == original)
    }

    @Test("save(pattern:) で編み図と更新日が更新される")
    func update() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let work = Work(name: "作品", pattern: Pattern(method: .joinedRounds, foundation: .magicRing))
        context.insert(work)
        let before = work.updatedAt

        var pattern = try work.loadPattern()
        PatternInput.addStitch(.singleCrochet, to: &pattern)
        try work.save(pattern: pattern)
        try context.save()

        #expect(try work.loadPattern().rows.count == 1)
        #expect(work.updatedAt >= before)
    }

    @Test("壊れた JSON は読み込みエラーになり、空の編み図で上書きしない（AMIZ-68）")
    func corruptedData() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let work = Work(name: "壊れた作品", pattern: Pattern(method: .joinedRounds, foundation: .magicRing))
        work.patternData = Data("not json".utf8)
        context.insert(work)

        #expect(throws: Work.StorageError.self) {
            _ = try work.loadPattern()
        }
        // 画面は編み図を読めたときだけ開くので、壊れたデータはそのまま残る
        #expect(work.patternData == Data("not json".utf8))

        // 負の目数（AMIZ-67）でも同じく読み込みエラーで、上書きしない
        let invalid = Data(#"{"schemaVersion":2,"method":"joinedRounds","foundation":{"type":"magicRing"},"yarns":[],"rows":[{"id":"00000000-0000-0000-0000-000000000001","steps":[{"id":"00000000-0000-0000-0000-000000000011","type":"increase","stitch":"singleCrochet","count":-3,"into":"stitch"}]}]}"#.utf8)
        work.patternData = invalid
        #expect(throws: Work.StorageError.self) {
            _ = try work.loadPattern()
        }
        #expect(work.patternData == invalid)
    }

    @Test("保存できないときは理由を返す（黙って捨てない。AMIZ-68）")
    func saveFailureIsReported() throws {
        // 保存先に結び付いていない（modelContext が nil の）作品でも、JSON 化はできるので投げない
        let pattern = SamplePatterns.bearHead
        let work = Work(name: "未挿入", pattern: pattern)
        #expect(throws: Never.self) {
            try work.save(pattern: pattern)
        }

        // 作品を保存先に入れてからの保存は成功し、読み戻せる
        let container = try makeContainer()
        container.mainContext.insert(work)
        try work.save(pattern: pattern)
        #expect(try work.loadPattern() == pattern)
    }
}
