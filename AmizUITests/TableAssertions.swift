import XCTest

/// 目数表を読むときの共通の待ち方（AMIZ-74）。
///
/// 目数表は入力中の段へ自動でスクロールし、画面の外にある行は作られない。
/// スクロールの量や描き直しのタイミングは端末やアニメーションで変わるので、
/// 「決まった回数だけスワイプする」のではなく「見えるまで待つ・たどる」形にする
extension XCUIApplication {
    /// 目数表（`stitchTable`）。開いていなければ最初の一覧
    var stitchTable: XCUIElement {
        let table = collectionViews["stitchTable"]
        return table.exists ? table : collectionViews.firstMatch
    }

    /// 「目数表」タブを開き、表が出るまで待つ（切り替えの反映が間に合わないことがあるので一度やり直す）
    @discardableResult
    func openStitchTable(attempts: Int = 3) -> Bool {
        for _ in 0..<attempts {
            if stitchTable.waitForExistence(timeout: 1) { return true }
            let tab = buttons["目数表"]
            if tab.exists { tab.tap() }
        }
        return stitchTable.exists
    }

    /// 目数表にその文字が見えるまで、少し待ってから上へたどる
    @discardableResult
    func waitForTableText(_ text: String, attempts: Int = 5) -> Bool {
        let element = staticTexts[text]
        if element.waitForExistence(timeout: 2) { return true }
        let table = stitchTable
        for _ in 0..<attempts {
            guard table.exists else { break }
            table.swipeDown()
            if element.waitForExistence(timeout: 1) { return true }
        }
        return element.exists
    }

    /// 目数表にその行（`table.row.N`）が見えるまで上へたどる
    @discardableResult
    func waitForTableRow(_ number: Int, attempts: Int = 5) -> XCUIElement {
        let row = buttons["table.row.\(number)"]
        if row.waitForExistence(timeout: 2) { return row }
        let table = stitchTable
        for _ in 0..<attempts {
            guard table.exists else { break }
            table.swipeDown()
            if row.waitForExistence(timeout: 1) { return row }
        }
        return row
    }
}
