import XCTest

/// 螺旋編み（ui-spec 4・5-6、domain-spec 5）の最小の UI テスト：
/// 新規作成で選べ、立ち上がりが入らず、「段を終える」で次の段へ進むだけ
final class SpiralUITests: XCTestCase {
    @MainActor
    func testCreateAndInputSpiralRows() {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing", "--reset-store"]
        app.launch()

        // 新規作成：螺旋編み
        let newButton = app.buttons["home.newFromEmpty"]
        XCTAssertTrue(newButton.waitForExistence(timeout: 5))
        newButton.tap()
        let nameField = app.textFields["newWork.name"]
        XCTAssertTrue(nameField.waitForExistence(timeout: 2))
        nameField.tap()
        nameField.typeText("うさぎの胴体")
        app.buttons["螺旋編み"].tap()
        app.buttons["newWork.create"].tap()

        // 編集画面：副題が螺旋編み、立ち上がりボタンは押せない
        let singleCrochet = app.buttons["stitch.singleCrochet"]
        XCTAssertTrue(singleCrochet.waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["螺旋編み・わの作り目"].exists)
        XCTAssertFalse(app.buttons["op.turningChain"].isEnabled)

        // 1段目：細編み6目 → 立ち上がりは入らない
        for _ in 0..<6 { singleCrochet.tap() }
        XCTAssertTrue(app.staticTexts["1段目・この段 6目"].waitForExistence(timeout: 2))
        XCTAssertFalse(app.staticTexts["立ち上がり鎖1"].exists)
        app.buttons["op.finishRow"].tap()
        XCTAssertTrue(app.staticTexts["2段目・この段 0目"].waitForExistence(timeout: 2))

        // 2段目：残りすべてに増し目 → 12目
        app.buttons["modifier.untilEnd"].tap()
        app.buttons["modifier.increase"].tap()
        singleCrochet.tap()
        XCTAssertTrue(app.staticTexts["2段目・この段 12目"].waitForExistence(timeout: 2))
        XCTAssertFalse(app.staticTexts["立ち上がり鎖1"].exists)
        snapshot(app, name: "spiral-1-editor")
        app.buttons["op.finishRow"].tap()
        XCTAssertTrue(app.staticTexts["3段目・この段 0目"].waitForExistence(timeout: 2))

        // 目数表
        XCTAssertTrue(app.openStitchTable(), "目数表が開く")
        XCTAssertTrue(app.waitForTableText("わの作り目に細編み6目"))
        XCTAssertTrue(app.staticTexts["細編み2目編み入れる×全目"].exists)
        XCTAssertTrue(app.staticTexts["12目"].exists)
        snapshot(app, name: "spiral-2-table")

        // 作品一覧に戻ると「螺旋編み・3段目まで」（入力中の3段目を含む）
        app.navigationBars.buttons.element(boundBy: 0).tap()
        XCTAssertTrue(app.staticTexts["螺旋編み・3段目まで"].waitForExistence(timeout: 3))
    }

    @MainActor
    private func snapshot(_ app: XCUIApplication, name: String) {
        guard let dir = ProcessInfo.processInfo.environment["AMIZ_SNAPSHOT_DIR"] else { return }
        try? app.screenshot().pngRepresentation.write(to: URL(fileURLWithPath: dir).appending(path: "\(name).png"))
    }
}
