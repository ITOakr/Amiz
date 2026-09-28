import XCTest

/// 文字を大きくしたときの編集画面（AMIZ-81）。
///
/// アクセシビリティの文字サイズでは、現在の段とキーボードが縦に伸びて編み図が見えなくなっていた。
/// 操作する部分に文字サイズの上限を付けたので、一番大きい設定でも編み図と操作が残ることを確かめる
final class LargeTextUITests: XCTestCase {
    /// 一番大きい文字サイズで起動する
    @MainActor
    private func launchWithLargestText() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = [
            "--ui-testing", "--reset-store",
            "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityExtraExtraExtraLarge",
        ]
        app.launch()
        return app
    }

    @MainActor
    func testEditorStaysUsableAtLargestTextSize() {
        let app = launchWithLargestText()

        let newButton = app.buttons["home.newFromEmpty"]
        XCTAssertTrue(newButton.waitForExistence(timeout: 5))
        newButton.tap()
        XCTAssertTrue(app.buttons["newWork.create"].waitForExistence(timeout: 2))
        app.buttons["newWork.create"].tap()

        // 編み図が残っている（高さが潰れていない）
        let chart = app.descendants(matching: .any).matching(identifier: "chart").firstMatch
        XCTAssertTrue(chart.waitForExistence(timeout: 5))
        XCTAssertGreaterThan(chart.frame.height, 150, "編み図の高さが潰れていない")

        // 図が「図／目数表」の切り替えより下にある（重なっていない）。
        // 図の中の「全体」ボタンは図と1つの要素に統合されているので（AMIZ-87）、図の位置で確かめる
        let tabs = app.segmentedControls.firstMatch
        XCTAssertTrue(tabs.exists)
        XCTAssertGreaterThanOrEqual(chart.frame.minY, tabs.frame.maxY, "図が切り替えタブに重なっていない")

        // 目ボタンと段の操作が押せる
        let singleCrochet = app.buttons["stitch.singleCrochet"]
        XCTAssertTrue(singleCrochet.isHittable, "細編みのボタンが押せる")
        XCTAssertTrue(app.buttons["op.finishRow"].isHittable, "「段を終える」が押せる")
        XCTAssertTrue(app.buttons["modifier.increase"].isHittable, "「増し目」が押せる")

        // 実際に編めて、目数が出る
        for _ in 0..<6 { singleCrochet.tap() }
        XCTAssertTrue(app.staticTexts["1段目・この段 6目"].waitForExistence(timeout: 2))

        // 目数表にも切り替えられる（こちらは文字サイズの上限を付けていない）
        XCTAssertTrue(app.openStitchTable(), "目数表が開く")
        XCTAssertTrue(app.waitForTableText("わの作り目"), "作り目の行が読める")
    }
}
