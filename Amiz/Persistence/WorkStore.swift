import SwiftUI
import Foundation
import SwiftData
import CrochetCore

/// 作品の保存先（SwiftData）を作る（tech-spec 6）。
///
/// 保存先はディスクの空き不足・ファイルの破損・将来のデータ形式の変更などで開けなくなることがある。
/// そのときにアプリを落とす（`fatalError`）と、起動するたびに落ちて何もできなくなるので、
/// 壊れた保存先を退避して作り直し、それも無理ならメモリ上で起動して理由を画面に出す（AMIZ-69）
enum WorkStore {
    /// 保存先を開いた結果
    struct Result {
        let container: ModelContainer
        /// 開けなかったときの説明（画面に出す）。問題なければ nil
        let warning: String?
    }

    /// 起動時に保存先を開く
    static func open(arguments: [String] = ProcessInfo.processInfo.arguments,
                     environment: [String: String] = ProcessInfo.processInfo.environment) -> Result {
        // ユニットテストのホストとして起動したときは、ファイルに書かない（テスト側が自分の保存先を作る）
        if environment["XCTestConfigurationFilePath"] != nil {
            return Result(container: inMemoryContainer(), warning: nil)
        }
        if arguments.contains("--ui-testing") {
            return uiTestingContainer(arguments: arguments)
        }
        return open(at: defaultStoreURL())
    }

    /// 通常の保存先。開けなければ1度だけ退避して作り直し、それも失敗したらメモリ上で起動する
    static func open(at url: URL) -> Result {
        do {
            return Result(container: try container(at: url), warning: nil)
        } catch {
            guard let movedTo = moveAside(url) else {
                return Result(container: inMemoryContainer(), warning: cannotSaveWarning)
            }
            do {
                let container = try container(at: url)
                return Result(container: container, warning: """
                    保存先を開けなかったため、新しく作り直しました。これまでの作品は「\(movedTo.lastPathComponent)」という名前で端末に残してあります。
                    """)
            } catch {
                return Result(container: inMemoryContainer(), warning: cannotSaveWarning)
            }
        }
    }

    private static let cannotSaveWarning = """
        保存先を開けませんでした。このまま使えますが、作った編み図は端末に保存されません。端末の空き容量を確認して、アプリを開き直してください。
        """

    /// 通常の保存先の場所
    static func defaultStoreURL() -> URL {
        URL.applicationSupportDirectory.appending(path: "default.store")
    }

    /// 壊れた保存先を日付き の名前に退避する。退避できたらその URL
    static func moveAside(_ url: URL, now: Date = Date()) -> URL? {
        let manager = FileManager.default
        guard manager.fileExists(atPath: url.path) else { return nil }
        let stamp = Self.stampFormatter.string(from: now)
        let name = url.deletingPathExtension().lastPathComponent
        let moved = url.deletingLastPathComponent().appending(path: "\(name)-破損-\(stamp).\(url.pathExtension)")
        do {
            try manager.moveItem(at: url, to: moved)
            // SQLite の付属ファイル（-shm / -wal）も一緒に動かす。失敗しても本体が動いていれば作り直せる
            for suffix in ["-shm", "-wal"] {
                let side = URL(filePath: url.path + suffix)
                if manager.fileExists(atPath: side.path) {
                    try? manager.moveItem(at: side, to: URL(filePath: moved.path + suffix))
                }
            }
            return moved
        } catch {
            return nil
        }
    }

    private static let stampFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        return formatter
    }()

    private static func container(at url: URL) throws -> ModelContainer {
        try ModelContainer(for: Work.self, configurations: ModelConfiguration(url: url))
    }

    private static func inMemoryContainer() -> ModelContainer {
        // メモリ上の保存先は失敗しない想定だが、万一のときも落とさずに空で続ける
        if let container = try? ModelContainer(for: Work.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true)) {
            return container
        }
        return try! ModelContainer(for: Work.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
    }

    /// UI テスト用の保存先（一時フォルダ）。`--reset-store` で空にし、`--seed-broken-work` で壊れた作品を置く
    private static func uiTestingContainer(arguments: [String]) -> Result {
        let url = URL.temporaryDirectory.appending(path: "amiz-uitest.store")
        if arguments.contains("--reset-store") {
            for suffix in ["", "-shm", "-wal"] {
                try? FileManager.default.removeItem(at: URL(filePath: url.path + suffix))
            }
            // 設定（UserDefaults）も既定に戻す。前のテストで変えた設定が残らないように
            if let bundleID = Bundle.main.bundleIdentifier {
                UserDefaults.standard.removePersistentDomain(forName: bundleID)
            }
        }
        guard let container = try? container(at: url) else {
            return Result(container: inMemoryContainer(), warning: nil)
        }
        if arguments.contains("--seed-broken-work") {
            let work = Work(name: "壊れた作品", pattern: Pattern(method: .joinedRounds, foundation: .magicRing))
            work.patternData = Data("not json".utf8)
            container.mainContext.insert(work)
            try? container.mainContext.save()
        }
        return Result(container: container, warning: arguments.contains("--store-warning") ? "保存先の確認用のメッセージです。" : nil)
    }
}

// MARK: - 画面へ渡す

private struct StoreWarningKey: EnvironmentKey {
    static let defaultValue: String? = nil
}

extension EnvironmentValues {
    /// 保存先を開けなかったときの説明（ホームで帯に出す）
    var storeWarning: String? {
        get { self[StoreWarningKey.self] }
        set { self[StoreWarningKey.self] = newValue }
    }
}
