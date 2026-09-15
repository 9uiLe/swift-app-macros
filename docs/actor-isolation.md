# Actor 隔離の設計

> [ドキュメント目次](README.md) ・ [設計概要](design.md)

AppMacros は、MainActor で利用する View の比較と `Equatable` 準拠を MainActor に隔離する。基礎となる言語機能は、Swift 6.2 で実装された [SE-0470: Global-actor isolated conformances][se-0470]。パッケージの要件は Swift tools 6.3、Swift 6 language mode、iOS 26 / macOS 26 以降。

## 型・比較関数・準拠

Actor 隔離は、宣言を利用できる実行文脈を定める。比較については、次の三つを区別する。

| 宣言 | 意味 |
| --- | --- |
| `@MainActor struct Row` | 型と、隔離を継承するメンバーを MainActor に置く |
| `@MainActor static func ==` | 比較関数を MainActor で呼ぶ |
| `extension Row: @MainActor Equatable` | `Row` の Equatable 準拠を MainActor で利用する |

`Equatable` の非隔離の要件を、MainActor の比較関数で満たすためには、準拠にも対応する隔離が必要となる。SE-0470 は、この準拠の利用場所をコンパイラが検査する仕組みを定めている。[WWDC25 “What’s new in Swift” 33:04][wwdc25-conformance] でも同じ契約を説明している。

次は、通常の View に対する生成コードと同じ隔離を手書きで表した例。

```swift
import SwiftUI

struct Row: View {
    let title: String

    @MainActor
    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.title == rhs.title
    }

    var body: some View {
        Text(title)
    }
}

extension Row: @MainActor Equatable {}

@MainActor
func makeRow() -> some View {
    Row(title: "Inbox").equatable()
}
```

## View の MainActor 継承

[Apple の View ドキュメント][view] は、`View` を `@MainActor @preconcurrency` protocol として宣言し、元の型宣言で準拠を記述した型が、その隔離を継承すると定めている。通常の `struct Row: View` はこの条件を満たす。

`extension Row: View` という別宣言での準拠は、型全体への同じ推論を行わない。また、明示的な `nonisolated struct` は global actor の推論を抑制する。[SE-0449][se-0449] がこの指定を定めている。

[WWDC24 “What’s new in SwiftUI” 17:28][wwdc24-view] は View protocol 全体の MainActor 注釈を紹介している。[WWDC25 “Explore concurrency in SwiftUI” 3:42][wwdc25-members] は、型の隔離をメンバーが継承することを説明している。

## `.equatable()` と隔離された準拠

[View.equatable()][equatable-method] は同期の `nonisolated` メソッドで、[EquatableView][equatable-view] の `Content` には `View` と `Equatable` の制約がある。`Sendable` / `SendableMetatype` 制約はない。

同期関数の `nonisolated` は、呼び出すと別の actor やバックグラウンドスレッドへ移動するという指定ではない。SE-0470 の Rule 2 は、`SendableMetatype` 制約で禁止していない generic コードに、隔離された準拠を渡せると定めている。

> we assume that generic code accepts isolated conformances unless it has indicated otherwise with a `SendableMetatype` constraint.

この規則により、MainActor の呼び出し元から、MainActor の Equatable 準拠を使って `.equatable()` を適用できる。利用条件は次のとおり。

| 利用場所・要求 | MainActor の Equatable 準拠 |
| --- | --- |
| MainActor 内で `==` を呼ぶ | 利用できる |
| MainActor 内で `.equatable()` を適用する | 利用できる |
| 非隔離の文脈でその準拠を利用する | 利用できない |
| `T: Equatable & SendableMetatype` を要求する API | その要求を満たせない |
| `T: Equatable & Sendable` を要求する API | その要求を満たせない |

MainActor 内の比較対象に `Sendable` は必須ではない。非隔離の比較が必要なら `.nonisolated` を指定し、その比較から各プロパティへ安全にアクセスできる型を設計する。`.nonisolated` は型へ `Sendable` 準拠を追加する指定ではない。

## マクロの隔離選定

次の順序で、最初に該当する指定を採用する。`.extension` はこの選定に影響せず、比較関数の配置だけを指定する。

