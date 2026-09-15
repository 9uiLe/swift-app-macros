# リリース運用

`9uiLe/swift-app-macros` は公開の Swift パッケージである。所有者 `9uiLe` が変更をマージし、ローカルの GitHub CLI 認証でリリースする。GitHub Actions はビルドとテストを担当する。

## 構成

| 担当 | 処理 |
| --- | --- |
| 所有者 | バージョンを決める、準備 PR をマージする、公開コマンドを実行する |
| `scripts/release.py` | CHANGELOG と README の更新、PR 作成、公開前検証、タグと Release の作成 |
| GitHub Actions | PR と `master` の Swift ビルド・テスト、iOS Simulator ビルド、リリースツールのテスト |
| GitHub の保護設定 | PR と CI の要求、タグ操作の制限、公開後のタグと添付ファイルの固定 |

公開処理には所有者の認証を使う。Actions の `GITHUB_TOKEN` は GitHub App の installation access token であり、起動した所有者の管理者権限を引き継がない。CI の token は `contents: read` とし、リリース用の PAT や App 秘密鍵を Actions に保存しない。[^token] [^permissions]

## 前提条件

- Python 3.10 以降、Git、最新の GitHub CLI (`gh`) をローカルに用意する。
- `gh auth login --hostname github.com` で `9uiLe` として認証する。複数アカウントがある場合は `gh auth switch --hostname github.com --user 9uiLe` で切り替える。
- `GH_TOKEN` / `GITHUB_TOKEN` を環境変数に設定している場合、その認証が CLI の保存済み認証より優先される。スクリプトは実際の認証ユーザーを検査する。[^gh-environment]
- `origin` は `https://github.com/9uiLe/swift-app-macros.git`、末尾の `.git` を省いた HTTPS URL、または `git@github.com:9uiLe/swift-app-macros.git` とする。
- 作業ツリーの変更をコミットするか退避する。スクリプトは `origin/master` とタグを fetch し、コミット済みの文書を使う。
- 下記のリポジトリ保護設定を有効にする。公開時には Immutable releases の有効化も検査する。

コマンドはチェックアウト内で実行する。GitHub Actions 内では実行できない。公開の検証結果には GitHub-hosted runner の CI を使うため、公開操作を行うローカル環境に Swift や Xcode は必要ない。

## バージョンを準備する

変更を加える PR で `CHANGELOG.md` の `Unreleased` に利用者向けの項目を書く。破壊的変更には `Breaking` と利用者が必要とする対応を記す。Release の本文にも同じ内容を使うため、リンクは完全な URL で記述する。

バージョンは `X.Y.Z` 形式の安定版を指定する。`v` 接頭辞、先頭のゼロ、prerelease/build suffix は扱わない。公開 API の互換性に基づいて所有者が選ぶ。`0.x` の破壊的変更では minor を上げる。`swift-tools-version` と SwiftSyntax のバージョンはコンパイラー要件であり、パッケージのリリース番号とは独立している。

以下は `0.3.0` を準備する例である。以後は次の未使用バージョンへ置き換える。

```sh
./scripts/release.py prepare 0.3.0 --dry-run
./scripts/release.py prepare 0.3.0
```

`prepare` は最新の `origin/master` から `release/0.3.0` ブランチを作り、次をコミット・push して PR を開く。

- `Unreleased` の項目を日付付きの `0.3.0` セクションに移す。
- CHANGELOG の比較リンクと README の依存バージョンを更新する。

`--dry-run` は対象コミットとリリースノートを表示する。fetch は行うが、作業ファイル、ブランチ、コミット、リモートへの書き込みは変更しない。バージョンは既存の安定版タグと CHANGELOG の最新リリースより新しい必要がある。

PR の内容と CI を確認し、所有者がマージする。必要なチェックは `Swift package checks` と `Release tooling checks`。承認レビュー数は `0` で、レビューの会話は解決済みであることを要求する。管理者バイパスを使ったマージでも、公開スクリプトはマージ後の CI 成功を要求する。

## 検証して公開する

PR のマージ後、`master` の push による CI が成功したら実行する。

```sh
./scripts/release.py check 0.3.0
./scripts/release.py publish 0.3.0
```

`check` はリモートへの書き込みを行わず、公開対象の完全なコミット SHA、CI URL、リリースノートを表示する。PR が未マージの場合や `master` の CI が未完了の場合は停止する。

`publish` は検証を再実行してから公開する。タグが未作成なら、その時点の `origin/master` を対象とする。検証対象は次のとおり。

