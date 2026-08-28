# 開発への参加

この文書は、新規開発者がこのリポジトリで作業を始めるための最小限の手順である。
AIを使う場合は、追加で [AGENTS.md](AGENTS.md) を読む。

## 最初に読むもの

1. [README.md](README.md)：プロダクトの現在地
2. この文書：日常の作業フロー
3. 対象のGitHub Issue：目的、受け入れ条件、対象外、制約
4. 関連する既存コード・文書・プルリクエスト

## 作業の流れ

```text
Issue下書き → Backlog → Ready → In Progress → In Review → Done
```

| 状態 | 意味 | 移行の条件 |
|---|---|---|
| Backlog | 候補。優先順位または内容が未確定 | IssueをProjectへ追加 |
| Ready | 目的、受け入れ条件、対象外が揃った | 要件レビューを終える |
| In Progress | 調査または実装を開始した | 着手を承認する |
| In Review | PRまたはユーザー確認を待つ | 変更と検証結果を提出する |
| Blocked | 判断・外部作業・技術的障害を待つ | ブロッカーと再開条件をIssueに残す |
| Done | IssueがClosedで完了として残る | マージまたは明示的な完了判断 |

Projectの `Status` が進捗の正本であり、IssueのOpen / Closedが完了の最終事実である。

## Issueを作る・選ぶ

実装、調査、バグ、保守は原則としてIssueに紐付ける。Issueには次を含める。

- 目的または解決したい問題
- 検証可能な受け入れ条件
- 明示的な対象外
- 重要な制約と関連情報

次の場合だけ、Issueを作らずに扱える。

- ユーザーが直接依頼した、範囲が明確で小さな文書・設定修正
- 一回限りの読み取り調査

ただし、独立した判断、レビュー、追跡が必要になった時点でIssueに切り替える。

## 実装とレビュー

1. `Ready`のIssueを選び、必要なら設計レビューを行う。
2. `type/<issue番号>-<短い説明>` の形式でブランチを作る。`type` は
   `feature`、`fix`、`chore`、`research` のいずれかを使う。
3. 範囲を守って変更し、実装に付随する文書・テストを更新する。
4. 利用可能な検査を実行し、実行できない検査は理由を記録する。
5. PRを作成し、PRテンプレートの受け入れ条件と検証欄を埋める。完了するIssueには
   `Fixes #<Issue番号>` を記載する。
6. Projectを`In Review`へ移す。レビュー後にマージし、IssueがClosedになれば
   Projectは自動で`Done`になる。

レビューには三つの段階がある。

- 要件レビュー：`Backlog`から`Ready`へ移す前
- 設計レビュー：後戻りしにくい判断を伴う実装の開始前
- コードレビュー：PR作成後、`In Review`で実施

## 自動化の範囲

GitHub Projectsは、次だけを自動化する。

| イベント | 自動処理 |
|---|---|
| OpenなIssueの作成・更新 | Projectへ追加 |
| Projectへ追加 | Statusを`Backlog`にする |
| IssueをClosed | Statusを`Done`にする |

`Ready`、`In Progress`、`In Review`、`Blocked`への移動は判断を伴うため自動化しない。
`Done`へのStatus変更だけでIssueをClosedにする自動化も使わない。

AIは人間が明示的に起動する。Issue作成、PR作成・更新、マージ、デプロイなどの外部操作を
イベント起点で自律実行しない。将来のGitHub Actionsは、Lint、型検査、テスト、ビルドなど
決定的な検査に限定して導入する。
