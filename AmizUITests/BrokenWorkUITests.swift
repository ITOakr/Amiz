import XCTest

/// 編み図が読めない作品を開いたとき（AMIZ-68）：編集画面を開かず、データを残す
final class BrokenWorkUITests: XCTestCase {
    @MainActor
    func testUnreadableWorkDoesNotOpenEditor() {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing", "--reset-store", "--seed-broken-work"]
        app.launch()

        // 一覧では「開けません」と出る（段数を読めないため）
        XCTAssertTrue(app.staticTexts["壊れた作品"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["輪編み・開けません"].exists)
        app.staticTexts["壊れた作品"].tap()

        // 編集画面は開かず、説明と書き出しボタンが出る
        XCTAssertTrue(app.staticTexts["この作品を開けませんでした"].waitForExistence(timeout: 3))
        XCTAssertFalse(app.buttons["stitch.singleCrochet"].exists)
        XCTAssertTrue(app.buttons["work.exportBroken"].exists)
        snapshot(app, name: "broken-work")

        // 戻っても作品は残っている
        app.navigationBars.buttons.element(boundBy: 0).tap()
        XCTAssertTrue(app.staticTexts["壊れた作品"].waitForExistence(timeout: 3))
    }

    @MainActor
    private func snapshot(_ app: XCUIApplication, name: String) {
        guard let dir = ProcessInfo.processInfo.environment["AMIZ_SNAPSHOT_DIR"] else { return }
        try? app.screenshot().pngRepresentation.write(to: URL(fileURLWithPath: dir).appending(path: "\(name).png"))
    }
}
