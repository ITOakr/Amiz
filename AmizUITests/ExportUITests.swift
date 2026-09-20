import XCTest

/// 書き出し（ui-spec 6-2・7-3）の最小の UI テスト。メニュー → 確認 → シート → 共有シートが開くところまで
final class ExportUITests: XCTestCase {
    /// 「くまの頭」（5段目が入力途中で、目数の警告がある）を開く
    @MainActor
    func testExportFlowWithConfirmation() {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing"]
        app.launchEnvironment = ["AMIZ_SCREEN": "sample"]
        app.launch()

        let more = app.buttons["toolbar.more"]
        XCTAssertTrue(more.waitForExistence(timeout: 5))
        more.tap()
        let export = app.buttons["menu.export"]
        XCTAssertTrue(export.waitForExistence(timeout: 2))
        export.tap()

        // 7-3 の確認
        let alert = app.alerts.firstMatch
        XCTAssertTrue(alert.waitForExistence(timeout: 2))
        XCTAssertTrue(alert.staticTexts["目数が合っていない段があります（5段目）。このまま書き出しますか？"].exists)
        snapshot(app, name: "export-1-confirm")
        alert.buttons["書き出す"].tap()

        // 書き出しシート：PDF・2ページ、書き出しボタンが押せる
        let share = app.buttons["export.share"]
        XCTAssertTrue(share.waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["A4 の PDF、2ページ"].exists)
        snapshot(app, name: "export-2-sheet")

        // 画像に切り替えると作り直される
        app.segmentedControls["export.format"].buttons["画像"].tap()
        XCTAssertTrue(app.staticTexts["A4 2ページぶんを縦に並べた画像"].waitForExistence(timeout: 5))
        XCTAssertTrue(share.waitForExistence(timeout: 5))

        // 共有シートが開く
        share.tap()
        let activity = app.otherElements["ActivityListView"]
        XCTAssertTrue(activity.waitForExistence(timeout: 5))
        snapshot(app, name: "export-3-share")
    }

    /// 確認用のスクリーンショット（環境変数 AMIZ_SNAPSHOT_DIR があればそこへ保存）
    @MainActor
    private func snapshot(_ app: XCUIApplication, name: String) {
        guard let dir = ProcessInfo.processInfo.environment["AMIZ_SNAPSHOT_DIR"] else { return }
        let data = app.screenshot().pngRepresentation
        try? data.write(to: URL(fileURLWithPath: dir).appending(path: "\(name).png"))
    }
}