1. `.mainActor` または `.nonisolated` 引数。
2. 型宣言に直接書いた `Equatable` / `EquatableBodyView` 準拠の明示的な隔離。
3. 型宣言の `nonisolated` 修飾。
4. 型の `@MainActor` 属性、または名前が `Actor` で終わる 6 文字以上の属性。
5. 型宣言に直接書いた `View` / `EquatableBodyView` 準拠から MainActor を選択。
6. いずれもなければ、隔離の注釈を生成せずコンパイラの推論に従う。

カスタム global actor の実体は、構文マクロから解決できない。型の属性は命名規則で認識する。`@UI Equatable` のように準拠へ明示した actor は、`Actor` で終わらない名前でも扱える。`@preconcurrency` は actor 名として扱わない。

## 直接宣言する準拠

MainActor の比較を使う View に Equatable 準拠を直接書く場合は、`View, @MainActor Equatable` とする。`EquatableBodyView` では `: @MainActor EquatableBodyView` とする。この protocol は `Equatable` を継承するため、外側の準拠にも一致する隔離が必要となる。

同じ型に `Hashable` / `Comparable` を直接宣言する場合も、生成する Equatable 準拠と隔離を揃える。マクロは不一致を診断し、準拠の隔離を指定する Fix-it を提示する。属性を付けた型の継承節を、マクロが自動で書き換えることはない。

`InferIsolatedConformances` は準拠の隔離を推論する言語設定。AppMacros は global actor の準拠を明示的に生成し、利用者が直接書く準拠にも一致する注釈を要求するため、この設定の有効化は不要。

[SE-0466][se-0466] の default actor isolation はモジュール単位の設定であり、マクロは利用先の設定を読み取れない。MainActor を明示的な契約にする一般の構造体には、`.mainActor` を指定できる。

## 検証範囲

[隔離の展開テスト](../Tests/AppMacrosTests/EquatableIsolationTests.swift)は、生成する比較関数・準拠・診断を検証する。[実行テスト](../Tests/AppMacrosTests/EquatableRuntimeTests.swift)は、非 Sendable 入力、MainActor の準拠を持つ型引数、カスタム actor、非隔離の比較をコンパイルして実行する。

[描画テスト](../Tests/AppMacrosTests/RenderSuppressionTests.swift)は macOS の View 階層にマウントし、比較中に `MainActor.assertIsolated()` を実行する。等しい入力での再評価抑制と、比較対象の変更による再評価を確認する。iOS の検証はビルドを対象とする。

SwiftUI の各 API の実行文脈は、その宣言で判断する。[WWDC25 “Explore concurrency in SwiftUI” 9:18][wwdc25-off-main] は MainActor 外で実行される処理も説明している。View の MainActor 継承や macOS の描画テストを、全 API・全 OS の内部実行経路への保証として扱わない。

## 一次情報

- [SE-0470: Global-actor isolated conformances][se-0470]
- [SE-0466: Control default actor isolation inference][se-0466]
- [SE-0449: Allow nonisolated to prevent global actor inference][se-0449]
- [Apple: View][view]
- [Apple: View.equatable()][equatable-method]
- [Apple: EquatableView][equatable-view]
- [WWDC24: What’s new in SwiftUI — 17:28][wwdc24-view]
- [WWDC25: What’s new in Swift — 33:04][wwdc25-conformance]
- [WWDC25: Explore concurrency in SwiftUI — 3:42][wwdc25-members]、[9:18][wwdc25-off-main]、[11:54][wwdc25-sendable]

[se-0470]: https://github.com/swiftlang/swift-evolution/blob/main/proposals/0470-isolated-conformances.md
[se-0466]: https://github.com/swiftlang/swift-evolution/blob/main/proposals/0466-control-default-actor-isolation.md
[se-0449]: https://github.com/swiftlang/swift-evolution/blob/main/proposals/0449-nonisolated-for-global-actor-cutoff.md
[view]: https://developer.apple.com/documentation/swiftui/view
[equatable-method]: https://developer.apple.com/documentation/swiftui/view/equatable()
[equatable-view]: https://developer.apple.com/documentation/swiftui/equatableview
[wwdc24-view]: https://developer.apple.com/videos/play/wwdc2024/10144/?time=1048
[wwdc25-conformance]: https://developer.apple.com/videos/play/wwdc2025/245/?time=1984
[wwdc25-members]: https://developer.apple.com/videos/play/wwdc2025/266/?time=222
[wwdc25-off-main]: https://developer.apple.com/videos/play/wwdc2025/266/?time=558
[wwdc25-sendable]: https://developer.apple.com/videos/play/wwdc2025/266/?time=714
