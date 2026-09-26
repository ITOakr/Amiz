import Foundation
import ImageIO
import Testing
import CrochetCore
@testable import Amiz

/// 作品カードのサムネイル（ui-spec 3）
@MainActor
@Suite("サムネイル")
struct ThumbnailTests {
    @Test("編み図から 320px 四方の PNG ができ、表示用の画像に戻せる。空の編み図は nil")
    func render() throws {
        let data = try #require(ThumbnailRenderer.png(for: SamplePatterns.bearHeadColored))
        #expect(data.count > 1000)
        let source = try #require(CGImageSourceCreateWithData(data as CFData, nil))
        let image = try #require(CGImageSourceCreateImageAtIndex(source, 0, nil))
        #expect(image.width == 320 && image.height == 320)
        #expect(ThumbnailRenderer.image(from: data) != nil)

        #expect(ThumbnailRenderer.png(for: Pattern(method: .joinedRounds, foundation: .magicRing)) == nil)
        #expect(ThumbnailRenderer.image(from: Data([0, 1, 2])) == nil)
    }

    @Test("保存するとサムネイルが作品に入る")
    func savedWithWork() throws {
        let work = Work(name: "くま", pattern: SamplePatterns.bearHead)
        #expect(work.thumbnail == nil)
        try work.save(pattern: SamplePatterns.bearHead, thumbnail: ThumbnailRenderer.png(for: SamplePatterns.bearHead))
        #expect((work.thumbnail?.count ?? 0) > 1000)
        // サムネイルを渡さない保存では前のものが残る
        let previous = work.thumbnail
        try work.save(pattern: SamplePatterns.bearHead)
        #expect(work.thumbnail == previous)
    }
}
