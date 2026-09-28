import CrochetCore

/// 編集画面の状態から、案内が見る状態を作る（AMIZ-84）
extension TutorialState {
    init(screen: TutorialScreen, model: EditorModel, showsTable: Bool = false) {
        let rows = model.expansion.rows
        let currentIndex = model.currentRowIndex
        self.init(
            screen: screen,
            // 入力中の段より前が「終わった段」
            finishedRowCounts: rows.enumerated()
                .filter { $0.offset != currentIndex }
                .map { $0.element.totalCount },
            currentRowCount: currentIndex.map { rows[$0].totalCount },
            modifier: model.modifier,
            isInRepeat: model.repeatStartIndex != nil,
            showsTable: showsTable
        )
    }
}
