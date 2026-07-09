# `@SkipEquatable`

> [ドキュメント目次](README.md) ・ [README](../README.md)

特定の格納プロパティを比較から除外するマーカー。1 バインディングに 1 つ。

```swift
@Equatable
struct Row {
    let id: Int
    @SkipEquatable let cache: ExpensiveThing   // 除外
}
```

除外したプロパティは生成 `==` の対象外になる。値スナップショットをキャプチャする
クロージャなどを除外する場合の不変条件は、[採用ガイド](adoption.md)を参照。

## 関連

- [`@Equatable`](equatable.md) — 何が自動除外されるか
- [採用ガイドと既知の制限](adoption.md)
