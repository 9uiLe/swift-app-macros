# AppMacros ドキュメント

AppMacros は、格納プロパティから `Equatable` 準拠を生成し、SwiftUI の入力比較による再評価抑制を支援する。導入方法と動作要件は [README](../README.md) を参照。

## 読み方

パッケージの利用者は利用ガイド、実装の開発者は設計概要、リリース担当者はリリース設計と運用から読む。

| ページ | 内容 |
| --- | --- |
| [利用ガイド](adoption.md) | API の選択、描画入力、コールバック、状態の所有、利用条件 |
| [設計概要](design.md) | API の役割、比較の契約、実装とテストの構成 |
| [`@Equatable`](equatable.md) | 隔離と配置、比較対象、型パラメーター、診断 |
| [`@SkipEquatable`](skip-equatable.md) | プロパティの除外と利用者が満たす条件 |
| [`EquatableBodyView`](equatable-body-view.md) | 比較境界を持つ View の定義と状態の扱い |
| [Actor 隔離の設計](actor-isolation.md) | 型・比較・準拠の隔離、Swift Evolution、Apple の API、WWDC |
| [リリース設計と運用](releasing.md) | 公開物と責務、バージョン、公開条件、コマンド、再開方法、GitHub の保護設定 |

開発時のコマンドと作業規約は [CONTRIBUTING.md](../CONTRIBUTING.md) を参照。
