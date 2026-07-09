# num-path 採用ガイド（提案 / num-path は未編集）

> **ステータス**: これは検証済みの「適用可能な提案」である。ユーザー判断により
> **num-path 本体は一切編集していない**。以下は num-path 側で実施する変更の設計と
> 具体差分。すべて `swift test --package-path AdPuzzleApp` /
> `./scripts/check-architecture.sh` / `./scripts/check-style.sh` を green にすること。

## 背景（検証済みの再描画課題）

num-path は `@Binding`/`@ObservedObject`/`@EnvironmentObject` を規約で禁止した
一方向データフローのため、再描画を抑える手段は実質 `Equatable` + `.equatable()` の
diff narrowing だけ。だが現状その適用は候補 9 View 中 2 つに留まる:

1. **中間層 spine が未最適化**: `PuzzleHomeContent → PuzzleLoadedGameView →
   PuzzleLoadedGameLayout → PuzzlePlayPanel → PuzzlePlayHeader` が
   `PuzzleHomeLoadedState` 丸ごとを保持し `Equatable` diff ゼロ。盤面に無関係な
   フィールド変化でも `GeometryReader` を含む header まで再評価される（最大の課題）。
2. **`PuzzleFeedbackRow` がパターン半適用**: `PuzzleFeedbackRowState` は存在するが
   View が `.equatable()` 未適用（`Panel/PuzzlePlayPanel.swift:109`）。
3. **手書き `nonisolated static func ==` ボイラープレート**: `PuzzleBoard`
   (`Board/PuzzleBoardView.swift:34`)・`PuzzleActionRow`
   (`Panel/PuzzleActionRow.swift:86`) の 2 箇所。

`@Equatable` はこの 3 つを直接解消する。

## Step 0 — 依存追加（`AdPuzzleApp/Package.swift`）

```swift
dependencies: [
    .package(url: "https://github.com/9uiLe/swift-app-macros.git", branch: "master"),   // 追加
    .package(url: "https://github.com/9uiLe/swift-scoped-animation.git", from: "0.2.0"),
    .package(url: "https://github.com/9uiLe/swift-tasking.git", from: "0.1.0"),
],

.target(
    name: "Presentation",
    dependencies: [
        "Application", "DesignSystem", "Domain",
        .product(name: "ScopedAnimation", package: "swift-scoped-animation"),
        .product(name: "AppMacros", package: "swift-app-macros"),   // 追加
        .product(name: "Tasking", package: "swift-tasking"),
    ],
    resources: [.process("Resources")],
),
```

## Step 1 — 既存の手書き == を置換（機械的・低リスク）

`PuzzleBoard` / `PuzzleActionRow` は View 準拠のため `@Equatable` が自動で
`nonisolated static func ==` を生成する。**手書き `==` は同じ編集で削除**する
（残すと二重定義エラー）。

```swift
import AppMacros

@Equatable                                   // 追加。: Equatable も付けてよい
struct PuzzleBoard: View {
    let state: PuzzleBoardState
    let select: @MainActor (GridPoint) -> Void   // クロージャは自動除外
    var body: some View { /* 変更なし */ }
    // nonisolated static func == { ... }   ← 削除
}
```

`PuzzleActionRow` も同様（`state` のみ比較、5 つの closure は自動除外）。

## Step 2 — `PuzzleFeedbackRow` を仕上げる（課題 #2）

```swift
@Equatable
struct PuzzleFeedbackRow: View {
    let state: PuzzleFeedbackRowState
    var body: some View { /* 変更なし */ }
}
```

呼び出し側 `Panel/PuzzlePlayPanel.swift:109`:

```swift
PuzzleFeedbackRow(state: loadedState.feedbackRowState)
    .equatable()          // 追加
```

## Step 3 — `PuzzlePlayHeader` を narrowed state 化（課題 #1・最大の効果）

現状の `PuzzlePlayHeader` は `loadedState` 丸ごとを読む。`body` が実際に読むのは
以下だけ（`Panel/PuzzlePlayPanel.swift` 実コードで確認済み）。**フィールド名は
検証済み**: `targetSum`/`pathLength` は `puzzle.puzzle.*`、選択数は
`selectedPoints.count` を projection する。

