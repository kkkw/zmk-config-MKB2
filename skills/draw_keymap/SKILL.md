---
name: draw_keymap
description: keymap-drawer を使用して MKB2 のキーマップの SVG 画像をローカルで生成・更新するスキル
---

# ZMK キーマップ SVG 生成 スキル

このスキルは、`config/MKB.keymap` を編集した後に、`keymap-drawer` を使ってローカルで `.svg` 画像 (`keymap-svg/MKB.svg`) を即座に更新し、視覚的にキーマップの変更内容を確認したい場合に呼び出します。

## 実行する手順
以下のステップに沿って処理を実行してください。

1. **実行の確認**
   - ユーザーに「キーマップのSVG画像をローカルで更新しますか？」と確認を取る。

2. **keymap-drawer のパース実行**
   - `keymap` コマンドを実行し、`.keymap` から `.yaml` への変換を行います。
   ```bash
   keymap parse -c keymap-drawer/config.yaml -z config/MKB.keymap > keymap-drawer/MKB.yaml
   ```

3. **SVGの描画実行**
   - 生成された `.yaml` を元に SVG を描画します。
   ```bash
   keymap draw -j keymap-drawer/config.yaml keymap-drawer/MKB.yaml > keymap-svg/MKB.svg
   ```

4. **完了の報告と確認**
   - SVGファイル（`keymap-svg/MKB.svg`）が正常に更新されたことをユーザーに報告し、必要であればプレビューして変更内容を確認するよう促します。
   - ※注意: GitHub Actions (`.github/workflows/draw-keymap.yml`) によっても Push 時にリモートで自動生成されますが、このスキルは「ローカルでの作業中・コミット前」のプレビューに最適です。
