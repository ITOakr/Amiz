import SwiftUI
import SwiftData
import CrochetCore

/// 起動時の画面（フェーズ4-6 の仮の形）：保存済みの作品があれば最新の1件を開き、なければ新しく作る。
/// 作品一覧（ui-spec 3）はフェーズ4-7 でこれを置き換える。
struct RootView: View {
    @Environment(\.modelContext) private var context
    /// 更新日の新しい順（ui-spec 3 の並び順）
    @Query(sort: \Work.updatedAt, order: .reverse) private var works: [Work]

    var body: some View {
        NavigationStack {
            if let work = works.first {
                EditorView(work: work)
                    .id(work.persistentModelID)
            } else {
                ProgressView()
                    .onAppear(perform: createFirstWork)
            }
        }
    }

    private func createFirstWork() {
        let work = Work(name: "新しい作品", pattern: Pattern(method: .joinedRounds, foundation: .magicRing))
        context.insert(work)
        try? context.save()
    }
}
