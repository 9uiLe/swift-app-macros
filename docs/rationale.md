# なぜ Equatable マクロなのか

> [ドキュメント目次](README.md) ・ [README](../README.md)

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

## 次に読む

- [`@Equatable` リファレンス](equatable.md)
- [`EquatableBodyView`（付け忘れ防止）](equatable-body-view.md)
- [採用ガイド](adoption.md)
