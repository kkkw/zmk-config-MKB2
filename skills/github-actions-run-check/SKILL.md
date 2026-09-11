---
name: github-actions-run-check
description: この ZMK 設定プロジェクトの GitHub Actions を読み取り専用で確認し、失敗、スキップ、生成物なしを区別して原因と次の対応を整理する。
---

# GitHub Actions 実行確認

このリポジトリで GitHub Actions の確認を依頼されたときに使う。既定では診断のみ行い、再実行、キャンセル、生成物の削除、設定変更、コミット、プッシュはしない。

## 手順

1. `git status --short` で作業ツリーを確認し、既存の未追跡・未コミット変更を無断で変更しない。
2. `gh run list --repo kkkw/zmk-config-MKB2 --workflow build.yml --limit 10` で直近のビルドを確認する。キーマップ図なら `draw-keymap.yml` を使う。
3. 対象 run について `gh run view RUN_ID --repo kkkw/zmk-config-MKB2 --json conclusion,event,headSha,jobs,url,workflowName` を取得し、最初に失敗した実質的なジョブと step を特定する。後処理の失敗と混同しない。
4. `gh api repos/kkkw/zmk-config-MKB2/actions/runs/RUN_ID/artifacts` で生成物を確認する。run が success でも、ビルドジョブが全て skipped、matrix の対象数が 0、または artifacts が 0 なら「成功したが生成物なし」と報告する。
5. 失敗時は `gh run view RUN_ID --repo kkkw/zmk-config-MKB2 --log-failed` を調べ、step 名、最初のエラー、終了コードを残す。ログが大きい場合は `error`、`failed`、`Traceback`、`exit code`、`No build targets` の周辺を絞り込む。
6. `.github/workflows/build.yml` が reusable workflow (`uses: .../.github/workflows/...@...`) を呼ぶ場合、呼び出し側の入力だけで判断しない。必要に応じて参照先 workflow と関連スクリプトを確認し、checkout、provenance、matrix、入力検証、実ビルドのどこで止まったかを分ける。
7. 結果を「run URL・commit・イベント・結論・失敗ジョブ/step・生成物数・原因・確度・次の対応」に整理する。コード上の事実と、実機や外部状態が必要な未検証事項を分ける。

## このプロジェクト固有の注意

- 通常の push ビルド対象は `MKB_L_MODULE_ENC` と `MKB_R_MODULE_TBv4`。対象フィルタの変更では、matrix が 0 件になっていないか確認する。
- build workflow は `te9no/zmk-workspace` の reusable workflow を使用する。ビルド本体より前の入力取得や provenance で失敗していないかを優先確認する。
- GitHub CLI の認証・ネットワークエラーと、Actions 自体の失敗を区別する。
- 修正・再実行・プッシュが必要そうでも、診断依頼だけなら提案に留め、利用者の明示的な依頼を待つ。
