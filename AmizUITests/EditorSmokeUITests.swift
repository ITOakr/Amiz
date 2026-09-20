import XCTest

/// 編集画面の最小の UI テスト（tech-spec 11：UI の自動テストは最小限）。
///
/// 通常のテスト（スキーム Amiz）には含めない。確認したいときだけスキーム AmizUITests で実行する。
/// 目的は「ボタンを押すとモデルが動き、画面に反映される」ことの確認で、細かい表示は見ない。
final class EditorSmokeUITests: XCTestCase {
    /// 保存先を空にして起動する（前のテストの作品が残らないように）
    @MainActor
    private func launchFresh() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing", "--reset-store"]
        app.launch()
        return app
    }

    /// 作品一覧（空）から新規作成して編集画面を開く
    @MainActor
    private func createWork(in app: XCUIApplication, name: String = "テスト") {
        let newButton = app.buttons["home.newFromEmpty"]
        XCTAssertTrue(newButton.waitForExistence(timeout: 5))
        newButton.tap()
        let nameField = app.textFields["newWork.name"]
        XCTAssertTrue(nameField.waitForExistence(timeout: 2))
        nameField.tap()
        nameField.typeText(name)
        app.buttons["newWork.create"].tap()
    }

    /// TC-1「くまの頭」の5段をキーボードで入力し、目数表が ui-spec 8章のサンプルと一致することを確かめる
    @MainActor
    func testInputTC1AndReadTable() {
        let app = launchFresh()
        createWork(in: app, name: "くまの頭")

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

        // 目数表（ui-spec 8章のサンプルと TC-1）。図タブから切り替え、画面外の行は作られないので上下にスクロールして確かめる
        app.buttons["目数表"].tap()
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

    /// 段を終えるときの確認（ui-spec 7-2）と拾いすぎ（domain-spec 23）
    @MainActor
    func testFinishRowConfirmation() {
        let app = launchFresh()
        createWork(in: app)

        let singleCrochet = app.buttons["stitch.singleCrochet"]
        XCTAssertTrue(singleCrochet.waitForExistence(timeout: 5))
        let finish = app.buttons["op.finishRow"]

        // 1段目：6目
        for _ in 0..<6 { singleCrochet.tap() }
        finish.tap()

        // 2段目：3目だけ編んで終える → 確認 → 戻って続ける
        for _ in 0..<3 { singleCrochet.tap() }
        finish.tap()
        let alert = app.alerts.firstMatch
        XCTAssertTrue(alert.waitForExistence(timeout: 2))
        XCTAssertTrue(alert.staticTexts["前段6目のうち、あと3目残っています。"].exists)
        alert.buttons["戻って続ける"].tap()
        XCTAssertTrue(app.staticTexts["2段目・この段 3目"].waitForExistence(timeout: 2))

        // このまま終える → 目数表に警告
        finish.tap()
        XCTAssertTrue(alert.waitForExistence(timeout: 2))
        alert.buttons["このまま終える"].tap()
        app.buttons["目数表"].tap()
        XCTAssertTrue(app.staticTexts["前段6目のうち3目しか拾っていません"].waitForExistence(timeout: 2))

        // 3段目：2目編んで 残りは編まない → 警告なし
        singleCrochet.tap()
        singleCrochet.tap()
        finish.tap()
        XCTAssertTrue(alert.waitForExistence(timeout: 2))
        alert.buttons["残りは編まない"].tap()
        XCTAssertTrue(app.staticTexts["4段目・この段 0目"].waitForExistence(timeout: 2))
        XCTAssertFalse(app.staticTexts["前段3目のうち2目しか拾っていません"].exists)

        // 4段目：前段2目を使い切ると表示が出て、さらに編んで終えると確認なしで拾いすぎの警告
        singleCrochet.tap()
        singleCrochet.tap()
        XCTAssertTrue(app.staticTexts["前段を使い切りました"].waitForExistence(timeout: 2))
        singleCrochet.tap()
        finish.tap()
        XCTAssertFalse(alert.exists)
        XCTAssertTrue(app.staticTexts["前段2目に対して3目拾っています"].waitForExistence(timeout: 2))
    }

    /// 自動保存：入力してアプリを終了・再起動しても、同じ作品が入力中の段から続けられる（tech-spec 6）
    @MainActor
    func testPatternPersistsAcrossLaunches() {
        let app = launchFresh()
        createWork(in: app, name: "保存の確認")
        let singleCrochet = app.buttons["stitch.singleCrochet"]
        XCTAssertTrue(singleCrochet.waitForExistence(timeout: 5))
        for _ in 0..<6 { singleCrochet.tap() }
        app.buttons["op.finishRow"].tap()
        for _ in 0..<3 { singleCrochet.tap() }
        XCTAssertTrue(app.staticTexts["2段目・この段 3目"].waitForExistence(timeout: 2))

        // 自動保存の待ち（0.4秒）より長く待ってから終了
        sleep(2)
        app.terminate()

        // 保存先を消さずに再起動 → 作品一覧にカードがあり、開くと続きから
        app.launchArguments = ["--ui-testing"]
        app.launch()
        let card = app.buttons["home.work"].firstMatch
        XCTAssertTrue(card.waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["保存の確認"].exists)
        XCTAssertTrue(app.staticTexts["輪編み・2段目まで"].exists)
        card.tap()
        XCTAssertTrue(app.staticTexts["2段目・この段 3目"].waitForExistence(timeout: 5))
        singleCrochet.tap()
        XCTAssertTrue(app.staticTexts["2段目・この段 4目"].waitForExistence(timeout: 2))
    }

    /// 目の選択（U15）：現在の段の項目をタップして種類を変え、削除する
    @MainActor
    func testSelectStitchAndChangeKind() {
        let app = launchFresh()
        createWork(in: app)
        let singleCrochet = app.buttons["stitch.singleCrochet"]
        XCTAssertTrue(singleCrochet.waitForExistence(timeout: 5))
        for _ in 0..<3 { singleCrochet.tap() }

        // 直前の項目（細編み）をタップ → 選択バーが出る
        app.buttons["細編み"].firstMatch.tap()
        XCTAssertTrue(app.staticTexts["selection.description"].waitForExistence(timeout: 2))
        XCTAssertEqual(app.staticTexts["selection.description"].label, "細編み（1段目）")

        // 目ボタンで種類の変更（目数は増えない）
        app.buttons["stitch.doubleCrochet"].tap()
        XCTAssertEqual(app.staticTexts["selection.description"].label, "長編み（1段目）")
        XCTAssertTrue(app.staticTexts["1段目・この段 3目"].exists)

        // 削除 → 2目、選択は解除
        app.buttons["selection.delete"].tap()
        XCTAssertTrue(app.staticTexts["1段目・この段 2目"].waitForExistence(timeout: 2))
        XCTAssertFalse(app.staticTexts["selection.description"].exists)
    }
}
