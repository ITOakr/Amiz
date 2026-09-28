import XCTest

/// 使い方の案内（ui-spec 7-5。AMIZ-86）を最初から最後まで通す
final class TutorialUITests: XCTestCase {
    /// 案内を出して起動する（`--tutorial` で、UI テストでも案内のおすすめを出す）
    @MainActor
    private func launchWithTutorial() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing", "--reset-store", "--tutorial"]
        app.launch()
        return app
    }

    /// 案内の説明文が出ていること
    @MainActor
    private func message(_ app: XCUIApplication) -> XCUIElement {
        app.staticTexts["tutorial.message"]
    }

    @MainActor
    func testFollowTutorialToTheEnd() {
        let app = launchWithTutorial()

        // 初回のおすすめ →「使い方を見る」
        let accept = app.buttons["使い方を見る"]
        XCTAssertTrue(accept.waitForExistence(timeout: 5), "初回に案内のおすすめが出る")
        accept.tap()
        XCTAssertTrue(message(app).waitForExistence(timeout: 2), "説明の帯が出る")
        attach(app, name: "tutorial-1-home")

        // 1〜2. 新規作成 → 作成（案内が名前を用意している）
        app.buttons["home.new"].tap()
        let create = app.buttons["newWork.create"]
        XCTAssertTrue(create.waitForExistence(timeout: 2))
        attach(app, name: "tutorial-2-new")
        create.tap()

        // 3〜4. 1段目：細編み6回 → 段を終える
        let singleCrochet = app.buttons["stitch.singleCrochet"]
        XCTAssertTrue(singleCrochet.waitForExistence(timeout: 5))
        attach(app, name: "tutorial-3-first-row")
        for _ in 0..<6 { singleCrochet.tap() }
        XCTAssertTrue(app.staticTexts["1段目・この段 6目"].waitForExistence(timeout: 2))
        app.buttons["op.finishRow"].tap()

        // 5〜8. 2段目：全目に → 増し目 → 細編み → 段を終える
        app.buttons["modifier.untilEnd"].tap()
        app.buttons["modifier.increase"].tap()
        singleCrochet.tap()
        XCTAssertTrue(app.staticTexts["2段目・この段 12目"].waitForExistence(timeout: 2))
        app.buttons["op.finishRow"].tap()

        // 9〜13. 3段目：繰り返し（細編み1目、増し目）×6
        app.buttons["op.beginRepeat"].tap()
        singleCrochet.tap()
        app.buttons["modifier.increase"].tap()
        singleCrochet.tap()
        attach(app, name: "tutorial-4-repeat")
        app.buttons["op.endRepeat"].tap()
        let repeatButton = app.alerts.buttons["この回数で繰り返す"]
        XCTAssertTrue(repeatButton.waitForExistence(timeout: 4))
        repeatButton.tap()
        XCTAssertTrue(app.staticTexts["3段目・この段 18目"].waitForExistence(timeout: 2))

        // 14. 段を終える
        app.buttons["op.finishRow"].tap()

        // 15. 目数表を見る
        XCTAssertTrue(app.openStitchTable(), "目数表が開く")
        XCTAssertTrue(app.waitForTableText("わの作り目に細編み6目"), "1段目の手順が出る")

        // 16. 終わり
        let finish = app.buttons["tutorial.finish"]
        XCTAssertTrue(finish.waitForExistence(timeout: 3), "最後のステップで「終わる」が出る")
        attach(app, name: "tutorial-5-done")
        finish.tap()
        XCTAssertFalse(message(app).exists, "案内が消える")

        // 作った編み図は「コースター（練習）」として残る
        XCTAssertTrue(app.staticTexts["12目（増減なし）"].exists || app.staticTexts["18目"].exists
                      || app.waitForTableText("18目"), "3段目の目数が出ている")
        app.navigationBars.buttons.firstMatch.tap()  // 作品一覧へ戻る
        XCTAssertTrue(app.staticTexts["コースター（練習）"].waitForExistence(timeout: 3), "作品として残る")
    }

    @MainActor
    func testSkipAndRestartFromSettings() {
        let app = launchWithTutorial()

        // スキップしても編み図は壊れない（まだ何も作っていないのでホームのまま）
        let accept = app.buttons["使い方を見る"]
        XCTAssertTrue(accept.waitForExistence(timeout: 5))
        accept.tap()
        XCTAssertTrue(message(app).waitForExistence(timeout: 2))
        app.buttons["tutorial.skip"].tap()
        XCTAssertFalse(message(app).exists, "案内が消える")

        // 設定から開き直せる
        app.buttons["home.settings"].tap()
        let restart = app.buttons["settings.tutorial"]
        XCTAssertTrue(restart.waitForExistence(timeout: 2), "設定に「使い方をもう一度見る」がある")
        restart.tap()
        XCTAssertTrue(message(app).waitForExistence(timeout: 3), "案内がまた出る")
    }

    @MainActor
    func testTutorialDoesNotAppearAfterItWasSeen() {
        // 1回目：案内を出してスキップする
        let first = launchWithTutorial()
        XCTAssertTrue(first.buttons["使い方を見る"].waitForExistence(timeout: 5))
        first.buttons["あとで"].tap()
        first.terminate()

        // 2回目：作品がなくても自動では出ない（--tutorial を渡さない）
        let second = XCUIApplication()
        second.launchArguments = ["--ui-testing"]
        second.launch()
        XCTAssertTrue(second.buttons["home.settings"].waitForExistence(timeout: 5))
        XCTAssertFalse(second.buttons["使い方を見る"].exists, "2回目は自動で出ない")
    }

    /// 確認用のスクリーンショットをテスト結果に付ける
    @MainActor
    private func attach(_ app: XCUIApplication, name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
