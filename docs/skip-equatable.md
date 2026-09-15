# `@SkipEquatable`

> [ドキュメント目次](README.md) ・ [利用ガイド](adoption.md)

`@Equatable` が生成する比較から、一つの格納プロパティを除外するマーカー。単独では比較関数や準拠を生成しない。

## 使用例

型エイリアスでクロージャ型を表すプロパティは、構文だけでは自動除外できない。`@SkipEquatable` で明示する。

```swift
import AppMacros
import SwiftUI

typealias RowAction = @MainActor () -> Void

@Equatable
struct ItemRow: @MainActor EquatableBodyView {
    let itemID: Int
    let title: String
    @SkipEquatable let onSelect: RowAction

    var equatableBody: some View {
        Button(title, action: onSelect)
    }
}
```

比較対象は `itemID` と `title`。`onSelect` の変化は比較結果に影響しない。同じ ID とタイトルで等しいと判定した場合に、以前の処理を使用しても正しく動作することが必要となる。

除外した処理が別の対象や設定をキャプチャするなら、その変化を比較対象の入力で表す。`@SkipEquatable` は、除外しても正しいことを検証する機能ではない。

## 宣言の条件

一つの格納プロパティの宣言に付ける。`let a = 1, b = 2` のような複数バインディングの宣言には付けられない。除外対象を個別に宣言する。

`#if` 内の格納プロパティや、関数型を内包する型にも使用できる。除外した値だけが変わっても、生成される `==` は異なるとは判定しない。入力の除外によって比較対象が空になった場合、`@Equatable` は常に等しくなることを警告する。

自動除外されるプロパティの一覧は [`@Equatable`](equatable.md) を参照。
