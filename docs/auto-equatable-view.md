# `@AutoEquatableView`

> [ドキュメント目次](README.md) ・ [利用ガイド](adoption.md)

公開部品のように、値だけを表示する View と操作や状態を持つ View が混在する場合に使う。マクロを `View` に付け、内容を `equatableBody` に実装する。`body` は直接書かない。

```swift
import AppMacros
import SwiftUI

@AutoEquatableView
struct StatusLabel: View {
    let title: String

    var equatableBody: some View {
        Text(title)
    }
}

@AutoEquatableView
struct SaveControl: View {
    let title: String
    let action: () -> Void

    var equatableBody: some View {
        Button(title, action: action)
    }
}
```

`StatusLabel` には `Equatable` 準拠と `EquatableBodyView` の比較境界を生成する。親から渡す `title` が等しい場合は内容の再評価を抑えられる。`SaveControl` はクロージャを持つため通常の `View.body` を生成する。新しいアクションを古いものとして保持しないため、`SaveControl` に比較境界は設けない。

| 格納プロパティ | 選択 |
| --- | --- |
| 比較可能な値だけ | MainActor 上の比較と境界を生成 |
| `@Environment`、`@State`、`@FocusState` など SwiftUI 管理の値 | 比較から除外し、SwiftUI の依存更新に任せる |
| クロージャ、`@SkipEquatable`、`@Binding`、`@ObservedObject`、`@Bindable` | 通常の `body` を生成して親からの更新を維持 |

任意の子 View を格納するコンテナでは `@SkipEquatable` を付ける。これにより子 View を無理に `Equatable` として扱わず、通常の更新を保てる。比較可能な入力だけの View でも、共有可変参照の前後の状態は自動で記録しない。変化を表す値を入力にする。

構文解析で扱えない型エイリアス内のクロージャや独自 property wrapper は、利用者が `@SkipEquatable` を付ける。比較対象の型が `Equatable` でない場合はコンパイル時にエラーとなる。マクロの選択は性能保証ではない。更新抑制と環境変更時の描画を、実際の画面で確認する。
