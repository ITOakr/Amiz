import XCTest

/// iPad の配置（ui-spec 5-2）の確認。iPhone では飛ばす。
/// 横向きでは図と目数表が同時に出て（タブがない）、右のレールにキーボードがある。スクリーンショットを結果に添付する。
final class IPadLayoutUITests: XCTestCase {
    @MainActor
    func testLandscapeShowsChartAndTableWithRail() throws {
        try XCTSkipUnless(UIDevice.current.userInterfaceIdiom == .pad, "iPad の配置の確認なので iPhone では飛ばす")

        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing", "--reset-store"]
        app.launchEnvironment = ["AMIZ_SCREEN": "sample"]
        app.launch()

        XCUIDevice.shared.orientation = .landscapeLeft
        XCTAssertTrue(app.buttons["stitch.singleCrochet"].waitForExistence(timeout: 5))
        // 横向き：タブがなく、図と目数表が同時に見える
        XCTAssertFalse(app.buttons["目数表"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.staticTexts["わの作り目に細編み6目"].exists)
        XCTAssertTrue(app.staticTexts["5段目・この段 4目"].exists)
        attachScreenshot(named: "ipad-landscape")

        // 縦向き：タブがある
        XCUIDevice.shared.orientation = .portrait
        XCTAssertTrue(app.buttons["目数表"].waitForExistence(timeout: 3))
        attachScreenshot(named: "ipad-portrait")

        // 横向きに戻して終える（テスト後にシミュレーターで横向きの確認ができるように）
        XCUIDevice.shared.orientation = .landscapeLeft
        XCTAssertFalse(app.buttons["目数表"].waitForExistence(timeout: 2))
    }

    @MainActor
    private func attachScreenshot(named name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
