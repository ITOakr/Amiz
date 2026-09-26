import Foundation
import SwiftData
import Testing
@testable import Amiz

/// 保存先が開けないときの回復（AMIZ-69）
@MainActor
@Suite("保存先の回復")
struct WorkStoreTests {
    /// テスト用の一時フォルダ
    private func makeDirectory() throws -> URL {
        let url = URL.temporaryDirectory.appending(path: "amiz-store-test-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    @Test("普通に開けるときは警告なし")
    func opensNormally() throws {
        let directory = try makeDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let result = WorkStore.open(at: directory.appending(path: "default.store"))
        #expect(result.warning == nil)
        result.container.mainContext.insert(Work(name: "作品", pattern: SamplePatterns.bearHead))
        #expect(throws: Never.self) { try result.container.mainContext.save() }
    }

    @Test("壊れた保存先は退避して作り直し、説明を返す。前のファイルは残る")
    func recoversFromBrokenStore() throws {
        let directory = try makeDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appending(path: "default.store")
        // SQLite として読めないファイルを置く
        try Data("これは壊れた保存先です".utf8).write(to: url)

        let result = WorkStore.open(at: url)
        let warning = try #require(result.warning)
        #expect(warning.contains("破損"))
        // 新しい保存先は使える
        result.container.mainContext.insert(Work(name: "作品", pattern: SamplePatterns.bearHead))
        #expect(throws: Never.self) { try result.container.mainContext.save() }
        // 退避したファイルが残っている
        let files = try FileManager.default.contentsOfDirectory(atPath: directory.path)
        #expect(files.contains { $0.contains("破損") })
    }

    @Test("退避の名前には日時が入り、付属ファイルも一緒に動く")
    func moveAside() throws {
        let directory = try makeDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appending(path: "default.store")
        try Data("本体".utf8).write(to: url)
        try Data("wal".utf8).write(to: URL(filePath: url.path + "-wal"))

        let date = Date(timeIntervalSince1970: 1_800_000_000)
        let moved = try #require(WorkStore.moveAside(url, now: date))
        #expect(moved.lastPathComponent.hasPrefix("default-破損-"))
        #expect(moved.pathExtension == "store")
        #expect(FileManager.default.fileExists(atPath: moved.path))
        #expect(FileManager.default.fileExists(atPath: moved.path + "-wal"))
        #expect(!FileManager.default.fileExists(atPath: url.path))

        // ファイルがなければ退避しない
        #expect(WorkStore.moveAside(directory.appending(path: "ない.store")) == nil)
    }
}
