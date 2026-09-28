import XCTest

/// 図と「全体」ボタンが別々の要素になっていること（AMIZ-87）。
///
/// 図の外側に識別子を付けていたため、重ねた「全体」ボタンを飲み込んで1つの要素になり、
/// 図全体が「全体」という名前で読み上げられ、ボタンを個別に押せなかった
final class ChartElementUITests: XCTestCase {
    @MainActor
    func testChartAndFitButtonAreSeparateElements() {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing", "--reset-store"]
        app.launch()

        let newButton = app.buttons["home.newFromEmpty"]
        XCTAssertTrue(newButton.waitForExistence(timeout: 5))
        newButton.tap()
        XCTAssertTrue(app.buttons["newWork.create"].waitForExistence(timeout: 2))
        app.buttons["newWork.create"].tap()

        let chart = app.descendants(matching: .any).matching(identifier: "chart").firstMatch
        XCTAssertTrue(chart.waitForExistence(timeout: 5))
        // 図は「全体」という名前で読み上げられない
        XCTAssertNotEqual(chart.label, "全体")

        // 「全体」ボタンが個別に存在し、押せる
        let fit = app.buttons["chart.fit"]
        XCTAssertTrue(fit.exists, "「全体」ボタンが別の要素として出る")
        XCTAssertTrue(fit.isHittable)
        fit.tap()

        // 押しても図は残り、そのまま編める
        XCTAssertTrue(chart.exists)
        app.buttons["stitch.singleCrochet"].tap()
        XCTAssertTrue(app.staticTexts["1段目・この段 1目"].waitForExistence(timeout: 2))
    }
}
