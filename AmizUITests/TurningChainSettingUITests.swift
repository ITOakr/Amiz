import XCTest

/// 設定「立ち上がりを1目と数える」の最小の UI テスト：「毎回選択」にして目を押すと確認が出る（ui-spec 6-3・7-4）
final class TurningChainSettingUITests: XCTestCase {
    @MainActor
    func testAskEveryTimeShowsQuestion() {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing", "--reset-store"]
        app.launch()

        // 設定で「毎回選択」にする
        let settings = app.buttons["home.settings"]
        XCTAssertTrue(settings.waitForExistence(timeout: 5))
        settings.tap()
        let picker = app.buttons["settings.turningChainCounting"]
        XCTAssertTrue(picker.waitForExistence(timeout: 2))
        picker.tap()
        let ask = app.buttons["毎回選択"]
        XCTAssertTrue(ask.waitForExistence(timeout: 2))
        ask.tap()
        XCTAssertTrue(app.staticTexts["毎回選択：立ち上がりが入るたびに聞く。これから入れる立ち上がりに効き、入力済みの段は変わりません。数え方は目を選択して後から変えられます。"].waitForExistence(timeout: 2))
        snapshot(app, name: "tc-1-settings")
        app.navigationBars.buttons.element(boundBy: 0).tap()

        // 新しい作品で細編みを押す → 確認
        app.buttons["home.newFromEmpty"].tap()
        let nameField = app.textFields["newWork.name"]
        XCTAssertTrue(nameField.waitForExistence(timeout: 2))
        nameField.tap()
        nameField.typeText("テスト")
        app.buttons["newWork.create"].tap()
        let singleCrochet = app.buttons["stitch.singleCrochet"]
        XCTAssertTrue(singleCrochet.waitForExistence(timeout: 5))
        singleCrochet.tap()
        let alert = app.alerts.firstMatch
        XCTAssertTrue(alert.waitForExistence(timeout: 2))
        XCTAssertTrue(alert.staticTexts["立ち上がり鎖1目を1目と数えますか？"].exists)
        snapshot(app, name: "tc-2-question")
        alert.buttons["数える"].tap()
        XCTAssertTrue(app.staticTexts["1段目・この段 2目"].waitForExistence(timeout: 2))

        // 目数表に注記が出る
        for _ in 0..<5 { singleCrochet.tap() }
        app.buttons["op.finishRow"].tap()
        app.buttons["目数表"].tap()
        XCTAssertTrue(app.staticTexts["わの作り目に立ち上がり鎖1目（1目と数える）、細編み6目"].waitForExistence(timeout: 2))
        snapshot(app, name: "tc-3-table")
    }

    @MainActor
    private func snapshot(_ app: XCUIApplication, name: String) {
        guard let dir = ProcessInfo.processInfo.environment["AMIZ_SNAPSHOT_DIR"] else { return }
        try? app.screenshot().pngRepresentation.write(to: URL(fileURLWithPath: dir).appending(path: "\(name).png"))
    }
}
