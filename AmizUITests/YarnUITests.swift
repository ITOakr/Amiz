import XCTest

/// 糸リストと持ち替え（ui-spec U17・6-1）の最小の UI テスト：糸を追加して持ち替え、目数表に糸名が出る
final class YarnUITests: XCTestCase {
    @MainActor
    func testAddYarnAndChange() {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing", "--reset-store"]
        app.launch()

        // 新規作成（最初の糸は「生成り」のまま）
        let newButton = app.buttons["home.newFromEmpty"]
        XCTAssertTrue(newButton.waitForExistence(timeout: 5))
        newButton.tap()
        let nameField = app.textFields["newWork.name"]
        XCTAssertTrue(nameField.waitForExistence(timeout: 2))
        nameField.tap()
        nameField.typeText("くまの頭")
        app.buttons["newWork.create"].tap()

        // 糸リストを開いて「こげ茶」を追加
        let yarnButton = app.buttons["toolbar.yarn"]
        XCTAssertTrue(yarnButton.waitForExistence(timeout: 5))
        XCTAssertEqual(yarnButton.label, "今持っている糸：生成り")
        yarnButton.tap()
        let add = app.buttons["yarns.add"]
        XCTAssertTrue(add.waitForExistence(timeout: 3))
        add.tap()
        let yarnName = app.textFields["yarn.name"]
        XCTAssertTrue(yarnName.waitForExistence(timeout: 3))
        yarnName.tap()
        yarnName.typeText("こげ茶")
        app.buttons["yarn.save"].tap()
        snapshot(app, name: "yarn-1-list")

        // タップで持ち替え → 閉じる → ツールバーの糸が変わる
        let brownRow = app.buttons["yarns.row.こげ茶"]
        XCTAssertTrue(brownRow.waitForExistence(timeout: 3))
        brownRow.tap()
        app.buttons["yarns.close"].tap()
        XCTAssertTrue(app.buttons["toolbar.yarn"].waitForExistence(timeout: 3))
        XCTAssertEqual(app.buttons["toolbar.yarn"].label, "今持っている糸：こげ茶")

        // こげ茶で細編み6目 → 段を終える → 目数表に「こげ茶で」
        let singleCrochet = app.buttons["stitch.singleCrochet"]
        for _ in 0..<6 { singleCrochet.tap() }
        XCTAssertTrue(app.staticTexts["1段目・この段 6目"].waitForExistence(timeout: 2))
        snapshot(app, name: "yarn-2-editor")
        app.buttons["op.finishRow"].tap()
        XCTAssertTrue(app.openStitchTable(), "目数表が開く")
        XCTAssertTrue(app.waitForTableText("わの作り目にこげ茶で細編み6目"))
    }

    @MainActor
    private func snapshot(_ app: XCUIApplication, name: String) {
        guard let dir = ProcessInfo.processInfo.environment["AMIZ_SNAPSHOT_DIR"] else { return }
        try? app.screenshot().pngRepresentation.write(to: URL(fileURLWithPath: dir).appending(path: "\(name).png"))
    }
}
