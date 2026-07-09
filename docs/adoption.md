# 採用ガイドと既知の制限

> [ドキュメント目次](README.md) ・ [README](../README.md)

## Safe adoption checklist

- Leaf views with only `let` inputs → prefer `EquatableBodyView`
- Intermediate views → `@Equatable` + `.equatable()` at every call site
- Closure props that capture **value snapshots** → include those values in compared `let` state, or use `@SkipEquatable` knowing they are excluded from diff
- Non-Sendable stored properties → `@SkipEquatable` or make the type `Sendable`
- Custom `DynamicProperty` wrappers → `@SkipEquatable` (not in allowlist)
- Typealias-hidden closure types → `@SkipEquatable` explicitly
- Write `: View` / `: EquatableBodyView` directly on the struct (not via refined protocols)

## 既知の制限（設計上の割り切り）

- **typealias 越しのクロージャ**は構文的に検出できない → `@SkipEquatable`
- **非 Sendable な stored property（SE-0434）** → `@SkipEquatable` または `Sendable` 化
- **stale closure 不変条件**: 除外したクロージャが値スナップショットをキャプチャする場合、
  その値を比較対象の stored property に含めること
- **`@SkipEquatable` は複数バインディングに付けられない** → 宣言を分割
- **手書き `static func ==` と `@Equatable` の併用不可** → 同じ編集で削除
- **`body: some View` だが `: View` 未宣言** → マクロが warning（`@Equatable(.nonisolated)` または struct に `: View`）
- **別 extension 内の `body` / protocol 経由準拠** → SE-0389 により検出不能

## 関連

- [なぜ Equatable マクロなのか](rationale.md)
- [`@Equatable`](equatable.md) ・ [`@SkipEquatable`](skip-equatable.md) ・ [`EquatableBodyView`](equatable-body-view.md)
