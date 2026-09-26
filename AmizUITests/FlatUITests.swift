import XCTest

/// 往復編み（ui-spec 4・5-6、domain-spec 21・33）の最小の UI テスト：
/// 鎖の作り目の目数を入れて作れ、作り目の行に鎖の目数が出て、段ごとに拾う向きが変わる
final class FlatUITests: XCTestCase {
    @MainActor
    func testCreateAndInputFlatRows() {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing", "--reset-store"]
        app.launch()

        // 新規作成：鎖の作り目 20 目 → 往復編みに切り替わる
        let newButton = app.buttons["home.newFromEmpty"]
        XCTAssertTrue(newButton.waitForExistence(timeout: 5))
        newButton.tap()
        let nameField = app.textFields["newWork.name"]
        XCTAssertTrue(nameField.waitForExistence(timeout: 2))
        nameField.tap()
        nameField.typeText("ブランケットの縁")
        app.buttons["鎖の作り目"].tap()
        let countField = app.textFields["newWork.stitchCount"]
        XCTAssertTrue(countField.waitForExistence(timeout: 2))
        XCTAssertTrue(app.staticTexts["実際に編む鎖は、細編みなら鎖21目、長編みなら鎖22目（立ち上がりを含む）。"].exists)
        snapshot(app, name: "flat-1-new")
        app.buttons["newWork.create"].tap()

        // 編集画面：副題が往復編み、立ち上がりボタンは押せる
        let singleCrochet = app.buttons["stitch.singleCrochet"]
        XCTAssertTrue(singleCrochet.waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["往復編み・鎖の作り目"].exists)
        XCTAssertTrue(app.buttons["op.turningChain"].isEnabled)

        // 1段目：細編み20目（立ち上がり鎖1目が入る）→ 段を終える
        for _ in 0..<20 { singleCrochet.tap() }
        XCTAssertTrue(app.staticTexts["1段目・この段 20目"].waitForExistence(timeout: 2))
        app.buttons["op.finishRow"].tap()
        XCTAssertTrue(app.staticTexts["2段目・この段 0目"].waitForExistence(timeout: 2))

        // 2段目：長編み（立ち上がり鎖3目が入って1目と数える）→ 残りすべてに長編み
        app.buttons["stitch.doubleCrochet"].tap()
        XCTAssertTrue(app.staticTexts["2段目・この段 2目"].waitForExistence(timeout: 2))
        app.buttons["modifier.untilEnd"].tap()
        app.buttons["stitch.doubleCrochet"].tap()
        XCTAssertTrue(app.staticTexts["2段目・この段 20目"].waitForExistence(timeout: 2))
        snapshot(app, name: "flat-2-editor")
        app.buttons["op.finishRow"].tap()

        // 目数表：作り目の行に鎖21目
        XCTAssertTrue(app.openStitchTable(), "目数表が開く")
        XCTAssertTrue(app.waitForTableText("作り目：鎖21目"))
        XCTAssertTrue(app.staticTexts["作り目に細編み20目"].exists)
        XCTAssertTrue(app.staticTexts["立ち上がり鎖3目、長編み1目、残りの目すべてに長編み"].exists)
        snapshot(app, name: "flat-3-table")
    }

    @MainActor
    private func snapshot(_ app: XCUIApplication, name: String) {
        guard let dir = ProcessInfo.processInfo.environment["AMIZ_SNAPSHOT_DIR"] else { return }
        try? app.screenshot().pngRepresentation.write(to: URL(fileURLWithPath: dir).appending(path: "\(name).png"))
    }
}
