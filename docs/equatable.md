# `@Equatable`

> [ドキュメント目次](README.md) ・ [README](../README.md)

格納プロパティから `Equatable` 準拠を生成する。**生成形は自動判定**:

| 対象 | 生成形 | 理由 |
|---|---|---|
| `View` 準拠 or global-actor 属性 (`@MainActor` 等) | 型内に `nonisolated static func ==` メンバ | SwiftUI の `.equatable()` が actor hop なしで `==` を呼べる |
| それ以外の値型 | `extension T: Equatable { static func == }` | 通常の値型に自然な形 |

明示上書きは `@Equatable(.nonisolated)` / `@Equatable(.extension)`。

Global-actor 属性の自動検出は `@MainActor` と、属性名が `*Actor`（6 文字以上）で終わる
慣習的な global actor 名に限定される。それ以外のカスタム global actor では
`@Equatable(.nonisolated)` を明示すること。

## 比較から自動除外されるもの

- computed property（`var x: Int { ... }`）、`body`
- `static` / `class` / `lazy` メンバ
- 関数・クロージャ型プロパティ（`() -> Void`, `@MainActor (T) -> Void`,
  `(() -> Void)?`, `[() -> Void]`、トップレベルがクロージャリテラルの初期化子）
- `.nonisolated` 形のとき、environment/参照由来の SwiftUI dynamic property wrapper
  （`@Binding`, `@Environment`, `@ScaledMetric`, `@FocusedValue`, `@ObservedObject` ほか。
  非 Equatable／`body` 外で読むとトラップするため）
- **`@State` は除外しない**。生成 `==` は `_count.wrappedValue` 経由で比較する
  （MainActor 隔離のアクセサを bypass し、EquatableBodyView で stale にならないため）

複数バインディング（`let a, b: Int`）は各識別子を個別に比較する。ジェネリック型は
比較対象プロパティの型パラメータに `: Equatable` 制約を付ける。

## 例

```swift
import AppMacros
import SwiftUI

@Equatable
struct PuzzleFeedbackRow: View {          // View なので nonisolated メンバを自動生成
    let state: PuzzleFeedbackRowState
    let onTap: @MainActor () -> Void       // クロージャは自動除外

    var body: some View { /* ... */ }      // body は自動除外
}

// 呼び出し側:
PuzzleFeedbackRow(state: loadedState.feedbackRowState, onTap: onTap)
    .equatable()
```

## 関連

- [`@SkipEquatable`](skip-equatable.md) — 特定プロパティを比較から除外する
- [`EquatableBodyView`](equatable-body-view.md) — `.equatable()` 付け忘れを防ぐ
- [採用ガイドと既知の制限](adoption.md)
