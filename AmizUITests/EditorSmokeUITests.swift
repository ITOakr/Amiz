import XCTest

/// 編集画面の最小の UI テスト（tech-spec 11：UI の自動テストは最小限）。
///
/// 通常のテスト（スキーム Amiz）には含めない。確認したいときだけスキーム AmizUITests で実行する。
/// 目的は「ボタンを押すとモデルが動き、画面に反映される」ことの確認で、細かい表示は見ない。
final class EditorSmokeUITests: XCTestCase {
    @MainActor
    func testInputRowsAndFinish() {
        let app = XCUIApplication()
        app.launch()

        // 1段目：細編み6目
        let singleCrochet = app.buttons["stitch.singleCrochet"]
        XCTAssertTrue(singleCrochet.waitForExistence(timeout: 5))
        for _ in 0..<6 { singleCrochet.tap() }
        XCTAssertTrue(app.staticTexts["1段目　この段 6目"].waitForExistence(timeout: 2))

        // 段を終える → 2段目
        app.buttons["op.finishRow"].tap()
        XCTAssertTrue(app.staticTexts["2段目　この段 0目"].waitForExistence(timeout: 2))

        // 2段目：残りすべてに＋2目編み入れる → 細編み ＝ 12目
        app.buttons["modifier.untilEnd"].tap()
        app.buttons["modifier.increase"].tap()
        singleCrochet.tap()
        XCTAssertTrue(app.staticTexts["2段目　この段 12目"].waitForExistence(timeout: 2))

        // 1目削除で繰り返しごと消える → 0目（立ち上がりだけ残る）
        app.buttons["op.deleteLast"].tap()
        XCTAssertTrue(app.staticTexts["2段目　この段 0目"].waitForExistence(timeout: 2))
    }
}
