# `EquatableBodyView`

> [ドキュメント目次](README.md) ・ [利用ガイド](adoption.md)

`EquatableBodyView` は `View` と `Equatable` を継承する MainActor の protocol。既定の `body` が `.equatable()` による比較境界を設ける。親から渡す入力が等しい場合に、`equatableBody` の再評価を抑制する。

## View を定義する

```swift
import AppMacros
import SwiftUI

@Equatable
struct ChipView: @MainActor EquatableBodyView {
    let title: String
    let onTap: @MainActor () -> Void

    var equatableBody: some View {
        Button(title, action: onTap)
    }
}

struct ChipPanel: View {
    var body: some View {
        ChipView(title: "Done", onTap: {})
    }
}
```

内容は `equatableBody` に実装する。使用側では通常の View として扱い、`.equatable()` の追加は不要。`@Equatable` が生成する比較は `title` を使用し、`onTap` を除外する。

等しい入力で以前のコールバックを使い続けても、正しく動作することが利用条件。コールバックの振る舞いが変わる場合は、その変化を比較可能な入力に含める。詳しくは [利用ガイド](adoption.md) を参照。

## 準拠の隔離

`@Equatable` と組み合わせる宣言は `: @MainActor EquatableBodyView` とする。比較関数と Equatable 準拠だけでなく、それを継承する EquatableBodyView 準拠も MainActor に隔離する。

既定の `body` が使用する内部 View も MainActor の Equatable 準拠を持ち、内容の比較を呼び出す。準拠の隔離が一致しない場合、`@Equatable` は診断と Fix-it を提示する。言語規則は [actor 隔離の設計](actor-isolation.md) を参照。

## 状態の扱い

| プロパティ | 利用条件 |
| --- | --- |
| 通常の格納値 | 表示や操作を決める入力として比較する |
| `@State` / `@StateObject` | View が所有する状態として使用できる。比較からは除外する |
| 環境などの既知の SwiftUI wrapper | 比較から除外する。SwiftUI の依存関係として扱う |
| `@ObservedObject` / `@Bindable` / `@Binding` | `@Equatable` がエラーにする。親で読み、比較可能な値を渡す |

親が参照先を差し替えられる状態を比較から除外すると、等しいという判定によって古い参照先を使い続ける可能性がある。子 View は値入力を受け取り、状態の読み書きは所有者が扱う構成にする。

SwiftUI が追跡する状態や環境の更新は、親入力の比較とは別の依存関係で処理される。比較境界は、すべての `equatableBody` 評価回数を固定する契約ではない。

## `body` の契約

`body` は protocol の既定実装を使用する。直接実装すると比較境界を経由しないため、`@Equatable` はエラーにし、`equatableBody` への改名を Fix-it で提示する。

別 extension にある `body` や、独自 protocol を経由した準拠はマクロから検出できない場合がある。検出範囲は [`@Equatable`](equatable.md) を参照。
