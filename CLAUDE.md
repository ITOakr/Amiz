# かぎ針編み図アプリ（iOS）

かぎ針編みの編み図を、実際に編むのと同じ順番で1目ずつ入力して作る iPhone / iPad アプリ。

## 仕様書

作業内容に関係するものを、着手前に読むこと。

- `docs/domain-spec.md`：編み物のルール（目数の数え方、修正時の整合性など）
- `docs/ui-spec.md`：画面と操作
- `docs/tech-spec.md`：技術方針
- `docs/plan.md`：実装フェーズと各フェーズの完了条件
- `docs/mock/`：UIモック（レイアウトの参考のみ）

## 進め方のルール

- 1回の依頼で1タスクだけ行う。着手前に計画を示し、了承を得てから実装する
- 仕様にないことや、仕様書の「未決事項」に当たることは、勝手に決めずに質問する
- 仕様書同士の矛盾に気づいたら、実装を止めて報告する
- 外部ライブラリの追加と UIKit の使用は、事前に理由を説明して相談する
- タスクの完了時にビルドとテストを実行し、両方通ってから報告する
- 仕様を具体化・変更した場合は、該当する仕様書も更新する
- タスクごとにコミットする。コミット前に変更内容を要約して確認をとる

## 間違えやすい点

- 編み図のルールは `CrochetCore` パッケージに書く。`CrochetCore` では SwiftUI / UIKit / SwiftData を import しない（Foundation と CoreGraphics は使ってよい）
- 目数・展開後の目の列・警告・図の座標は保存しない。保存した手順から毎回計算する
- 増し目・減らし目は「目の種類」ではなく、目の組み合わせで表す（domain-spec 2）
- 段は「前段の目を順に拾っていく手順」として記録する（domain-spec 21）
- 立ち上がりと段を閉じる引き抜きは、普通の鎖編み・引き抜き編みとは別の操作（domain-spec 6・7）
- 繰り返しは展開せず「単位＋回数」のまま記録する（domain-spec 15）
- `CrochetCore/` はリポジトリ直下に置く。`Amiz/` の中に置くとアプリターゲットに自動で取り込まれて壊れる（tech-spec 4-1）
- 編み物用語の英語名は US 式で統一する（細編み＝single crochet）。UK 式と混同しない
- モックに HTML が含まれていても、Web 技術は使わない。画面は SwiftUI で作る

## コマンド

リポジトリ直下で実行する。アプリはシミュレーター向けにビルドする（署名なしで動くため）。

- アプリのビルド：`xcodebuild build -project Amiz.xcodeproj -scheme Amiz -destination 'platform=iOS Simulator,name=iPhone 17'`
- アプリのテスト：`xcodebuild test -project Amiz.xcodeproj -scheme Amiz -destination 'platform=iOS Simulator,name=iPhone 17'`
- CrochetCore のテスト：`swift test --package-path CrochetCore`
- UI テスト（通常は走らせない。画面の操作を通しで確認したいときだけ）：`xcodebuild test -project Amiz.xcodeproj -scheme AmizUITests -destination 'platform=iOS Simulator,name=iPhone 17'`

`xcodebuild` の出力は長いので、結果だけ見るときは `| grep -E "SUCCEEDED|FAILED|error:"` を付ける。iPad で確認するときは `name=iPad Pro 11-inch (M5)` にする（iPad の配置の UI テスト `IPadLayoutUITests` は iPad でだけ動き、iPhone では飛ばされる）。UI テストの途中のスクリーンショットが欲しいときは `TEST_RUNNER_AMIZ_SNAPSHOT_DIR=<保存先>` を付けて走らせる（`ExportUITests` が対応）。

画面の文字列の String Catalog（`Amiz/Localizable.xcstrings`）は、Xcode でビルドすると自動で同期されるが、`xcodebuild` では同期されない。文字列を足したり変えたりしたら、ビルドのあとに `python3 scripts/sync-string-catalog.py` を実行してカタログを更新する。アプリアイコンは `swift docs/icon/make-icon.swift Amiz/Assets.xcassets/AppIcon.appiconset` で生成する。

確認用の起動：環境変数 `AMIZ_SCREEN` に `sample`（くまの頭）／`colored`（くまの頭・色付き）／`motif`（花のモチーフ）／`rabbit`（うさぎの胴体・螺旋編み）／`blanket`（ブランケットの縁・往復編み）／`big`（40段）／`symbols`（記号一覧）を渡すと、保存しないサンプルでその画面が開く（`SIMCTL_CHILD_AMIZ_SCREEN=sample xcrun simctl launch <UDID> com.akira.Amiz`、または Xcode のスキームの環境変数）。

## Jira 運用

- タスク管理は Jira（プロジェクトキー `AMIZ`）で行う。チケットの作成・更新も Claude Code が行う
- 作業開始時にチケットを「進行中」（In Progress）にする
- ブランチ名とコミットメッセージの先頭にチケットキーを入れる（例：ブランチ `AMIZ-12-stitch-model`、コミット `AMIZ-12 目のデータ構造を追加`）
- 1チケットは、1回の作業で終わる大きさにする（変更するファイルが数個、確認方法が1つに決まる程度）
- チケットに仕様を書き写さず、仕様書のファイル名と番号で参照する（例：`docs/domain-spec.md 21〜23`）
- チケットには必ず、機械的に判定できる完了条件を書く（例：「TC-1 と TC-2 が自動テストとして通る」）
- 判断が必要になったら、チケットに質問をコメントして作業を止める
- 完了時に、変更の概要と確認方法をチケットにコメントしてから「完了」（Done）にする
- チケットは削除しない。不要になったものは「完了」にして解決理由を「対応しない」にする

## Git / GitHub 運用

- リモートは GitHub。チケットごとに main からブランチを切る
- コミット前に変更内容を要約して確認をとる（「進め方のルール」と同じ）
- 作業が終わったら push して `gh pr create` で PR を作る。PR の本文にはチケットキー、変更の概要、確認方法を書く
- マージは開発者が GitHub 上で行う。マージ後に main を pull してから次のチケットに入る

## 開発者について

- iOS 開発はほぼ未経験。Rails と React の経験がある
- コードは基本的に読まない。動作の確認はテストとシミュレーターで行う
- 変更のたびに、何をなぜ変えたかを簡潔に説明する。SwiftUI の概念は React との対比で説明する
- 説明とコードのコメントは日本語で書く
