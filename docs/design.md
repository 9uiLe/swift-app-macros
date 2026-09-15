# AppMacros の設計

> [ドキュメント目次](README.md) ・ [利用ガイド](adoption.md)

AppMacros は、SwiftUI の View に渡す入力を比較し、入力が等しい場合の本体の再評価を抑制するためのライブラリ。一般の構造体にも、格納プロパティに基づく `Equatable` 準拠を提供する。

## 公開 API の役割

| API | 契約 |
| --- | --- |
| [`@Equatable`](equatable.md) | 比較対象の格納プロパティから `==` と `Equatable` 準拠を生成する |
| [`@SkipEquatable`](skip-equatable.md) | 指定した格納プロパティを比較対象から除外する |
| [`EquatableBodyView`](equatable-body-view.md) | 既定の `body` に `.equatable()` を適用し、内容を `equatableBody` で受け取る |

`.equatable()` は、前後の View が等しい場合に子の更新を抑制する比較境界を作る。`@Equatable` は比較を提供し、通常の `View` では使用箇所で `.equatable()` を適用する。`EquatableBodyView` は、この比較境界を View の定義に含める。

## 比較が表すもの

生成する `==` は、選定した格納プロパティを宣言順に比較する。比較対象には、表示と操作の意味を決める入力を含める。等しいと判定した View は、親から渡された内容を引き続き使用してもよいことが前提となる。

クロージャや明示的に除外した値の変化は、比較結果に影響しない。除外したコールバックが異なる対象を操作する場合は、その対象の識別子などを比較対象の入力に含める。共有する可変参照を比較しても、変更前の値のスナップショットは得られない。

SwiftUI が管理する状態・環境は、親からの値入力とは別の依存関係を持つ。既知の dynamic property wrapper は、actor 隔離や `==` の配置にかかわらず比較対象から除外する。`EquatableBodyView` では、親が参照先を差し替えられる `@ObservedObject`、`@Bindable`、`@Binding` を診断エラーにする。

## Actor 隔離

通常の `struct Row: View` には、MainActor に隔離した `==` と `Equatable` 準拠を生成する。検出できる global actor 型には同じ actor の隔離を適用する。明示的に隔離を選ぶ API は `.mainActor` と `.nonisolated`。

一般の構造体では、actor をマクロが選定できなければ extension に無注釈の比較と準拠を生成し、コンパイラの隔離推論に従う。`.extension` は配置だけを指定し、隔離は自動選択する。

隔離された準拠は、その actor の文脈で利用する。型の隔離、`==` の隔離、準拠の隔離は別々の契約であり、生成コードでは対応する actor を明示する。言語規則と SwiftUI の公開 API による根拠は、[actor 隔離の設計](actor-isolation.md)にまとめている。

## 構文解析の境界

マクロが調べる範囲は、属性を付けた構造体の宣言。別 extension、型エイリアスの実体、任意の継承 protocol、利用側モジュールの既定隔離設定は解決しない。SwiftUI の wrapper と protocol は名前で認識する。

検出できる曖昧な入力には診断を返す。比較対象になる `#if` 内の格納プロパティ、関数型を内包する値、競合する手書きの `==` などはエラー。エラーのある宣言には比較関数も追加準拠も生成しない。型の準拠や actor アクセスの最終的な適否は Swift コンパイラが検査する。

## 実装の構成

| ファイル | 担当 |
| --- | --- |
| [公開マクロ宣言](../Sources/AppMacros/EquatableMacro.swift) | 引数と利用条件 |
| [EquatableBodyView.swift](../Sources/AppMacros/EquatableBodyView.swift) | 比較境界を含む View protocol と MainActor の内部 View |
| [EquatableMacro.swift](../Sources/AppMacrosMacros/EquatableMacro.swift) | member / extension のマクロ入口と診断の通知 |
| [EquatableExpansion.swift](../Sources/AppMacrosMacros/EquatableExpansion.swift) | 引数、隔離、準拠の整合性、配置、コード生成 |
| [EquatableProperties.swift](../Sources/AppMacrosMacros/EquatableProperties.swift) | 比較対象と SwiftUI 状態の分類 |
| [EquatableSyntax.swift](../Sources/AppMacrosMacros/EquatableSyntax.swift) | 型・宣言の構文判定、アクセス修飾、型パラメーター制約 |
| [EquatableDiagnostic.swift](../Sources/AppMacrosMacros/EquatableDiagnostic.swift) | エラー、警告、Fix-it |

member と extension の両方の入口が同じ展開計画を使用する。診断の通知は extension 側に集約する。比較対象の解析は隔離の選定から独立している。

## 検証の構成

| 対象 | 実行可能な仕様 |
| --- | --- |
| 生成形・公開範囲・型パラメーター | [EquatableMacroTests.swift](../Tests/AppMacrosTests/EquatableMacroTests.swift) |
| Actor 選定・準拠の整合性・Fix-it | [EquatableIsolationTests.swift](../Tests/AppMacrosTests/EquatableIsolationTests.swift) |
| 比較対象・除外・不正な宣言 | [EquatablePropertyTests.swift](../Tests/AppMacrosTests/EquatablePropertyTests.swift) |
| コンパイルされた比較・隔離された入力 | [EquatableRuntimeTests.swift](../Tests/AppMacrosTests/EquatableRuntimeTests.swift) |
| EquatableBodyView の展開・状態の扱い | [EquatableBodyViewTests.swift](../Tests/AppMacrosTests/EquatableBodyViewTests.swift) |
| マウント済み View の再評価・MainActor 上の比較 | [RenderSuppressionTests.swift](../Tests/AppMacrosTests/RenderSuppressionTests.swift) |

描画テストは macOS の `NSHostingView` を使用する。iOS はビルドで検証する。コマンドと開発時の規約は [CONTRIBUTING.md](../CONTRIBUTING.md) を参照。
