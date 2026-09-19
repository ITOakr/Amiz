import Testing
@testable import CrochetCore

// パッケージのテストが動くことを確認するための仮のテスト。
// フェーズ1で CrochetCoreInfo を削除するときに一緒に削除する。
@Test("パッケージ名を返す")
func packageName() {
    #expect(CrochetCoreInfo.name == "CrochetCore")
}