```swift
struct PuzzlePlayHeaderState: Equatable {
    let progressText: String
    let mistakeCount: Int
    let hintCount: Int
    let targetSum: Int
    let selectedSum: Int
    let remainingSelections: Int
    let selectedPointCount: Int
    let pathLength: Int
    let feedback: PuzzleFeedback
}

extension PuzzleHomeLoadedState {
    var playHeaderState: PuzzlePlayHeaderState {
        PuzzlePlayHeaderState(
            progressText: progressText,
            mistakeCount: mistakeCount,
            hintCount: hintCount,
            targetSum: puzzle.puzzle.targetSum,
            selectedSum: selectedSum,
            remainingSelections: remainingSelections,
            selectedPointCount: selectedPoints.count,
            pathLength: puzzle.puzzle.pathLength,
            feedback: feedback,
        )
    }
}

@Equatable
private struct PuzzlePlayHeader: View {
    let state: PuzzlePlayHeaderState
    var body: some View {
        // body 内の loadedState.* を state.* に置換
        // 例: loadedState.puzzle.puzzle.targetSum -> state.targetSum
        //     loadedState.selectedPoints.count    -> state.selectedPointCount
    }
}
```

呼び出し側:

```swift
PuzzlePlayHeader(state: loadedState.playHeaderState)
    .equatable()
```

## Step 4 — panel/spine を narrowed state 化（残りの課題 #1）

Step 3 と同じ要領で `PuzzlePlayPanelState`（`headerState` + `boardState` +
`feedbackRowState` + `feedback`）を projection し、`PuzzlePlayPanel` を
`@Equatable` + `.equatable()` 化する。`@Environment(\.accessibilityReduceMotion)`
は `.nonisolated` allowlist に含まれるため比較から自動除外される。効果が測れなければ
`PuzzleLoadedGameLayout`/`PuzzleLoadedGameView` まで拡張する（リスクが上がるので
計測で必要性を確認してから）。

## 代替: `EquatableBodyView` で付け忘れを構造的に防ぐ（推奨・ADR-0015）

課題 #2 の `PuzzleFeedbackRow` は「`Equatable` は満たすが `.equatable()` を付け忘れて効果ゼロ」の
サイレント失敗そのものだった。stateless / `@State` のみの leaf View（`PuzzleFeedbackRow`・
`PuzzleBoard` 等）は、`.equatable()` を呼び出し側に書く代わりに `EquatableBodyView` に準拠させると
付け忘れが原理的に起きない:

```swift
@Equatable
struct PuzzleFeedbackRow: EquatableBodyView {
    let state: PuzzleFeedbackRowState

    var equatableBody: some View {   // body ではなく equatableBody
        // 既存の body 本体をそのまま
    }
}

// 呼び出し側は .equatable() 不要:
PuzzleFeedbackRow(state: loadedState.feedbackRowState)
```

注意: `PuzzleBoard` / `PuzzleActionRow` は `select` などの**参照キャプチャ closure** を持つが、
これらは最新値を読むため stale にならない（値スナップショットを捕捉する closure のみ、キャプチャ値を
比較 state に含める必要がある）。`@StateObject` / `@ObservedObject` / `@Binding` を持つ View には
使えない（マクロが診断エラーにする）。num-path は一方向データフロー（これらを規約で禁止）のため
適合しやすい。

## 検証ゲート（必須）

```bash
swift test --package-path AdPuzzleApp     # 全ロジックテスト
./scripts/check-architecture.sh           # 依存方向・並行性・View 分割規約
./scripts/check-style.sh                  # SwiftFormat / SwiftLint
```

## 規約適合の根拠

- **View 分割規約（`check-architecture.sh` rule 9）**: `@Equatable` の展開は
  `static func ==` メンバ / `extension` のみで、`func -> some View` /
  computed-`some View` / `@ViewBuilder` を一切生成しない。規約の文言・精神の双方に適合。
- **アニメーション規約**: マクロはアニメーション API を生成しない（`ScopedAnimation`
  集約に影響なし）。
- **Swift 6 隔離**: View 準拠を検出して `nonisolated` メンバを生成するため、
  `.equatable()` が actor hop なしで `==` を呼べる（既存手書きと同一の形）。
