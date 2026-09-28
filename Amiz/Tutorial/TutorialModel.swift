import Foundation
import Observation

/// 使い方の案内の進行（ui-spec 7-5。AMIZ-84）。
///
/// 画面から `update(_:)` で今の状態を渡すと、条件を満たしているあいだステップを進める。
/// ボタンの押下を横取りしないので、案内と違う操作をしても止まらない
@Observable
final class TutorialModel {
    /// 案内を最後まで見た（またはスキップした）か。UserDefaults に残す
    static let completedKey = "tutorialCompleted"

    let steps: [TutorialStep]
    /// 案内中か
    private(set) var isActive = false
    /// 今のステップの位置（0始まり）
    private(set) var stepIndex = 0

    private let defaults: UserDefaults

    init(steps: [TutorialStep] = TutorialStep.coaster, defaults: UserDefaults = .standard) {
        self.steps = steps
        self.defaults = defaults
    }

    /// 今のステップ（案内中でなければ nil）
    var currentStep: TutorialStep? {
        guard isActive, steps.indices.contains(stepIndex) else { return nil }
        return steps[stepIndex]
    }

    /// 進み具合（「3 / 16」）
    var progressText: String {
        "\(min(stepIndex + 1, steps.count)) / \(steps.count)"
    }

    /// 最後のステップ（ここまで来たら「終わる」を出す）
    var isOnLastStep: Bool {
        stepIndex == steps.count - 1
    }

    /// すでに一度見たか（初回だけ自動で出すための判断に使う）
    var hasCompleted: Bool {
        defaults.bool(forKey: Self.completedKey)
    }

    /// 初回の案内を自動で出すか（ui-spec 7-5）。
    ///
    /// UI テストでは既定で出さない（多くのテストが案内を邪魔に感じるため）。
    /// 案内そのものを試すテストは `--tutorial` を渡して出す
    func shouldOfferAutomatically(hasWorks: Bool, arguments: [String] = ProcessInfo.processInfo.arguments) -> Bool {
        if arguments.contains("--tutorial") { return true }
        if arguments.contains("--ui-testing") { return false }
        return !hasWorks && !hasCompleted
    }

    /// UI テストのために、見たことの記録を消す（`--reset-store` と一緒に使う）
    static func resetIfNeeded(arguments: [String] = ProcessInfo.processInfo.arguments, defaults: UserDefaults = .standard) {
        guard arguments.contains("--reset-store") || arguments.contains("--tutorial") else { return }
        defaults.removeObject(forKey: completedKey)
    }

    /// 案内を始める
    func start() {
        stepIndex = 0
        isActive = true
    }

    /// 今の状態を渡す。条件を満たしているあいだステップを進める
    func update(_ state: TutorialState) {
        guard isActive else { return }
        while steps.indices.contains(stepIndex), steps[stepIndex].isDone(state) {
            stepIndex += 1
        }
    }

    /// 途中でやめる（編み図はそのまま残す）
    func skip() {
        end()
    }

    /// 最後まで見た
    func finish() {
        end()
    }

    private func end() {
        isActive = false
        defaults.set(true, forKey: Self.completedKey)
    }
}
