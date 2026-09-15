# 利用ガイド

> [ドキュメント目次](README.md) ・ [設計概要](design.md)

AppMacros を使う View では、親から渡す比較可能な入力と、SwiftUI が管理する状態を区別する。比較した入力が等しい場合に、本体の再評価を抑制できる。

## API を選ぶ

| 用途 | 定義 | 使用箇所 |
| --- | --- | --- |
| 使用箇所で比較を適用する View | `@Equatable` と `View` | `.equatable()` を付ける |
| 定義に比較を組み込む View | `@Equatable` と `@MainActor EquatableBodyView` | 通常の View として使う |
| 格納値を比較する一般の構造体 | `@Equatable` | `==` / `!=` を使う |

### 通常の View

```swift
import AppMacros
import SwiftUI

@Equatable
struct MessageRow: View {
    let title: String
    let unreadCount: Int

    var body: some View {
        LabeledContent(title, value: unreadCount.formatted())
    }
}

struct Inbox: View {
    let title: String
    let unreadCount: Int

    var body: some View {
        MessageRow(title: title, unreadCount: unreadCount).equatable()
    }
}
```

`@Equatable` は `title` と `unreadCount` を比較する。比較と追加準拠は MainActor に隔離される。準拠を型宣言に直接書く場合の形は `struct MessageRow: View, @MainActor Equatable`。

### 比較を定義に含める View

```swift
import AppMacros
import SwiftUI

@Equatable
struct CounterRow: @MainActor EquatableBodyView {
    let value: Int

    var equatableBody: some View {
        Text(value.formatted())
    }
}
```

`EquatableBodyView` の既定の `body` が `.equatable()` を適用する。内容は `equatableBody` に実装し、呼び出し元は `CounterRow(value: 1)` として使う。詳細は [`EquatableBodyView`](equatable-body-view.md) を参照。

## 比較可能な入力を定義する

表示と操作の意味を決める値を、比較対象の格納プロパティとして渡す。可変モデルを前後の View が共有していると、両方が変更後の値を読む可能性がある。変更を検出する入力には、描画時点の値や変更を表す識別子を使用する。

非 Sendable の型も MainActor 内で比較できる。ただし、actor 隔離は共有データへのアクセスを制御するもので、値のスナップショットを作る機能ではない。

## コールバックと除外プロパティ

トップレベルのクロージャは自動的に比較から除外される。`@SkipEquatable` で除外する値も、変化だけでは親入力の比較境界を通過しない。等しいと判定したときに、以前のコールバックや除外値を使い続けても正しく動作することが必要となる。

例えばコールバックが項目 ID をキャプチャするなら、その ID を比較対象にも含める。キャプチャする処理先や設定が ID と無関係に変わるなら、その変化も比較可能な入力で表すか、比較による更新抑制を適用しない。

型エイリアスで隠れたクロージャや独自の property wrapper を除外する場合は、`@SkipEquatable` を明示する。具体例は [`@SkipEquatable`](skip-equatable.md) を参照。

## 状態の所有を決める

`@State` / `@StateObject` は View が所有する状態であり、生成する比較に含めない。SwiftUI が追跡する状態・環境の更新は、親からの値入力の比較とは別に扱われる。

`EquatableBodyView` では `@ObservedObject` / `@Bindable` / `@Binding` を使用できない。親が参照先を差し替えたとき、その変化を除外したまま等しいと判定すると、古い参照先を使い続ける可能性がある。親で状態を読み、子には比較可能な値と操作用のコールバックを渡す。

通常の `View` でも、これらの wrapper は生成する比較から除外される。`.equatable()` を適用する場合は、参照先の差し替えを比較対象に反映できることを確認する。

## Actor をまたぐ利用

MainActor の Equatable 準拠は、MainActor の文脈で利用する。非隔離の比較が必要な一般の値型には、次のように `.nonisolated` を指定できる。

```swift
import AppMacros

@Equatable(.nonisolated)
nonisolated struct Snapshot: Sendable {
    let revision: Int
    let title: String
}

nonisolated func matches(_ lhs: Snapshot, _ rhs: Snapshot) -> Bool {
    lhs == rhs
}
```

比較対象は、非隔離の `==` から安全にアクセス・比較できる必要がある。マクロは `Sendable` 準拠を生成しない。隔離された準拠と generic API の関係は [actor 隔離の設計](actor-isolation.md) を参照。

## 構文マクロの利用条件

- 対象は構造体。競合する手書きの `==` は併用しない。
- 型エイリアス、別 extension、独自の継承 protocol、利用先の既定隔離設定は解決しない。必要な隔離は引数や準拠の注釈で明示する。
- 既知の SwiftUI wrapper は名前で認識する。同名の独自 wrapper も除外対象となる。
- `@SkipEquatable` は一つの格納プロパティの宣言に付ける。複数の変数をまとめた宣言には付けられない。
- 型パラメーターの制約は型注釈から生成する。関連型や独自コンテナーの条件付き準拠には、利用側の制約が必要になる場合がある。
- 比較対象が空なら `==` は常に `true`。クロージャや `@SkipEquatable` で入力を除外した結果として空になる場合は、警告を確認する。

生成規則と診断の一覧は [`@Equatable` リファレンス](equatable.md) を参照。
