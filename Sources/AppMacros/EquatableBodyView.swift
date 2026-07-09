#if canImport(SwiftUI)
    import SwiftUI

    /// `.equatable()` を「定義側の body」に焼き込み、使用側の付け忘れ（サイレント失敗）を
    /// 原理的に不可能にする `View`（ADR-0015 案G）。
    ///
    /// 通常の `@Equatable` + `.equatable()` は 2 箇所セットで書く必要があり、使用側で
    /// `.equatable()` を忘れると「コンパイル成功・無警告・効果ゼロ」のサイレント失敗になる。
    /// `EquatableBodyView` は本体を `body` ではなく `equatableBody` に書かせ、`body` の既定実装が
    /// `_EquatableHost(host: self).equatable()` を返すことで、使用側は通常の `Child(...)` 記法の
    /// まま再描画抑制が効く。
    ///
    /// **適用範囲は stateless + `@State` 限定**。`@StateObject` / `@ObservedObject` / `@Binding` は
    /// 非 Equatable ゆえ比較に反映されず stale バグになるため、`@Equatable` が診断エラーにする。
    /// また本体を `body` に直書きすると既定実装の `.equatable()` ゲートをバイパスするため、これも
    /// `@Equatable` が診断エラーにする。
    ///
    /// ```swift
    /// @Equatable
    /// struct ChipView: EquatableBodyView {
    ///     let title: String
    ///     let onTap: () -> Void                     // クロージャ型は自動で比較対象外
    ///
    ///     var equatableBody: some View {            // body ではなく equatableBody に書く
    ///         Button(title, action: onTap)
    ///     }
    /// }
    ///
    /// // 使用側は .equatable() 不要:
    /// ChipView(title: "x", onTap: onTap)
    /// ```
    ///
    /// > 再描画抑制のランタイム効果（親 30 回 invalidate → `equatableBody` 1 回・overhead 無視可）は
    /// > usapo-ios ADR-0015 のシミュレータ実測で検証済み。本パッケージのテストはコンパイル・展開・
    /// > 診断の正しさを担保する。
    public protocol EquatableBodyView: View, Equatable {
        associatedtype EquatableBody: View
        /// 重い本体をここに書く（`body` は既定実装が `.equatable()` 注入に専有している）。
        @ViewBuilder @MainActor var equatableBody: EquatableBody { get }
    }

    extension EquatableBodyView {
        public var body: some View {
            _EquatableHost(host: self).equatable()
        }
    }

    /// `equatableBody` を評価する内部ラッパー。`==` は準拠型（`@Equatable` 生成）に委譲するため、
    /// 入力が等価な限り SwiftUI は `body`（= `equatableBody`）の評価をスキップできる。
    ///
    /// `host` は `nonisolated(unsafe)`。不変条件として「準拠型の比較対象プロパティは値型 / Sendable のみ」
    /// を前提とする（`@MainActor` 隔離下で `nonisolated ==` から安全に読むため・SE-0434）。
    private struct _EquatableHost<Content: EquatableBodyView>: View, Equatable {
        nonisolated(unsafe) let host: Content

        nonisolated static func == (lhs: Self, rhs: Self) -> Bool {
            lhs.host == rhs.host
        }

        var body: Content.EquatableBody {
            host.equatableBody
        }
    }
#endif
