import XCTest

/// 束に編み入れる（ui-spec 5-6、domain-spec 21、TC-10）の最小の UI テスト：
/// 花のモチーフ 3 段を入力し、3 段目が「束に細編み3目編み入れる×全目」で 36 目になる
final class ChainSpaceUITests: XCTestCase {
    @MainActor
    func testFlowerMotifWithChainSpaces() {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing", "--reset-store"]
        app.launch()

        let newButton = app.buttons["home.newFromEmpty"]
        XCTAssertTrue(newButton.waitForExistence(timeout: 5))
        newButton.tap()
        let nameField = app.textFields["newWork.name"]
        XCTAssertTrue(nameField.waitForExistence(timeout: 2))
        nameField.tap()
        nameField.typeText("花のモチーフ")
        app.buttons["newWork.create"].tap()

        let doubleCrochet = app.buttons["stitch.doubleCrochet"]
        let chain = app.buttons["stitch.chain"]
        let singleCrochet = app.buttons["stitch.singleCrochet"]
        XCTAssertTrue(doubleCrochet.waitForExistence(timeout: 5))

        // 1段目：長編み12目（立ち上がり鎖3目が入って1目と数える）→ 11 回押す
        for _ in 0..<11 { doubleCrochet.tap() }
        XCTAssertTrue(app.staticTexts["1段目・この段 12目"].waitForExistence(timeout: 2))
        app.buttons["op.finishRow"].tap()

        // 2段目：鎖2 →（長編み、鎖2）を段の終わりまで。最初の長編みを押したときに立ち上がり鎖3目（1目と数える）が
        // 段の先頭に入り、TC-4 の「立ち上がり鎖3目、鎖2目、（長編み1目、鎖2目）×11」になる
        chain.tap()
        chain.tap()
        app.buttons["op.beginRepeat"].tap()
        doubleCrochet.tap()
        chain.tap()
        chain.tap()
        app.buttons["op.endRepeat"].tap()
        let untilEnd = app.alerts.buttons["段の終わりまで"]
        XCTAssertTrue(untilEnd.waitForExistence(timeout: 4))
        untilEnd.tap()
        XCTAssertTrue(app.staticTexts["2段目・この段 36目"].waitForExistence(timeout: 2))
        app.buttons["op.finishRow"].tap()

        // 3段目：残りすべてに＋束に＋2目編み入れる×2（3目）→ 細編み
        app.buttons["modifier.untilEnd"].tap()
        app.buttons["modifier.chainSpace"].tap()
        app.buttons["modifier.increase"].tap()
        app.buttons["modifier.increase"].tap()
        singleCrochet.tap()
        XCTAssertTrue(app.staticTexts["3段目・この段 36目"].waitForExistence(timeout: 5))
        snapshot(app, name: "motif-1-editor")
        app.buttons["op.finishRow"].tap()
        XCTAssertTrue(app.staticTexts["4段目・この段 0目"].waitForExistence(timeout: 2))

        // 目数表：3段目の文と目数、警告なし
        app.buttons["目数表"].tap()
        XCTAssertTrue(app.staticTexts["束に細編み3目編み入れる×全目"].waitForExistence(timeout: 2))
        // 2段目も合計36目なので「増減なし」が付く
        XCTAssertTrue(app.staticTexts["36目（増減なし）"].exists)
        XCTAssertFalse(app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "しか拾っていません")).firstMatch.exists)
        snapshot(app, name: "motif-2-table")
    }

    @MainActor
    private func snapshot(_ app: XCUIApplication, name: String) {
        guard let dir = ProcessInfo.processInfo.environment["AMIZ_SNAPSHOT_DIR"] else { return }
        try? app.screenshot().pngRepresentation.write(to: URL(fileURLWithPath: dir).appending(path: "\(name).png"))
    }
}
