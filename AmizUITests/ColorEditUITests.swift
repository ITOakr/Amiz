import XCTest

/// 色編集モード（ui-spec U21）の最小の UI テスト：モードに入り、糸を追加して段を塗り、完了する
final class ColorEditUITests: XCTestCase {
    @MainActor
    func testPaintRowInColorEditMode() {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing"]
        app.launchEnvironment = ["AMIZ_SCREEN": "sample"]  // くまの頭（糸は既定の1本）
        app.launch()

        // メニュー → 色を編集 → パレットが出る
        let more = app.buttons["toolbar.more"]
        XCTAssertTrue(more.waitForExistence(timeout: 5))
        more.tap()
        let colorEdit = app.buttons["menu.colorEdit"]
        XCTAssertTrue(colorEdit.waitForExistence(timeout: 2))
        colorEdit.tap()
        XCTAssertTrue(app.buttons["palette.done"].waitForExistence(timeout: 3))
        XCTAssertFalse(app.buttons["stitch.singleCrochet"].exists)

        // 糸を追加（こげ茶）→ 追加した糸が選ばれる
        app.buttons["palette.add"].tap()
        let yarnName = app.textFields["yarn.name"]
        XCTAssertTrue(yarnName.waitForExistence(timeout: 3))
        yarnName.tap()
        yarnName.typeText("こげ茶")
        app.buttons["yarn.save"].tap()
        XCTAssertTrue(app.buttons["palette.yarn.こげ茶"].waitForExistence(timeout: 3))
        XCTAssertEqual(app.buttons["palette.yarn.こげ茶"].label, "こげ茶（選択中）")
        snapshot(app, name: "color-1-palette")

        // 目数表で2段目をタップ → 段全体がこげ茶 → 文に糸名
        XCTAssertTrue(app.openStitchTable(), "目数表が開く")
        let row2 = app.buttons["table.row.2"]
        XCTAssertTrue(row2.waitForExistence(timeout: 3))
        row2.tap()
        XCTAssertTrue(app.waitForTableText("こげ茶で細編み2目編み入れる×全目"))
        XCTAssertTrue(app.staticTexts["メインで（細編み1目、細編み2目編み入れる）×6"].exists)
        snapshot(app, name: "color-2-table")

        // 完了 → キーボードに戻る
        app.buttons["palette.done"].tap()
        XCTAssertTrue(app.buttons["stitch.singleCrochet"].waitForExistence(timeout: 3))
    }

    @MainActor
    private func snapshot(_ app: XCUIApplication, name: String) {
        guard let dir = ProcessInfo.processInfo.environment["AMIZ_SNAPSHOT_DIR"] else { return }
        try? app.screenshot().pngRepresentation.write(to: URL(fileURLWithPath: dir).appending(path: "\(name).png"))
    }
}
