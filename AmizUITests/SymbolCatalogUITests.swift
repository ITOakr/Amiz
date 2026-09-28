import XCTest

/// 記号の一覧（ui-spec 6-3。AMIZ-82）：設定から開けて、記号と見出しが出る
final class SymbolCatalogUITests: XCTestCase {
    @MainActor
    func testOpenSymbolCatalogFromSettings() {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing", "--reset-store"]
        app.launch()

        let settings = app.buttons["home.settings"]
        XCTAssertTrue(settings.waitForExistence(timeout: 5))
        settings.tap()

        let link = app.buttons["settings.symbolCatalog"]
        XCTAssertTrue(link.waitForExistence(timeout: 2), "設定に「記号の一覧」がある")
        link.tap()

        // 目の種類と、組み合わせ・玉編みの見出しが出る
        XCTAssertTrue(app.staticTexts["長々編み"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.staticTexts["引き抜き編み"].exists)
        XCTAssertTrue(app.staticTexts["玉編みとピコット"].exists)
    }
}
