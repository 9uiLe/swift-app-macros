# AppMacros

アプリ開発向けの Swift マクロ集（`swift-app-macros`）。
初版は SwiftUI 再描画最適化の `@Equatable` / `@SkipEquatable` / `EquatableBodyView` を提供する。

## なぜ Equatable マクロなのか

SwiftUI は `View` が `Equatable` かつ `.equatable()`（内部的に `EquatableView`）で
ラップされていると、入力が等しい限り `body` の再評価をスキップできる。だが手書きの
`Equatable` 準拠には、SwiftUI/Swift 6 特有の落とし穴が多い:

- View は `View` 準拠だけで暗黙 `@MainActor`。素直に `static func ==` を書くと
  MainActor 隔離となり、`Equatable` の nonisolated 要件を満たせずコンパイル不能。
- クロージャ型プロパティは `Equatable` ではないため、比較に含めると必ず失敗する。
- `@State` / `@Environment` などの dynamic property は nonisolated から読むと
  隔離違反・実行時トラップの温床になる。

`@Equatable` はこれらを機械的に正しく処理し、`nonisolated static func ==` の
定型ボイラープレートを消す。

## インストール

```swift
// Package.swift
dependencies: [
    .package(path: "../swift-app-macros"),
],
targets: [
    .target(name: "YourFeature", dependencies: [
        .product(name: "AppMacros", package: "swift-app-macros"),
    ]),
]
```

- swift-tools-version: **6.3** / `swiftLanguageModes: [.v6]`
- 依存: swift-syntax `603.0.2`

## `@Equatable`

格納プロパティから `Equatable` 準拠を生成する。**生成形は自動判定**:

| 対象 | 生成形 | 理由 |
|---|---|---|
| `View` 準拠 or global-actor 属性 (`@MainActor` 等) | 型内に `nonisolated static func ==` メンバ | SwiftUI の `.equatable()` が actor hop なしで `==` を呼べる |
| それ以外の値型 | `extension T: Equatable { static func == }` | 通常の値型に自然な形 |

明示上書きは `@Equatable(.nonisolated)` / `@Equatable(.extension)`。

### 比較から自動除外されるもの

- computed property（`var x: Int { ... }`）、`body`
- `static` / `class` / `lazy` メンバ
- 関数・クロージャ型プロパティ（`() -> Void`, `@MainActor (T) -> Void`,
  `(() -> Void)?`, `[() -> Void]`、トップレベルがクロージャリテラルの初期化子）
- `.nonisolated` 形のとき、environment/参照由来の SwiftUI dynamic property wrapper
  （`@Binding`, `@Environment`, `@ScaledMetric`, `@FocusedValue`, `@ObservedObject` ほか。
  非 Equatable／`body` 外で読むとトラップするため）。**`@State` は除外しない**（値は
  Equatable で比較対象。EquatableBodyView で除外すると stale になるため・ADR-0015）

複数バインディング（`let a, b: Int`）は各識別子を個別に比較する。ジェネリック型は
`extension Box: Equatable where T: Equatable` の条件付き準拠を生成する。

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

// 生成:
// extension PuzzleFeedbackRow: Equatable {}
// nonisolated static func == (lhs:, rhs:) -> Bool { lhs.state == rhs.state }

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
忘れると「コンパイル成功・無警告・効果ゼロ」のサイレント失敗**になる（`.equatable()` は親が子に
適用するもので、SwiftUI に「View が Equatable なら自動で `==` を使う」機構は無い）。これは
最悪の失敗モードで、実際に num-path の `PuzzleFeedbackRow` はこの形の未適用だった。

`EquatableBodyView` は `.equatable()` を**定義側の body 既定実装に焼き込む**ことでこれを解消する。
本体は `body` ではなく `equatableBody` に書く。使用側は通常の `Child(...)` 記法のままでよい。

```swift
@Equatable
struct ChipView: EquatableBodyView {
    let title: String
    let onTap: () -> Void           // 自動除外

    var equatableBody: some View {  // body ではなく equatableBody に書く
        Button(title, action: onTap)
    }
}

ChipView(title: "x", onTap: onTap)  // 使用側は .equatable() 不要
```

**適用範囲は stateless + `@State` 限定**。`@Equatable` が以下を診断エラーにする:

- `@StateObject` / `@ObservedObject` / `@Binding`（非 Equatable → 比較に反映されず stale）
- `body` の直書き（既定実装の `.equatable()` ゲートをバイパスする。本体は `equatableBody` へ）

診断は構文ベースのため、以下は検出できない（原理的制限・SE-0389）— `: EquatableBodyView` /
`: View` を**直接**書くこと:

- `EquatableBodyView` を精緻化した独自 protocol 経由の準拠（`protocol Leaf: EquatableBodyView` 等）
- typealias で別名化した property wrapper（`typealias B = Binding` を `@B` で使う等）
- **別 extension 内**で宣言した `body`（`#if` 内の `body` は検出する）

> 再描画抑制のランタイム効果（親 30 回 invalidate → `equatableBody` 1 回・overhead 無視可）は
> usapo-ios ADR-0015 のシミュレータ実測で検証済み。本パッケージのテストはコンパイル・展開・診断を
> 担保する（ランタイム抑制効果そのものは当該実測に依拠）。

## 既知の制限（設計上の割り切り）

- **typealias 越しのクロージャ**は構文的に検出できないため比較に含まれてしまう。
  `typealias Action = () -> Void` のような型は `@SkipEquatable` で明示除外する
  （含めるとコンパイルエラーになり、修正は自明）。
- **非 Sendable な stored property（SE-0434）**: `@MainActor` 隔離型（`View` 含む）が生成する
  `nonisolated ==` から読めるのは Sendable 型のみ。非 Sendable 参照型を比較に含めるとコンパイル
  エラーになるため、`@SkipEquatable` で除外するか型を `Sendable` にする。
- **stale closure 不変条件**: `@SkipEquatable` / 自動除外したクロージャが**値スナップショットを
  キャプチャ**する場合、その値を比較対象の stored property に必ず含めること（参照・`@State`
  キャプチャは最新値を読むため安全）。除外はレンダリング入力からの除外であり、挙動の除外ではない。
- **`@SkipEquatable` は複数バインディングに付けられない**（Swift の peer macro 制約:
  `peer macro can only be applied to a single variable`）。宣言を分割すること。
- **手書きの `static func ==` を残したまま `@Equatable` を付けない**。二重定義になる。
  移行時は同じ編集で手書き `==` を削除する。
- **`body: some View` を struct 本体に書くが `: View` を直接付けない**場合、マクロは警告を出す
  （別 extension で `: View` を宣言するスタイルは `nonisolated ==` にならず `.equatable()` が壊れる）。
  対処: struct 宣言に `: View` を付けるか `@Equatable(.nonisolated)` を使う。
- **カスタム `DynamicProperty`** は allowlist に無いため、必要なら `@SkipEquatable`。

## テスト

```bash
swift test   # 44 tests / 4 suites（マクロ展開・診断・実コンパイル・実行時等価性・EquatableBodyView）
```
