# リリース設計と運用

AppMacros は、公開リポジトリ `9uiLe/swift-app-macros` から配布する Swift パッケージである。所有者 `9uiLe` が公開バージョンを決定し、GitHub Actions で検証したコミットを、ローカルの GitHub CLI 認証で公開する。

## 公開物と責務

一つのリリースは、同じバージョン名を持つ注釈付き Git タグと GitHub Release で構成する。タグは配布するソースのコミットを指し、Release はその変更履歴を掲載する。配布対象はソースコードで、バイナリーの添付は行わない。

**SwiftPM は、リモートにタグが作成された時点でそのバージョンを取得できる。** このため、公開に必要な検証はタグ作成前に完了させる。GitHub Release はドラフトとして作成し、タグとの一致を確認してから公開する。[^swift-package] [^gh-release]

| 担当 | 責務 |
| --- | --- |
| 所有者 `9uiLe` | バージョンの決定、PR のマージ、公開コマンドの実行 |
| ローカルの `scripts/release.py` | バージョン文書と PR の準備、公開条件の検査、タグ・Release の作成 |
| GitHub Actions | PR と `master` のビルド・テスト |
| GitHub のアクセス権と保護設定 | 書き込み主体の制限、マージ条件の適用、公開済み成果物の固定 |

公開操作には、GitHub CLI が認証した所有者の権限を使う。CI は GitHub-hosted runner で実行し、`GITHUB_TOKEN` の権限を `contents: read` とする。所有者のトークンやリリース用 App の秘密鍵を Actions に保存しない。

`GITHUB_TOKEN` は GitHub App の installation access token であり、workflow を起動した所有者の管理者ロールは持たない。所有者の認証と CI の認証をそれぞれの責務に対応させる。[^token] [^permissions]

## バージョンと公開対象

| 情報 | 正本 |
| --- | --- |
| パッケージのバージョン | `X.Y.Z` 形式の Git タグ名 |
| 公開するソース | タグが直接指すコミットの完全な SHA |
| リリース日・利用者向けの変更履歴 | 対象コミットの `CHANGELOG.md` |
| インストールするバージョン | 対象コミットの `README.md` の SwiftPM 依存指定 |
| 検証結果 | 同じ SHA に対する `.github/workflows/ci.yml` の `master` push 実行 |

バージョンは所有者が公開 API の互換性に基づいて選ぶ。`0.x` の破壊的変更では minor を上げる。スクリプトが扱う形式は `0.3.0` のような安定版番号で、`v` 接頭辞、先頭のゼロ、prerelease/build suffix は使用しない。`swift-tools-version` と SwiftSyntax のバージョンはコンパイラー要件を表す。

タグが未作成の場合、公開対象はコマンドが取得した `origin/master` の先端とする。タグが作成済みの場合は、そのタグのコミットを使う。どちらも `master` の履歴に含まれることを要求する。

## コマンド

リポジトリのルートで実行する。以下の `X.Y.Z` は、操作対象のバージョン番号へ置き換える。

| コマンド | 結果 |
| --- | --- |
| `./scripts/release.py prepare X.Y.Z --dry-run` | 準備元のコミットとリリースノートを表示する |
| `./scripts/release.py prepare X.Y.Z` | 文書を更新した `release/X.Y.Z` ブランチをコミット・push し、PR を作成する |
| `./scripts/release.py check X.Y.Z` | 公開条件を検査し、対象 SHA・CI URL・リリースノートを表示する |
| `./scripts/release.py publish X.Y.Z` | 公開条件を検査し、タグと Release を公開する |

すべてのコマンドが `origin/master` とタグを fetch する。`prepare --dry-run` と `check` は、作業ファイルの編集、作業ブランチの作成、リモートへの書き込みを行わない。

### 実行環境

ローカルには Python 3.10 以降、Git、最新の GitHub CLI (`gh`) を用意する。Swift と Xcode は CI で使用する。スクリプトは GitHub Actions 内での実行を拒否する。

GitHub CLI では所有者として認証する。

```sh
gh auth login --hostname github.com
```

複数のアカウントを登録している場合は、使用するアカウントを指定する。

```sh
gh auth switch --hostname github.com --user 9uiLe
```

`GH_TOKEN` / `GITHUB_TOKEN` 環境変数は CLI の保存済み認証より優先される。スクリプトは API を使って実際の認証ユーザーを検査する。[^gh-environment]

作業ツリーは変更のない状態にし、`origin` には次のいずれかを設定する。

- `https://github.com/9uiLe/swift-app-macros.git`
- `https://github.com/9uiLe/swift-app-macros`
- `git@github.com:9uiLe/swift-app-macros.git`

### 1. リリース内容を準備する

機能や修正の PR で、`CHANGELOG.md` の `Unreleased` に利用者向けの項目を記載する。破壊的変更には `Breaking` と利用者に必要な対応を書く。Release の本文にも同じ文章を掲載するため、リンクは完全な URL を使う。

