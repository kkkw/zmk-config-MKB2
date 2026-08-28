---
name: build_firmware
description: Dockerの永続workspaceを使いMKB2の対象UF2をローカル増分ビルドするスキル
---

# MKB2 ローカルファームウェアビルド

## 前提確認

1. Docker Desktopが起動していることを `docker info` で確認する。
2. `config/west.yml` と対象の `build.yaml` 定義を確認する。
3. 通常の反復では左ENCまたは右TBv4だけを選び、無関係なターゲットをビルドしない。

## ビルド

左エンコーダーは次を実行する。

```bash
scripts/build-zmk-local.sh --target MKB_L_MODULE_ENC
```

右トラックボールv4は次を実行する。

```bash
scripts/build-zmk-local.sh --target MKB_R_MODULE_TBv4
```

両方が必要な場合は `--target both` を指定する。生成物は `build/local/<artifact>.uf2` に出力される。

## 更新とクリーンビルド

- `config/west.yml` が変わると、自動的に `west update` を実行する。
- リモート側の状態を明示的に再確認するときは `--update` を指定する。
- キャッシュやCMake構成が疑わしい場合だけ `--pristine` を指定する。
- 通常のキーマップ調整では、どちらも指定せず同じbuild directoryを再利用する。

## 検証

- コマンド終了時に対象UF2のSHA-256が表示されることを確認する。
- UF2が存在しても、ビルドログにwarningやerrorがないか確認する。
- 実機書き込みには `skills/flash_firmware/SKILL.md` と `scripts/flash-uf2-macos.sh` を使う。