- 実際の認証ユーザーが `9uiLe` であり、公開先が公開リポジトリ `9uiLe/swift-app-macros`、既定ブランチが `master`、認証ユーザーが管理者である。
- 対象コミットの CHANGELOG の最新リリースと README の依存バージョンが指定バージョンに一致し、`Unreleased` が空である。
- `.github/workflows/ci.yml` の `master` push 実行が対象 SHA と一致し、その SHA に対する最新の実行・再実行が成功している。
- その実行の `Swift package checks` と `Release tooling checks` が、対象 SHA に対して両方成功している。
- 既存のタグ・Release がある場合、注釈付きタグのコミット、Release の作成者・対象・本文・公開状態が公開計画と一致する。

検証に通ると、所有者の GitHub API 認証で対象 SHA に注釈付きタグを作成する。リモートタグの指すコミットを照合し、`gh release create --verify-tag --draft` でドラフトを作成する。ドラフトとタグを再確認して公開し、Release が immutable であることを確認する。添付バイナリーは作成しない。

**SwiftPM はタグの作成時点でそのバージョンを取得できる。** GitHub Release の公開より先にタグが利用可能になるため、認証・文書・CI の検証はタグ作成前に完了させる。既存タグがある場合、Release API の `target_commitish` ではタグの位置を指定し直せないため、タグのコミットを別途照合する。[^swift-package] [^release-api] [^gh-release]

## 中断と再開

公開中に失敗した場合は、表示された原因を解消して同じコマンドを実行する。

```sh
./scripts/release.py publish 0.3.0
```

| 状態 | 再実行時の処理 |
| --- | --- |
| タグが未作成 | 最新の `master` と CI を検証して開始する |
| 注釈付きタグだけ作成済み | タグの元の SHA と CI を検証し、その SHA の Release を作る |
| ドラフト作成済み | 作成者・対象・本文とタグを照合して公開する |
| 同じ Release が公開済み | immutable とタグ・内容の一致を確認し、URL を表示して終了する |
| タグや Release が計画と異なる | 停止する。状態を確認し、正しい次のバージョンで準備する |

タグが作成済みなら、`master` が進んでもタグの元の SHA を使う。タグの削除、上書き、付け替えは行わない。検証中にタグが変わった場合も公開を停止する。

`prepare` は既存の `release/X.Y.Z` ブランチがある場合に停止する。コミットや push の途中で中断した場合は、そのブランチの差分と `gh pr list --head release/X.Y.Z` を確認する。push だけ失敗していれば作成済みコミットを push し、PR 作成だけ失敗していれば `gh pr create --base master --head release/X.Y.Z` で作成する。同じ準備ブランチを削除してやり直す必要はない。

## リポジトリの保護設定

| 設定 | 値 |
| --- | --- |
| Visibility | Public |
| 変更権限 | 所有者 `9uiLe` のみ。追加の collaborator と書き込み可能な deploy key を登録しない |
| `Protect master` | `master` の削除・force push を禁止。PR、最新のベースに対する両 CI チェック、会話の解決を要求。必須承認数 `0` |
| `master` のバイパス | Repository Admin、PR 経由のみ |
| `Protect release tags` | 全タグの作成・更新・削除・force push を制限。Repository Admin のみ常時バイパス |
| Actions | 既定 token は read-only、PR の承認を禁止。workflow も `contents: read`。checkout は完全な SHA へ固定し、資格情報を残さない |
| Immutable releases | 有効 |

公開リポジトリでは閲覧、fork、外部 PR は可能だが、元リポジトリへの変更や Release の作成には書き込み権限が必要である。個人所有リポジトリの collaborator は書き込み権限を持つため、所有者だけで運用する間は追加しない。[^personal] [^release-overview]

Actions の既定権限は、workflow に指定できる権限の上限ではない。GitHub App、deploy key、workflow の権限を変更する際は、書き込み経路が追加されるか確認する。タグの ruleset は Git ref を保護する機能であり、既存タグに対する Release 作成の認証主体を制限する機能ではない。[^permissions] [^rules]

Immutable releases は有効化後の新規リリースに適用され、公開後のタグと添付ファイルを固定する。リリースノートやタイトルなど一部のメタデータは変更できる。過去の `0.1.0` と `0.2.0` へ遡って適用されるものではない。[^immutable] [^immutable-settings]

## ツールの検証

```sh
python3 -m unittest discover -s scripts/tests -v
```

テストは一時 Git リポジトリと GitHub の模擬応答を使う。認証情報やネットワークは不要で、実リポジトリへタグや Release を作成しない。PR と `master` の CI でも同じテストを実行する。

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
