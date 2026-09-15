# `@Equatable`

> [ドキュメント目次](README.md) ・ [利用ガイド](adoption.md)

構造体の格納プロパティから `==` と `Equatable` 準拠を生成するマクロ。比較には、除外規則に該当しないプロパティを宣言順に使用する。

## 使用例

```swift
import AppMacros
import SwiftUI

@Equatable
struct FeedbackRow: View {
    let title: String
    let onTap: @MainActor () -> Void

    var body: some View {
        Button(title, action: onTap)
    }
}

@MainActor
func feedback(title: String, onTap: @escaping @MainActor () -> Void) -> some View {
    FeedbackRow(title: title, onTap: onTap).equatable()
}
```

この型には MainActor の `==` と `extension FeedbackRow: @MainActor Equatable` を生成する。比較対象は `title`。クロージャである `onTap` は除外されるため、同じ `title` なら以前のコールバックを使用してもよいことが利用条件となる。

マクロは View の `body` を変更しない。比較による再評価抑制を利用する箇所では `.equatable()` を適用する。定義に比較を含める API は [`EquatableBodyView`](equatable-body-view.md)。

## 引数と生成位置

引数は省略するか、`nil`、`.mainActor`、`.nonisolated`、`.extension` を直接記述する。変数や関数呼び出しから計算する引数は使用できない。

| 引数 | 比較の隔離 | `==` の配置 |
| --- | --- | --- |
| 省略 / `nil` | 宣言から自動選択 | Actor または非隔離を選定できれば型内、それ以外は extension |
| `.mainActor` | MainActor | 型内 |
| `.nonisolated` | 非隔離 | 型内 |
| `.extension` | 宣言から自動選択 | extension |

`.nonisolated` は、比較対象に非隔離の文脈から安全にアクセスできる場合に使用する。型そのものの隔離や `Sendable` 準拠を変更する指定ではない。

## 隔離と準拠

自動選択では、直接書かれた `Equatable` / `EquatableBodyView` 準拠の隔離、`nonisolated struct`、型の actor 属性、直接の View 準拠の順に調べる。通常の `View` には MainActor を選択する。

カスタム actor の型属性は、名前が `Actor` で終わる 6 文字以上の属性として認識する。それ以外の名前は `@UI Equatable` のように準拠へ明示できる。選定できなければ無注釈のコードを生成し、コンパイラの隔離推論に従う。

| 選定した隔離 | 生成する `==` | 追加する準拠 |
| --- | --- | --- |
| MainActor | `@MainActor static func ==` | `extension T: @MainActor Equatable` |
| カスタム global actor | 同じ actor の属性を付けた比較 | 同じ actor の属性を付けた Equatable 準拠 |
| 非隔離 | `nonisolated static func ==` | `extension T: Equatable` |
| コンパイラの推論 | `static func ==` | `extension T: Equatable` |

型宣言に `Equatable` が直接あれば、追加準拠は生成しない。直接書く `Equatable`、`EquatableBodyView`、`Hashable`、`Comparable` の隔離は、選定した比較と一致させる。MainActor の View では、例えば `View, @MainActor Equatable` または `@MainActor EquatableBodyView` と書く。

マクロは利用先の default actor isolation 設定を読み取れない。MainActor を明示する一般の構造体には `.mainActor` を指定する。完全な選定順序、準拠の推論設定、generic API の利用条件は [actor 隔離の設計](actor-isolation.md) を参照。

## 比較対象

通常の格納プロパティは `let` / `var` とも比較する。`willSet` / `didSet` だけを持つプロパティも対象。複数の変数をまとめた宣言では、それぞれの識別子を比較する。

以下は比較から除外する。

- computed property
- `body` という名前で `some View` 型を持つプロパティ
- `static` / `class` / `lazy` メンバー
- `@SkipEquatable` を付けたプロパティ
- トップレベルの関数型・クロージャ型。optional、属性付き、括弧付きも含む
- クロージャリテラルを直接代入したプロパティ
- 既知の SwiftUI dynamic property wrapper を持つプロパティ

### SwiftUI の wrapper

次の名前を持つ wrapper は、隔離方式・生成位置・View 準拠の有無にかかわらず除外する。

| 分類 | Wrapper |
| --- | --- |
| 状態・保存 | `State`、`StateObject`、`AppStorage`、`SceneStorage` |
| 参照・binding | `ObservedObject`、`Bindable`、`Binding` |
| 環境 | `Environment`、`EnvironmentObject`、`ScaledMetric` |
| フォーカス | `AccessibilityFocusState`、`FocusState`、`FocusedBinding`、`FocusedObject`、`FocusedValue`、`FocusedSceneObject`、`FocusedSceneValue` |
| データ取得 | `FetchRequest`、`SectionedFetchRequest`、`Query` |
| その他 | `GestureState`、`Namespace`、`NSApplicationDelegateAdaptor`、`UIApplicationDelegateAdaptor`、`WKApplicationDelegateAdaptor` |

名前による構文判定のため、同名の独自 wrapper も除外される。独自 wrapper を明示的に除外する API は [`@SkipEquatable`](skip-equatable.md)。

## 型パラメーターと公開範囲

比較対象の型注釈で参照する型パラメーターには、`Equatable` 制約を生成する。比較対象が参照しない型パラメーターには追加しない。

```swift
import AppMacros

@Equatable
struct Item<Value, Tag> {
    let value: Value
    let revision: Int
}
```

この例の準拠には `where Value: Equatable` が付く。`Tag` への制約はない。関連型や任意のコンテナーの準拠条件は意味解析しないため、利用側で明示的な制約が必要になる場合がある。

`public` / `package` の型には、同じアクセス修飾を持つ比較関数を生成する。

## 診断

| 条件 | 診断と対応 |
| --- | --- |
| 構造体以外に付与 | エラー。構造体に使用する |
| 引数が対応する直接指定でない | エラー。対応する enum case または `nil` を書く |
| 比較と直接宣言した準拠の隔離が不一致 | エラー。一致する隔離を指定する Fix-it を提示 |
| 単純な識別子でない格納パターン | エラー。個別のプロパティとして宣言する |
| `#if` 内に比較対象の格納プロパティがある | エラー。無条件に宣言するか、`@SkipEquatable` で除外する |
| 関数型を内包する型。`[() -> Void]` など | エラー。除外するなら `@SkipEquatable` を明示する |
| 同じ型同士を比較する手書きの `==` がある | エラー。比較関数かマクロのどちらかを使用する |
| 入力を除外した結果、比較対象が空 | 警告。`==` は常に `true` となる |
| `body: some View` があり、隔離を選定できない | 警告。View 準拠または隔離を明示する |

空の構造体は常に等しく、除外した入力がなければ空比較の警告は出さない。エラーがある宣言には、比較関数も追加準拠も生成しない。

`EquatableBodyView` 固有の状態・`body` の診断は [専用リファレンス](equatable-body-view.md) を参照。

## 構文解析の制限

型エイリアスや、クロージャリテラル以外の初期化式の型は解決しない。クロージャ型が構文上見えなければ、比較対象となるため、除外する場合は `@SkipEquatable` が必要となる。

別 extension にある準拠・メンバー、独自 protocol の継承関係も解析対象外。利用側での判断は [利用ガイド](adoption.md) を参照。
