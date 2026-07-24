---
name: sync_zmk_smart_merge
description: フォーク元の最新状態にリセットしつつ、現在のキーマップ（bindings）のみを維持し、エンコーダー設定等はフォーク元の最新を適用する自律的自己改善型スキル
---

# ZMK スマートマージ同期 スキル (自律的自己改善型)

このスキルは、ZMKのフォーク元（Upstream）の最新設定（エンコーダー設定や新しいマクロ・レイヤー定義など）を取り込みつつ、**自分がカスタマイズしたキー配列（`bindings`）だけは維持したい**場合に使用します。

## 実行する手順
エージェントは以下の手順に沿って処理を行い、もし予測せぬエラーや構造変更に直面した場合は、**自律的に解決策を導き出し、この SKILL.md 自体を更新して学習**してください。

### 1. 現在のキーマップの退避
- `config/MKB.keymap` を `tmp/MKB_backup.keymap` にコピーして退避します。

### 2. フォーク元（Upstream）へのハードリセット
- `git remote -v` で `upstream` を確認（無ければ `git remote add upstream https://github.com/te9no/zmk-config-MKB2.git` を追加）。
- `git fetch upstream`
- `git reset --hard upstream/main` (ブランチ名は適宜確認)
- これにより、エンコーダーの `sensor-bindings` やその他すべての設定がフォーク元の最新状態になります。

### 3. キー配列（bindings）のスマートマージ
- **【自己改善による新手法】** ユーザーが独自のレイヤー（例: `symbol_layer`）やマクロを追加している場合、単純にフォーク元ファイルへ `bindings` だけを上書きするとレイヤー構造が崩れるため、以下の手法でマージします。
- 退避した `tmp/MKB_backup.keymap` をベースとして、`config/MKB.keymap` に上書きコピーします（これによりユーザーの独自レイヤーや `#define` が完全に維持されます）。
- ただし、エンコーダーなどの設定をフォーク元の最新に合わせるため、`config/MKB.keymap` 内のすべての **`sensor-bindings = < ... >;`** の行を、フォーク元の最新のものに置換します。（必要に応じて特定レイヤーのみ独自の `&scroll_encoder` に戻します）
- また、フォーク元で新たに追加されたグローバル設定（例: `&mt { ... }` など）があれば、それを適宜ユーザーのファイルに追記して統合します。

### 4. 安定化設定の再適用（自律的自己改善による追加ルール）
- フォーク元をリセットすると安定化チューニングが失われるため、以下の処理を自動で行います。
  - `config/west.yml` の ZMK `revision` を安全なバージョン（例: `dc5b3d5b15ccbfac85c167c57fb3ab1485fdf7f0`）に固定する（誤ダウングレード回避）。
  - `boards/shields/MKB/MKB_L_Base.conf` と `MKB_R_Base.conf` に以下の安定化チューニングを自動マージする：
    - `CONFIG_ZMK_KSCAN_CHARLIEPLEX_WAIT_...` (20/2: チャタリング防止)
    - `CONFIG_BT_L2CAP_TX_BUF_COUNT=20` 等のBLEバッファ拡張（トラックボール・エンコーダーのバースト・フリーズ対策）
    - 右手側の `CONFIG_ZMK_SLEEP=n` (ディープスリープによる左手ハング回避)
    - 左手側のみ `CONFIG_ZMK_BLE_EXPERIMENTAL_CONN=y`
    - 右手側の通信幅 `CONFIG_BT_PERIPHERAL_PREF_MAX_INT=24`

### 4. 検証と自律的自己改善 (CRITICAL)
- 置換後、ファイルが正しい DeviceTree 構文（`dts`）を維持しているか確認します（カッコの対応関係やセミコロンの有無など）。
- 構文エラーや、フォーク元でのレイヤー名の変更（例: `default_layer` が `base_layer` に変わった等）によりマージが失敗した場合、**エージェントは自ら構造を分析し、新しいマージ手法を編み出してください**。
- **【自己改善ルール】** もし新しいマージ手法や構文の変更ルールを発見した場合、次回以降も自動で対応できるよう、**この `SKILL.md` の「スマートマージ」の項目をエージェント自身で書き換え、学習内容を追記してください。**

### 5. コミットとPush
- `git add config/MKB.keymap`
- `git commit -m "Sync with upstream, but keep custom key bindings"`
- `git push -f origin main`
- ユーザーに完了を報告し、必要であれば `draw_keymap` スキルを提案して変更が壊れていないか視覚的な確認を促します。
