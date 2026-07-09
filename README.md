# AppMacros

Production-oriented Swift macros for app development.

`swift-app-macros` ships [`AppMacros`](Sources/AppMacros): SwiftUI redraw optimization via `@Equatable`, `@SkipEquatable`, and `EquatableBodyView`.

## Quick start (English)

```swift
import AppMacros
import SwiftUI

@Equatable
struct CounterRow: EquatableBodyView {
    let value: Int

    var equatableBody: some View {
        Text("\(value)")
    }
}

// No `.equatable()` at call sites — baked into EquatableBodyView.
CounterRow(value: 1)
```

For intermediate views, use `@Equatable` and apply `.equatable()` at the call site.

## Compatibility

| Requirement | Version |
|---|---|
| Swift tools | **6.3** (`swiftLanguageModes: [.v6]`) |
| Platforms | **iOS 26+**, **macOS 26+** |
| swift-syntax | `603.0.2` (exact pin) |

This is an early package targeting the latest Apple SDKs. Older OS / Swift versions are not supported.

## Installation

```swift
// Package.swift
dependencies: [
    .package(url: "https://github.com/9uiLe/swift-app-macros.git", branch: "master"),
],
targets: [
    .target(name: "YourFeature", dependencies: [
        .product(name: "AppMacros", package: "swift-app-macros"),
    ]),
]
```

After the first tagged release, prefer `.from: "0.1.0"` instead of `branch: "master"`.

## なぜ Equatable マクロなのか

SwiftUI は `View` が `Equatable` かつ `.equatable()`（内部的に `EquatableView`）で
ラップされていると、入力が等しい限り `body` の再評価をスキップできる。だが手書きの
`Equatable` 準拠には、SwiftUI/Swift 6 特有の落とし穴が多い:

- View は `View` 準拠だけで暗黙 `@MainActor`。素直に `static func ==` を書くと
  MainActor 隔離となり、`Equatable` の nonisolated 要件を満たせずコンパイル不能。
- クロージャ型プロパティは `Equatable` ではないため、比較に含めると必ず失敗する。
- `@Environment` などの dynamic property は nonisolated から読むと
  隔離違反・実行時トラップの温床になる。

`@Equatable` はこれらを機械的に正しく処理し、`nonisolated static func ==` の
定型ボイラープレートを消す。

## `@Equatable`

格納プロパティから `Equatable` 準拠を生成する。**生成形は自動判定**:

| 対象 | 生成形 | 理由 |
|---|---|---|
| `View` 準拠 or global-actor 属性 (`@MainActor` 等) | 型内に `nonisolated static func ==` メンバ | SwiftUI の `.equatable()` が actor hop なしで `==` を呼べる |
| それ以外の値型 | `extension T: Equatable { static func == }` | 通常の値型に自然な形 |

明示上書きは `@Equatable(.nonisolated)` / `@Equatable(.extension)`。

Global-actor 属性の自動検出は `@MainActor` と、属性名が `*Actor`（6 文字以上）で終わる
慣習的な global actor 名に限定される。それ以外のカスタム global actor では
`@Equatable(.nonisolated)` を明示すること。

### 比較から自動除外されるもの

- computed property（`var x: Int { ... }`）、`body`
- `static` / `class` / `lazy` メンバ
- 関数・クロージャ型プロパティ（`() -> Void`, `@MainActor (T) -> Void`,
  `(() -> Void)?`, `[() -> Void]`、トップレベルがクロージャリテラルの初期化子）
- `.nonisolated` 形のとき、environment/参照由来の SwiftUI dynamic property wrapper
  （`@Binding`, `@Environment`, `@ScaledMetric`, `@FocusedValue`, `@ObservedObject` ほか。
  非 Equatable／`body` 外で読むとトラップするため）
- **`@State` は除外しない**。生成 `==` は `_count.wrappedValue` 経由で比較する
  （MainActor 隔離のアクセサを bypass し、EquatableBodyView で stale にならないため・ADR-0015）

複数バインディング（`let a, b: Int`）は各識別子を個別に比較する。ジェネリック型は
比較対象プロパティの型パラメータに `: Equatable` 制約を付ける。

### 例

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

## `@SkipEquatable`

特定の格納プロパティを比較から除外するマーカー。1 バインディングに 1 つ。

```swift
@Equatable
struct Row {
    let id: Int
    @SkipEquatable let cache: ExpensiveThing   // 除外
}
```

## `EquatableBodyView`（付け忘れ防止・ADR-0015）

`@Equatable` + `.equatable()` は 2 箇所セットで書く必要があり、**使用側で `.equatable()` を
忘れると「コンパイル成功・無警告・効果ゼロ」のサイレント失敗**になる。

`EquatableBodyView` は `.equatable()` を**定義側の body 既定実装に焼き込む**。
本体は `body` ではなく `equatableBody` に書く。

```swift
@Equatable
struct ChipView: EquatableBodyView {
    let title: String
    let onTap: () -> Void           // 自動除外

    var equatableBody: some View {
        Button(title, action: onTap)
    }
}

ChipView(title: "x", onTap: onTap)  // 使用側は .equatable() 不要
```

**適用範囲は stateless + `@State` 限定**。`@Equatable` が以下を診断エラーにする:

- `@StateObject` / `@ObservedObject` / `@Binding`
- `body` の直書き（本体は `equatableBody` へ）

## Safe adoption checklist

- Leaf views with only `let` inputs → prefer `EquatableBodyView`
- Intermediate views → `@Equatable` + `.equatable()` at every call site
- Closure props that capture **value snapshots** → include those values in compared `let` state, or use `@SkipEquatable` knowing they are excluded from diff
- Non-Sendable stored properties → `@SkipEquatable` or make the type `Sendable`
- Custom `DynamicProperty` wrappers → `@SkipEquatable` (not in allowlist)
- Typealias-hidden closure types → `@SkipEquatable` explicitly
- Write `: View` / `: EquatableBodyView` directly on the struct (not via refined protocols)

## 既知の制限（設計上の割り切り）

- **typealias 越しのクロージャ**は構文的に検出できない → `@SkipEquatable`
- **非 Sendable な stored property（SE-0434）** → `@SkipEquatable` または `Sendable` 化
- **stale closure 不変条件**: 除外したクロージャが値スナップショットをキャプチャする場合、
  その値を比較対象の stored property に含めること
- **`@SkipEquatable` は複数バインディングに付けられない** → 宣言を分割
- **手書き `static func ==` と `@Equatable` の併用不可** → 同じ編集で削除
- **`body: some View` だが `: View` 未宣言** → マクロが warning（`@Equatable(.nonisolated)` または struct に `: View`）
- **別 extension 内の `body` / protocol 経由準拠** → SE-0389 により検出不能

## テスト

```bash
swift test   # 44 tests / 4 suites
```

CI runs on pull requests (`.github/workflows/ci.yml`).

## License

MIT — see [LICENSE](LICENSE).
