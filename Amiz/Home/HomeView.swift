import SwiftUI
import SwiftData
import CrochetCore

/// 作品一覧（ホーム。ui-spec 3）。作品カードのグリッド、新規作成、設定への入口。
struct HomeView: View {
    @Environment(\.modelContext) private var context
    /// 更新日の新しい順（ui-spec 3 U19）
    @Query(sort: \Work.updatedAt, order: .reverse) private var works: [Work]

    /// 画面の遷移先の積み重ね（作品を作ったらそのまま編集画面へ進むために持つ）
    @State private var path = NavigationPath()
    @State private var isNewWorkPresented = false
    /// カードのメニュー（ui-spec 3）：名前を変える作品と入力中の名前、削除の確認中の作品
    @State private var renamingWork: Work?
    @State private var renameText = ""
    @State private var deletingWork: Work?

    var body: some View {
        NavigationStack(path: $path) {
            Group {
                if works.isEmpty {
                    emptyState
                } else {
                    grid
                }
            }
            .background(AppTheme.canvas)
            .navigationTitle("作品")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    NavigationLink(value: Destination.settings) {
                        Label("設定", systemImage: "gearshape")
                    }
                    .accessibilityIdentifier("home.settings")
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("新規作成", systemImage: "plus") {
                        isNewWorkPresented = true
                    }
                    .accessibilityIdentifier("home.new")
                }
            }
            .navigationDestination(for: Work.self) { work in
                EditorView(work: work)
            }
            .navigationDestination(for: Destination.self) { destination in
                switch destination {
                case .settings:
                    SettingsView()
                }
            }
            .sheet(isPresented: $isNewWorkPresented) {
                NewWorkSheet { work in
                    context.insert(work)
                    try? context.save()
                    path.append(work)
                }
            }
            .alert("名前の変更", isPresented: isRenamePresented) {
                TextField("作品名", text: $renameText)
                    .accessibilityIdentifier("home.renameField")
                Button("変更") {
                    if let work = renamingWork {
                        rename(work, to: renameText)
                    }
                }
                Button("キャンセル", role: .cancel) {}
            }
            .confirmationDialog("この作品を削除しますか？", isPresented: isDeletePresented, titleVisibility: .visible) {
                Button("削除", role: .destructive) {
                    if let work = deletingWork {
                        delete(work)
                    }
                }
                Button("キャンセル", role: .cancel) {}
            } message: {
                Text("「\(deletingWork?.name ?? "")」の編み図が消えます。元に戻せません。")
            }
        }
    }

    // MARK: - カードのメニュー（ui-spec 3）

    private var isRenamePresented: Binding<Bool> {
        Binding(get: { renamingWork != nil }, set: { if !$0 { renamingWork = nil } })
    }

    private var isDeletePresented: Binding<Bool> {
        Binding(get: { deletingWork != nil }, set: { if !$0 { deletingWork = nil } })
    }

    private func rename(_ work: Work, to name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        work.name = trimmed
        work.updatedAt = Date()
        try? context.save()
    }

    /// 複製：同じ編み図とサムネイルで「〜のコピー」を作る。更新日は今なので一覧の先頭に来る
    private func duplicate(_ work: Work) {
        guard let pattern = work.loadPattern() else { return }
        let copy = Work(name: work.name + "のコピー", pattern: pattern)
        copy.thumbnail = work.thumbnail
        context.insert(copy)
        try? context.save()
    }

    private func delete(_ work: Work) {
        context.delete(work)
        try? context.save()
    }

    private enum Destination: Hashable {
        case settings
    }

    /// 作品が1つもないとき（ui-spec 3）
    private var emptyState: some View {
        ContentUnavailableView {
            Label("最初の作品を作りましょう", systemImage: "circle.dashed")
        } description: {
            Text("編み目のボタンを押していくと、記号図と目数表ができあがります。")
        } actions: {
            Button("新規作成") {
                isNewWorkPresented = true
            }
            .buttonStyle(.borderedProminent)
            .accessibilityIdentifier("home.newFromEmpty")
        }
    }

    /// 作品カードのグリッド（iPad は列数が増える）
    private var grid: some View {
        ScrollView {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 160, maximum: 240), spacing: 16)], spacing: 16) {
                ForEach(works) { work in
                    NavigationLink(value: work) {
                        WorkCard(work: work)
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("home.work")
                    // カードの長押しメニュー（ui-spec 3）
                    .contextMenu {
                        Button("名前の変更", systemImage: "pencil") {
                            renameText = work.name
                            renamingWork = work
                        }
                        Button("複製", systemImage: "plus.square.on.square") {
                            duplicate(work)
                        }
                        Button("削除", systemImage: "trash", role: .destructive) {
                            deletingWork = work
                        }
                    }
                }
            }
            .padding(16)
        }
    }
}

/// 作品カード（ui-spec 3）。サムネイルは保存時に作った図の縮小画像。まだなければ仮のアイコン
private struct WorkCard: View {
    let work: Work

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            RoundedRectangle(cornerRadius: AppTheme.cardRadius)
                .fill(AppTheme.surface)
                .aspectRatio(1, contentMode: .fit)
                .overlay {
                    if let data = work.thumbnail, let image = ThumbnailRenderer.image(from: data) {
                        image
                            .resizable()
                            .scaledToFit()
                            .padding(6)
                            .accessibilityIdentifier("home.thumbnail")
                    } else {
                        Image(systemName: "circle.circle")
                            .font(.largeTitle)
                            .foregroundStyle(.tertiary)
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.cardRadius))
            Text(work.name)
                .font(.headline)
                .lineLimit(1)
            Text("\(work.method.japaneseName)・\(rowsText)")
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(work.updatedAt, format: .relative(presentation: .named))
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
    }

    /// 「4段目まで」（入力中の段を含む段数）
    private var rowsText: String {
        let count = work.loadPattern()?.rows.count ?? 0
        return count == 0 ? "未入力" : "\(count)段目まで"
    }
}

#Preview {
    HomeView()
        .modelContainer(for: Work.self, inMemory: true)
}
