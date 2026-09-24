import XCTest

/// 玉編みとピコット（ui-spec 5-6、domain-spec TC-13・TC-14）の最小の UI テスト
final class ClusterPicotUITests: XCTestCase {
    @MainActor
    func testClusterRowAndPicotRow() {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing", "--reset-store"]
        app.launch()

        let newButton = app.buttons["home.newFromEmpty"]
        XCTAssertTrue(newButton.waitForExistence(timeout: 5))
        newButton.tap()
        let nameField = app.textFields["newWork.name"]
        XCTAssertTrue(nameField.waitForExistence(timeout: 2))
        nameField.tap()
        nameField.typeText("玉編み")
        app.buttons["newWork.create"].tap()

        let sc = app.buttons["stitch.singleCrochet"], ch = app.buttons["stitch.chain"], hdc = app.buttons["stitch.halfDoubleCrochet"]
        XCTAssertTrue(sc.waitForExistence(timeout: 5))

        // ピコットは直前に目がないと押せない
        XCTAssertFalse(app.buttons["op.picot"].isEnabled)

        // 1段目：細編み12目
        for _ in 0..<12 { sc.tap() }
        XCTAssertTrue(app.staticTexts["1段目・この段 12目"].waitForExistence(timeout: 2))
        app.buttons["op.finishRow"].tap()

        // 2段目（TC-13）：立ち上がり鎖2目 →（鎖1目、中長編み3目の玉編み）×11 → 鎖1目
        app.buttons["op.turningChain"].tap()
        let chains2 = app.buttons["鎖2目"]
        XCTAssertTrue(chains2.waitForExistence(timeout: 3))
        chains2.tap()
        app.buttons["op.beginRepeat"].tap()
        ch.tap()
        app.buttons["modifier.cluster"].tap()
        XCTAssertTrue(app.buttons["modifier.cluster"].label.contains("3目の玉編み"))
        hdc.tap()
        app.buttons["op.endRepeat"].tap()
        let repeatField = app.alerts.textFields.firstMatch
        XCTAssertTrue(repeatField.waitForExistence(timeout: 4))
        setRepeatCount(app, repeatField, "11")
        app.alerts.buttons["この回数で繰り返す"].tap()
        ch.tap()
        XCTAssertTrue(app.staticTexts["2段目・この段 24目"].waitForExistence(timeout: 3))
        snapshot(app, name: "cluster-1-editor")
        app.buttons["op.finishRow"].tap()

        // 3段目（TC-14 相当）：細編み2目、ピコット、（細編み3目、ピコット）×3、細編み1目 → 前段24目なので 1目残るが確認は「このまま終える」
        sc.tap(); sc.tap()
        XCTAssertTrue(app.buttons["op.picot"].isEnabled)
        app.buttons["op.picot"].tap()
        XCTAssertFalse(app.buttons["op.picot"].isEnabled)  // ピコットの直後には付けられない
        app.buttons["op.beginRepeat"].tap()
        sc.tap(); sc.tap(); sc.tap()
        app.buttons["op.picot"].tap()
        app.buttons["op.endRepeat"].tap()
        let repeatField2 = app.alerts.textFields.firstMatch
        XCTAssertTrue(repeatField2.waitForExistence(timeout: 4))
        setRepeatCount(app, repeatField2, "3")
        app.alerts.buttons["この回数で繰り返す"].tap()
        sc.tap()
        XCTAssertTrue(app.staticTexts["3段目・この段 12目"].waitForExistence(timeout: 3))  // ピコットは数えない

        // 目数表
        app.buttons["目数表"].tap()
        XCTAssertTrue(app.staticTexts["立ち上がり鎖2目、（鎖1目、中長編み3目の玉編み）×11、鎖1目"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["合計24目／鎖抜き12目"].exists)
        snapshot(app, name: "cluster-2-table")
    }

    /// 繰り返しの回数の入力欄を消してから入れる
    @MainActor
    private func setRepeatCount(_ app: XCUIApplication, _ field: XCUIElement, _ value: String) {
        field.tap()
        let current = (field.value as? String) ?? ""
        field.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: max(current.count, 1) + 1))
        field.typeText(value)
    }

    @MainActor
    private func snapshot(_ app: XCUIApplication, name: String) {
        guard let dir = ProcessInfo.processInfo.environment["AMIZ_SNAPSHOT_DIR"] else { return }
        try? app.screenshot().pngRepresentation.write(to: URL(fileURLWithPath: dir).appending(path: "\(name).png"))
    }
}
