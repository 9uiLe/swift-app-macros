# `EquatableBodyView`（付け忘れ防止）

> [ドキュメント目次](README.md) ・ [README](../README.md)

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

**適用範囲は stateless + `@State` 限定**。`@State` は保持できるが比較対象外
（変更はゲート下流を直接 invalidate するため stale にならない）。
`@Equatable` が以下を診断エラーにする:

- `@StateObject` / `@ObservedObject` / `@Binding`
- `body` の直書き（本体は `equatableBody` へ）

## 関連

- [`@Equatable`](equatable.md)
- [採用ガイドと既知の制限](adoption.md)