所有者はバージョンを選び、`prepare --dry-run` で内容を確認してから `prepare` を実行する。準備するバージョンには、既存の安定版タグと CHANGELOG の最新リリースより新しく、タグ・Release・準備ブランチが存在しない番号を指定する。

`prepare` は `origin/master` から `release/X.Y.Z` を作成する。`Unreleased` の項目を日付付きのリリースセクションへ移し、比較リンクと README の依存バージョンを更新して、`master` を対象とする PR を作成する。

### 2. PR をマージする

所有者はリリースノート、互換性情報、依存バージョンを確認する。レビューの会話を解決し、`Swift package checks` と `Release tooling checks` が成功した PR をマージする。必須承認レビュー数は `0` とする。

`master` への push によって CI が実行される。公開には、このマージ後のコミットに対する検証結果を使う。

### 3. 検証して公開する

`master` の CI 成功後、`check` で対象 SHA・CI URL・リリースノートを確認し、`publish` を実行する。例えば `0.3.0` の公開コマンドは次のとおり。

```sh
./scripts/release.py check 0.3.0
./scripts/release.py publish 0.3.0
```

`publish` は実行時に公開条件を検査する。事前に実行した `check` の結果を使い回さない。公開が完了すると Release の URL を表示する。

## 公開条件

| 検査対象 | 成立条件 |
| --- | --- |
| 認証と公開先 | 認証ユーザーが `9uiLe`。リポジトリが公開の `9uiLe/swift-app-macros`、既定ブランチが `master`、所有者に管理者権限がある |
| 成果物の保護 | リポジトリの Immutable releases が有効 |
| コミット | 完全な SHA で特定でき、`master` の履歴に含まれる |
| 文書 | CHANGELOG の最新リリースと README の依存バージョンが指定番号に一致する。日付とリリース項目が有効で、`Unreleased` が空である |
| CI 実行 | 有効な `ci.yml` の、対象リポジトリ・`master`・push イベント・対象 SHA が一致する実行のうち、最新の実行・再実行が成功している |
| CI ジョブ | その実行に含まれる `Swift package checks` と `Release tooling checks` が、対象 SHA に対してそれぞれ一つ存在し、両方成功している |
| 作成済みのタグ | 指定バージョン名の注釈付きタグであり、コミットを直接指す |
| 作成済みの Release | 指定タグ、対象 SHA、作成者 `9uiLe`、CHANGELOG 本文が一致する。prerelease や添付ファイルがない |

未公開のバージョンは、ほかの既存安定版タグより新しいことも要求する。公開済み Release の再実行では、その内容と immutable 状態を検査して終了する。

検査に通ると、所有者の API 認証で注釈付きタグを作成し、タグの SHA を照合してドラフトを作成する。公開直前にもタグとドラフトを照合し、公開後に Release の immutable 状態とタグの SHA を確認する。

GitHub の Release API は、既存タグの位置を `target_commitish` で変更しない。`--verify-tag` はリモートタグの存在を検査する。対象コミットとの一致は、スクリプトがタグを読み取って確認する。[^release-api] [^gh-release]

## 中断した操作の扱い

### 公開の再実行

エラーの原因を解消した後、同じバージョンで `publish` を実行する。スクリプトは GitHub のタグと Release の状態から再開位置を決める。

| GitHub 上の状態 | 処理 |
| --- | --- |
| タグ・Release がない | 最新の `origin/master` と CI を検証して開始する |
| 注釈付きタグがある | タグのコミットと CI を検証し、そのコミットのドラフトを作成する |
| 対応するドラフトがある | タグ、作成者、対象 SHA、本文を照合して公開する |
| 対応する Release が公開済み | タグ、内容、immutable 状態を確認し、URL を表示して終了する |
| タグや Release が公開条件を満たさない | 自動処理を停止する |

タグ作成後は、`master` が進んでも同じタグのコミットを使う。タグを削除・上書き・付け替えする処理は持たない。新規タグの作成前に `master` が変わった場合や、検証中にタグが変更・削除された場合も停止する。

認証付きの Release 一覧にはドラフトも含まれるため、ドラフトの検出にはこの一覧を使う。タグ指定の Release 取得 API は公開済み Release 用である。[^release-api]

### 準備の再開

`prepare` は、同名の準備ブランチがある場合に停止する。中断時は `release/X.Y.Z` の差分・コミットと、`gh pr list --head release/X.Y.Z` の結果を確認する。

- 文書更新やコミットが未完了なら、そのブランチで内容を確認してコミットする。
- push が未完了なら、作成済みコミットを所有者の認証で push する。
- PR が未作成なら、`gh pr create --base master --head release/X.Y.Z` で作成する。

## GitHub の保護設定

