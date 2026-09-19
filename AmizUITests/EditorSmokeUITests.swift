import XCTest

/// 編集画面の最小の UI テスト（tech-spec 11：UI の自動テストは最小限）。
///
/// 通常のテスト（スキーム Amiz）には含めない。確認したいときだけスキーム AmizUITests で実行する。
/// 目的は「ボタンを押すとモデルが動き、画面に反映される」ことの確認で、細かい表示は見ない。
final class EditorSmokeUITests: XCTestCase {
    /// TC-1「くまの頭」の5段をキーボードで入力し、目数表が ui-spec 8章のサンプルと一致することを確かめる
    @MainActor
    func testInputTC1AndReadTable() {
        let app = XCUIApplication()
        app.launch()

        let singleCrochet = app.buttons["stitch.singleCrochet"]
        XCTAssertTrue(singleCrochet.waitForExistence(timeout: 5))

        // 1段目：細編み6目、段を終える
        for _ in 0..<6 { singleCrochet.tap() }
        XCTAssertTrue(app.staticTexts["1段目・この段 6目"].waitForExistence(timeout: 2))
        app.buttons["op.finishRow"].tap()
        XCTAssertTrue(app.staticTexts["2段目・この段 0目"].waitForExistence(timeout: 2))

        // 2段目：残りすべてに＋2目編み入れる → 細編み
        app.buttons["modifier.untilEnd"].tap()
        app.buttons["modifier.increase"].tap()
        singleCrochet.tap()
        XCTAssertTrue(app.staticTexts["2段目・この段 12目"].waitForExistence(timeout: 2))
        app.buttons["op.finishRow"].tap()

        // 3段目：（細編み1目、増し目）×6
        app.buttons["op.beginRepeat"].tap()
        singleCrochet.tap()
        app.buttons["modifier.increase"].tap()
        singleCrochet.tap()
        app.buttons["op.endRepeat"].tap()
        let repeatSix = app.alerts.buttons["×6で繰り返す"]
        XCTAssertTrue(repeatSix.waitForExistence(timeout: 2))
        repeatSix.tap()
        XCTAssertTrue(app.staticTexts["3段目・この段 18目"].waitForExistence(timeout: 2))
        app.buttons["op.finishRow"].tap()

        // 4段目：（細編み2目、増し目）×6
        app.buttons["op.beginRepeat"].tap()
        singleCrochet.tap()
        singleCrochet.tap()
        app.buttons["modifier.increase"].tap()
        singleCrochet.tap()
        app.buttons["op.endRepeat"].tap()
        XCTAssertTrue(repeatSix.waitForExistence(timeout: 2))
        repeatSix.tap()
        XCTAssertTrue(app.staticTexts["4段目・この段 24目"].waitForExistence(timeout: 2))
        app.buttons["op.finishRow"].tap()

        // 5段目：残りすべてに → 細編み、段を終える
        app.buttons["modifier.untilEnd"].tap()
        singleCrochet.tap()
        XCTAssertTrue(app.staticTexts["5段目・この段 24目"].waitForExistence(timeout: 2))
        app.buttons["op.finishRow"].tap()
        XCTAssertTrue(app.staticTexts["6段目・この段 0目"].waitForExistence(timeout: 2))

        // 目数表（ui-spec 8章のサンプルと TC-1）。画面外の行は作られないので、上下にスクロールして確かめる
        let table = app.collectionViews.firstMatch
        XCTAssertTrue(table.waitForExistence(timeout: 2))
        for text in ["（細編み2目、細編み2目編み入れる）×6", "24目", "残りの目すべてに細編み", "入力中"] {
            XCTAssertTrue(app.staticTexts[text].exists, "目数表の下の方に「\(text)」がある")
        }
        table.swipeDown()
        for text in ["わの作り目", "わの作り目に細編み6目", "6目", "細編み2目編み入れる×全目", "12目", "（細編み1目、細編み2目編み入れる）×6", "18目"] {
            XCTAssertTrue(app.staticTexts[text].waitForExistence(timeout: 2), "目数表の上の方に「\(text)」がある")
        }

        // 1目削除で「段を終える」が取り消され、5段目が入力中に戻る
        app.buttons["op.deleteLast"].tap()
        XCTAssertTrue(app.staticTexts["5段目・この段 24目"].waitForExistence(timeout: 2))
    }
}
