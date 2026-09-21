import XCTest

/// 作品カードのメニュー（ui-spec 3）：複製・名前の変更・削除
final class HomeMenuUITests: XCTestCase {
    @MainActor
    func testDuplicateRenameDelete() {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing", "--reset-store"]
        app.launch()

        // 作品を1つ作って戻る
        let newButton = app.buttons["home.newFromEmpty"]
        XCTAssertTrue(newButton.waitForExistence(timeout: 5))
        newButton.tap()
        let nameField = app.textFields["newWork.name"]
        XCTAssertTrue(nameField.waitForExistence(timeout: 2))
        nameField.tap()
        nameField.typeText("くま")
        app.buttons["newWork.create"].tap()
        XCTAssertTrue(app.buttons["stitch.singleCrochet"].waitForExistence(timeout: 5))
        app.navigationBars.buttons.element(boundBy: 0).tap()

        // 複製 → 2枚（「くまのコピー」が先頭）
        let card = app.buttons.matching(identifier: "home.work").firstMatch
        XCTAssertTrue(card.waitForExistence(timeout: 5))
        card.press(forDuration: 1.0)
        let duplicate = app.buttons["複製"]
        XCTAssertTrue(duplicate.waitForExistence(timeout: 3))
        duplicate.tap()
        XCTAssertTrue(app.staticTexts["くまのコピー"].waitForExistence(timeout: 3))
        XCTAssertEqual(app.buttons.matching(identifier: "home.work").count, 2)

        // 名前の変更（先頭＝コピー）
        app.buttons.matching(identifier: "home.work").firstMatch.press(forDuration: 1.0)
        let rename = app.buttons["名前の変更"]
        XCTAssertTrue(rename.waitForExistence(timeout: 3))
        rename.tap()
        let field = app.alerts.textFields.firstMatch
        XCTAssertTrue(field.waitForExistence(timeout: 3))
        field.tap()
        field.typeText("2")
        app.alerts.buttons["変更"].tap()
        XCTAssertTrue(app.staticTexts["くまのコピー2"].waitForExistence(timeout: 3))
        snapshot(app, name: "home-1-menu")

        // 削除（確認あり）
        app.buttons.matching(identifier: "home.work").firstMatch.press(forDuration: 1.0)
        let delete = app.buttons["削除"]
        XCTAssertTrue(delete.waitForExistence(timeout: 3))
        delete.tap()
        let confirm = app.buttons["削除"]
        XCTAssertTrue(confirm.waitForExistence(timeout: 3))
        confirm.tap()
        XCTAssertTrue(app.staticTexts["くま"].waitForExistence(timeout: 3))
        XCTAssertFalse(app.staticTexts["くまのコピー2"].exists)
        XCTAssertEqual(app.buttons.matching(identifier: "home.work").count, 1)
    }

    @MainActor
    private func snapshot(_ app: XCUIApplication, name: String) {
        guard let dir = ProcessInfo.processInfo.environment["AMIZ_SNAPSHOT_DIR"] else { return }
        try? app.screenshot().pngRepresentation.write(to: URL(fileURLWithPath: dir).appending(path: "\(name).png"))
    }
}
