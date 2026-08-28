# 反復ビルド・書き込み経路の調査

調査日: 2026-08-28

## 現状

- `.github/workflows/build.yml` は `te9no/zmk-workspace` の再利用可能workflowを呼び出す。
- 調査開始時は通常の push と定期実行が `target = all` となり、`build.yaml` の17ターゲットを最大4並列でビルドしていた。
- 2026-08-29に既定ターゲットを `MKB_L_MODULE_ENC` と `MKB_R_MODULE_TBv4` の2つへ変更した。手動実行で `target = all` を指定した場合は、引き続き全ターゲットをビルドできる。
- 直近の全体ビルドは約11〜13分。2026-08-28のrun 84では、左 ENC のビルドジョブ単体は約2分14秒だった。
- workflow_dispatch は target を正規表現で絞り込み、成果物の自動コミットを無効にできる。
- `firmware/zmk-config-MKB2/<branch>/` にはActionsが生成したUF2が保存されている。

## 推奨する二つの経路

### 1. GitHub Actionsの単体ビルド

通常は左エンコーダーと右トラックボールv4の2つが選択される。左エンコーダーだけを調整するときは次を指定できる。

- `target`: `^MKB_L_MODULE_ENC$`
- `commit_firmware`: `false`

全ターゲットをビルドせず、UF2はworkflow artifactとして取得する。安定した候補だけをmainへ統合し、最後に全ターゲットをビルドする。

push時も既定の2ターゲットだけをビルドする。ほかのモジュールに影響する変更では、手動実行の `target` に `all` を指定して全体ビルドを行う。

### 2. ローカル増分ビルドと直接書き込み

Docker Desktopと公式ZMKビルドコンテナを使い、west workspace、依存モジュール、`MKB_L_MODULE_ENC` 専用build directoryを永続化する。初回準備は時間とディスク容量を使うが、以後は同じbuild directoryを指定した増分ビルドにより待ち時間を短縮できる。

生成したUF2は、利用者が左コントローラーをブートローダーモードへ入れた後、macOSの `/Volumes` 以下へ現れるUF2ドライブへコピーできる。物理的なリセット操作は利用者が行う。エージェントは対象とマウント状態を確認した上でコピーを実行できる。

## 現在のローカル環境

- macOS arm64
- Docker CLI/Desktopはインストール済みだが、確認時はdaemon停止中
- `west`、`zmk`、`ninja`、Zephyr SDKは未導入
- GitHub CLIはインストール済みだが、保存された認証が無効
- ブートローダーのUF2ドライブは未接続

Docker経路を採用する場合はDocker Desktopを起動し、コンテナがarm64環境でこのforkと外部モジュールをビルドできることを最初に確認する。GitHub artifactをCLIで取得する場合は、先に `gh auth refresh -h github.com` で再認証する。

2026-08-29に `scripts/build-zmk-local.sh` と `scripts/build-zmk-container.sh` を追加した。Docker named volume `zmk-config-mkb2-workspace` へwest依存関係、ccache、左ENC・右TBv4それぞれのbuild directoryを保持し、生成したUF2だけを `build/local/` へコピーする。通常は次のコマンドを使用する。

```bash
scripts/build-zmk-local.sh --target MKB_L_MODULE_ENC
scripts/build-zmk-local.sh --target MKB_R_MODULE_TBv4
```

初回のwest依存取得と左ENCビルドは完了済み。右TBv4の初回build directory生成は約20秒、変更なしの左ENC再ビルドは1.44秒、両ターゲット連続再ビルドは1.91秒だった。生成物は次のとおり。

- `build/local/MKB_L_MODULE_ENC.uf2`: 921,600バイト
- `build/local/MKB_R_MODULE_TBv4.uf2`: 651,264バイト

既存設定に由来するdeprecated symbol、Kconfig依存不成立、devicetree unit-addressなどのwarningは残る。ローカルビルド導入による新規エラーではないが、今後の設定変更時はwarningの増減も確認する。

## 既存スクリプトの問題

`scripts/flashgh.ps1` と `scripts/flash.ps1` は、そのままでは現在の環境に使用できない。

- `pwsh` が開発機にない。
- Windowsのドライブ表現を前提としている。
- 存在しない `MKB2` remote と古いbranch名を参照する。
- 現在のActions artifact名と一致しない。
- 呼び出し側の `-Uf2File` と受け側の `-Uf2FileName` が一致しない。
- 対象選択が `JOY` と `R` に限定され、左 ENC を選択できない。

これらを部分修正せず、macOS向けに対象UF2、artifact名、マウントされたUF2ドライブを明示的に検証する `scripts/flash-uf2-macos.sh` を追加した。最初に `--dry-run` を実行し、実際のコピーには対話で `FLASH` の入力を要求する。

## 参照

- [ZMK: Container Setup](https://zmk.dev/docs/development/local-toolchain/setup/container)
- [ZMK: Building and Flashing](https://zmk.dev/docs/development/local-toolchain/build-flash)
- [GitHub Actions run 84](https://github.com/kkkw/zmk-config-MKB2/actions/runs/33140256957)
