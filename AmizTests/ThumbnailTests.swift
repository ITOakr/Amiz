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

    @Test("入力中の自動保存ではサムネイルを作らず、画面を閉じるときに作る（AMIZ-70）")
    func thumbnailOnlyOnClose() throws {
        let pattern = SamplePatterns.bearHead
        let work = Work(name: "くま", pattern: pattern)
        // 入力中の保存（サムネイルなし）では前のサムネイルのまま
        try work.save(pattern: pattern, thumbnail: nil)
        #expect(work.thumbnail == nil)
        // 画面を閉じるときの保存で作られる
        try work.save(pattern: pattern, thumbnail: ThumbnailRenderer.png(for: pattern))
        #expect((work.thumbnail?.count ?? 0) > 1000)
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

/// サムネイルの重さ対策（AMIZ-70）
@MainActor
@Suite("サムネイルの重さ")
struct ThumbnailCostTests {
    @Test("目が多い作品は間引いて描く。少ない作品は全部描く")
    func stride() {
        #expect(ThumbnailRenderer.stride(forStitchCount: 0) == 1)
        #expect(ThumbnailRenderer.stride(forStitchCount: 1200) == 1)
        #expect(ThumbnailRenderer.stride(forStitchCount: 2400) == 2)
        #expect(ThumbnailRenderer.stride(forStitchCount: 5000) == 5)
    }

    @Test("5000目の作品でも 0.3 秒以内に作れる（間引きの効果）")
    func costIsBounded() throws {
        let pattern = SamplePatterns.largeDisc(rows: 40)
        let clock = ContinuousClock().now
        let data = try #require(ThumbnailRenderer.png(for: pattern))
        let elapsed = ContinuousClock().now - clock
        #expect(data.count > 1000)
        #expect(elapsed < .milliseconds(300), "サムネイルの生成に \(elapsed) かかりました")
    }
}
