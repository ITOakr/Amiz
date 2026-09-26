import XCTest

/// 鎖を輪にした作り目（domain-spec 33。AMIZ-78）の UI テスト：
/// 鎖6目を輪にして輪編みの作品を作り、1段目に長編み16目を編み入れて目数表に出る
final class ChainRingUITests: XCTestCase {
    @MainActor
    func testCreateWorkWithChainRing() {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing", "--reset-store"]
        app.launch()

        // 新規作成：作り目に「鎖を輪にする」を選ぶ → 編み方が輪編みに切り替わる
        let newButton = app.buttons["home.newFromEmpty"]
        XCTAssertTrue(newButton.waitForExistence(timeout: 5))
        newButton.tap()
        let nameField = app.textFields["newWork.name"]
        XCTAssertTrue(nameField.waitForExistence(timeout: 2))
        nameField.tap()
        nameField.typeText("鎖の輪のモチーフ")

        app.buttons["鎖を輪にする"].tap()
        let countField = app.textFields["newWork.ringChainCount"]
        XCTAssertTrue(countField.waitForExistence(timeout: 2))
        XCTAssertTrue(app.staticTexts["鎖6目を輪にして、その中に1段目を編み入れます。1段目は何目でも編み入れられます。"].exists)
        // 作れる組み合わせなので、対応しない旨の文は出ない
        XCTAssertFalse(app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS %@", "今後対応します")
        ).firstMatch.exists)

        let createButton = app.buttons["newWork.create"]
        XCTAssertTrue(createButton.isEnabled)
        createButton.tap()

        // 編集画面：副題が「輪編み・鎖を輪にした作り目」
        let doubleCrochet = app.buttons["stitch.doubleCrochet"]
        XCTAssertTrue(doubleCrochet.waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["輪編み・鎖を輪にした作り目"].exists)

        // 1段目：長編み16目（立ち上がり鎖3目が入って1目と数えるので 15 回押す）。
        // わの作り目と同じく前段の目数に縛られない
        for _ in 0..<15 { doubleCrochet.tap() }
        XCTAssertTrue(app.staticTexts["1段目・この段 16目"].waitForExistence(timeout: 2))
        app.buttons["op.finishRow"].tap()
        XCTAssertTrue(app.staticTexts["2段目・この段 0目"].waitForExistence(timeout: 2))

        // 目数表：作り目の行と1段目。整合性の警告は出ない
        XCTAssertTrue(app.openStitchTable(), "目数表が開く")
        XCTAssertTrue(app.waitForTableText("作り目：鎖6目を輪にする"), "作り目の行が出る")
        XCTAssertTrue(app.staticTexts["鎖の輪の中に立ち上がり鎖3目、長編み15目"].exists)
        XCTAssertFalse(app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS %@", "しか拾っていません")
        ).firstMatch.exists)
    }

    /// 鎖の作り目（1目ずつ拾う）と輪編みの組み合わせは、まだ作れない（AMIZ-79）
    @MainActor
    func testChainFoundationWithRoundsIsNotAvailableYet() {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing", "--reset-store"]
        app.launch()

        let newButton = app.buttons["home.newFromEmpty"]
        XCTAssertTrue(newButton.waitForExistence(timeout: 5))
        newButton.tap()
        XCTAssertTrue(app.buttons["鎖の作り目"].waitForExistence(timeout: 2))
        app.buttons["鎖の作り目"].tap()
        // 鎖の作り目では往復編みに切り替わるので、輪編みに戻す
        app.buttons["輪編み"].tap()

        XCTAssertTrue(app.staticTexts["鎖を1目ずつ拾って輪に編むのは今後対応します。鎖を輪にして中に編み入れるなら「鎖を輪にする」を選んでください。"].exists)
        XCTAssertFalse(app.buttons["newWork.create"].isEnabled)
    }
}