アクセス制御は GitHub の設定で適用する。スクリプトの実行時検査は、所有者が誤った対象や未検証のコミットを公開することを防ぐための条件である。

| 設定 | 値 |
| --- | --- |
| Visibility | Public |
| 書き込み主体 | 所有者 `9uiLe`。追加の collaborator、書き込み可能な deploy key、書き込み権限を持つ GitHub App を登録しない |
| `Protect master` | `master` の削除・force push を禁止。PR、最新のベースに対する両 CI チェック、レビューの会話の解決を要求。必須承認数 `0` |
| `master` のバイパス | Repository Admin が PR 経由で利用可能 |
| `Protect release tags` | 全タグの作成・更新・削除・force push を制限。Repository Admin のみ常時バイパス可能 |
| Actions | 既定 token は read-only、PR 承認を禁止。workflow は `contents: read`、checkout は完全な SHA に固定し、資格情報を残さない |
| Immutable releases | 有効 |

公開リポジトリでは閲覧、fork、外部 PR を受け付ける。個人所有リポジトリの collaborator には書き込み権限が付くため、所有者のみの運用では追加しない。Release の作成にも書き込み権限が必要となる。[^personal] [^release-overview]

Actions の既定 token 権限は、workflow に指定できる権限の上限ではない。workflow や App の設定を変更する場合は、書き込み権限を持つ主体を確認する。タグの ruleset が制限するのは Git ref の操作であり、既存タグに対する Release の作成権限は別途管理する。[^permissions] [^rules]

管理者の PR バイパスはマージ時に利用できる。公開スクリプトは、バイパスの利用にかかわらず対象コミットの CI 成功を要求する。

Immutable releases は、有効化後に作成するリリースの公開済みタグと添付ファイルを固定する。タイトルやリリースノートなど一部のメタデータは編集可能で、有効化前のリリースには遡って適用されない。[^immutable] [^immutable-settings]

## 実装と検証

| ファイル | 役割 |
| --- | --- |
| [`scripts/release.py`](../scripts/release.py) | 文書の生成、公開計画の検証、所有者の認証による GitHub 操作 |
| [`scripts/tests/test_release.py`](../scripts/tests/test_release.py) | 文書整合性、認証・CI・タグ不一致時の停止、公開の再実行、PR 準備の検証 |
| [`.github/workflows/ci.yml`](../.github/workflows/ci.yml) | PR と `master` push の Swift・リリースツール検証 |

リリースツールのテストは次のコマンドで実行する。

```sh
python3 -m unittest discover -s scripts/tests -v
```

テストは一時 Git リポジトリと GitHub の模擬応答を使用し、認証情報やネットワーク接続を必要としない。Swift パッケージと iOS Simulator ビルドの検証手順は [CONTRIBUTING.md](../CONTRIBUTING.md) を参照。

## 一次情報

[^token]: GitHub Docs, [GITHUB_TOKEN](https://docs.github.com/en/actions/concepts/security/github_token).
[^permissions]: GitHub Docs, [Workflow syntax — permissions](https://docs.github.com/en/actions/reference/workflows-and-actions/workflow-syntax#permissions).
[^gh-environment]: GitHub CLI, [Environment variables](https://cli.github.com/manual/gh_help_environment).
[^personal]: GitHub Docs, [Permission levels for a personal account repository](https://docs.github.com/en/account-and-profile/reference/permission-levels-for-a-personal-account-repository).
[^release-overview]: GitHub Docs, [About releases](https://docs.github.com/en/repositories/releasing-projects-on-github/about-releases).
[^rules]: GitHub Docs, [Available rules for rulesets](https://docs.github.com/en/repositories/configuring-branches-and-merges-in-your-repository/managing-rulesets/available-rules-for-rulesets) and [Granting bypass permissions](https://docs.github.com/en/repositories/configuring-branches-and-merges-in-your-repository/managing-rulesets/creating-rulesets-for-a-repository#granting-bypass-permissions-for-your-branch-or-tag-ruleset).
[^release-api]: GitHub REST API, [Create a release](https://docs.github.com/en/rest/releases/releases#create-a-release) and [List releases](https://docs.github.com/en/rest/releases/releases#list-releases).
[^gh-release]: GitHub CLI, [gh release create](https://cli.github.com/manual/gh_release_create) and [gh release edit](https://cli.github.com/manual/gh_release_edit).
[^immutable]: GitHub Docs, [Immutable releases](https://docs.github.com/en/code-security/concepts/supply-chain-security/immutable-releases).
[^immutable-settings]: GitHub Docs, [Preventing changes to your releases](https://docs.github.com/en/code-security/how-tos/secure-your-supply-chain/establish-provenance-and-integrity/prevent-release-changes).
[^swift-package]: Apple Developer Documentation, [Publishing a Swift package with Xcode](https://developer.apple.com/documentation/xcode/publishing-a-swift-package-with-xcode).
