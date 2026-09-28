import XCTest

/// 編み目キーボードの「先に選ぶボタン」の表示（ui-spec 5-6。AMIZ-80）。
///
/// ボタン名は短くして幅を揃え、選んだ目数はボタンの中の小さい2行目に出す。
/// 読み上げ（VoiceOver）には今までどおりの言い方を渡す
final class KeyboardLayoutUITests: XCTestCase {
    @MainActor
    func testModifierButtonsShowCountInsideButton() {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing", "--reset-store"]
        app.launch()

        let newButton = app.buttons["home.newFromEmpty"]
        XCTAssertTrue(newButton.waitForExistence(timeout: 5))
        newButton.tap()
        app.buttons["newWork.create"].tap()

        let increase = app.buttons["modifier.increase"]
        XCTAssertTrue(increase.waitForExistence(timeout: 5))

        // 選ぶ前：短い名前だけ。読み上げは「2目編み入れる」
        XCTAssertFalse(increase.staticTexts["2目"].exists)
        XCTAssertEqual(increase.label, "2目編み入れる")
        XCTAssertEqual(app.buttons["modifier.decrease"].label, "2目一度")
        XCTAssertEqual(app.buttons["modifier.cluster"].label, "玉編み")
        XCTAssertEqual(app.buttons["modifier.chainSpace"].label, "束に編み入れる")
        XCTAssertEqual(app.buttons["modifier.untilEnd"].label, "残りすべての目に")

        // 1回押すと2目、もう1回で3目（ボタンの中に目数が出る。名前の部分は変わらない）
        increase.tap()
        XCTAssertTrue(increase.staticTexts["2目"].waitForExistence(timeout: 2))
        XCTAssertTrue(increase.staticTexts["増し目"].exists)
        XCTAssertEqual(increase.label, "2目編み入れる")  // 読み上げは今の選択を読む
        snapshot(app, name: "keyboard-increase-2")

        increase.tap()
        XCTAssertTrue(increase.staticTexts["3目"].waitForExistence(timeout: 2))
        XCTAssertEqual(increase.label, "3目編み入れる")

        // もう一度押すと選択が解除され、目数の行も消える
        increase.tap()
        XCTAssertTrue(app.staticTexts["3目"].waitForNonExistence(timeout: 2))

        // 玉編みは 3目 から始まる（domain-spec 2）
        let cluster = app.buttons["modifier.cluster"]
        cluster.tap()
        XCTAssertTrue(cluster.staticTexts["3目"].waitForExistence(timeout: 2))
        XCTAssertEqual(cluster.label, "3目の玉編み")
        snapshot(app, name: "keyboard-cluster-3")
    }

    @MainActor
    private func snapshot(_ app: XCUIApplication, name: String) {
        guard let dir = ProcessInfo.processInfo.environment["AMIZ_SNAPSHOT_DIR"] else { return }
        try? app.screenshot().pngRepresentation.write(to: URL(fileURLWithPath: dir).appending(path: "\(name).png"))
    }
}
