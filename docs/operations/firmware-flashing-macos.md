# macOSでのファームウェアビルド・書き込み

この手順は、MeKaBuの左エンコーダー構成と右トラックボールv4構成を、macOSからビルドしてXIAO nRF52840へUF2形式で書き込むためのものである。

## 対象ファームウェア

| 対象 | artifact名 | ローカルUF2 |
| --- | --- | --- |
| 左エンコーダー | `MKB_L_MODULE_ENC` | `build/local/MKB_L_MODULE_ENC.uf2` |
| 右トラックボールv4 | `MKB_R_MODULE_TBv4` | `build/local/MKB_R_MODULE_TBv4.uf2` |

左側はsplit central、右側はperipheralである。左エンコーダーだけを調整した場合は、原則として左側だけを書き込む。共有設定や右トラックボール関連を変更した場合は、変更内容に応じて両側を書き込む。

## 重要な原則

- 左右を同時にUSB接続せず、必ず片側ずつ扱う。
- USBケーブルはデータ通信対応品を使う。
- 書き込み中はUSBケーブルを抜かない。
- UF2のファイル名、対象側、ブートローダードライブを照合するまでコピーしない。
- 通常の反復更新では `settings_reset` を使わない。
- リセットボタンの位置が不明な場合は作業を止め、写真または製作者資料で確認する。未確認の `RST` / `GND` 短絡は行わない。

## 1. ビルド

Docker Desktopを起動し、対象をローカルビルドする。

左エンコーダーだけをビルドする場合:

```bash
scripts/build-zmk-local.sh --target MKB_L_MODULE_ENC
```

右トラックボールv4だけをビルドする場合:

```bash
scripts/build-zmk-local.sh --target MKB_R_MODULE_TBv4
```

両方をビルドする場合:

```bash
scripts/build-zmk-local.sh --target both
```

コマンド終了時に、対象UF2のパス、サイズ、SHA-256を確認する。既知正常ファームウェアへ戻せるよう、書き込み前に復旧用UF2のパスとハッシュも記録する。

## 2. 利用者が書き込みreadyにする

次の操作を、今回書き込む側だけに行う。

1. 左右両方の電源スイッチをOFFにする。
2. 左右からUSBケーブルを外す。
3. 今回書き込む側だけを、データ通信対応USB-CケーブルでMacへ接続する。
4. 電源スイッチはOFFのままにする。XIAO nRF52840はUSBから給電される。
5. 対象側のリセットボタンを、約0.5秒以内に素早く2回押す。
6. 数秒待ち、FinderにUSBドライブが現れることを確認する。ドライブ名は `XIAO-SENSE` などの場合がある。
7. ドライブ内に `INFO_UF2.TXT` があることを確認する。
8. UF2を手動コピーせず、エージェントへ「左側ready」または「右側ready」と伝える。

リセットボタンの位置が分からない場合は、USB端子周辺と基板が見える写真を用意して位置確認を依頼する。

## 3. エージェントがdry-runする

エージェントは次を確認する。

- `/Volumes` 以下に `INFO_UF2.TXT` を持つドライブが1つだけ存在する。
- UF2のファイル名が期待するartifact名と一致する。
- UF2のマジック値が正しい。
- UF2のSHA-256、コピー元、コピー先、ブートローダー情報が確認できる。

左エンコーダーの例:

```bash
scripts/flash-uf2-macos.sh \
  --firmware build/local/MKB_L_MODULE_ENC.uf2 \
  --expect MKB_L_MODULE_ENC \
  --dry-run
```

dry-runではファイルをコピーしない。表示された対象とドライブが正しいことを利用者とエージェントの双方で確認する。

## 4. 書き込む

利用者が「書き込んでください」と明示的に承認した後、dry-runから `--dry-run` を外して実行する。

```bash
scripts/flash-uf2-macos.sh \
  --firmware build/local/MKB_L_MODULE_ENC.uf2 \
  --expect MKB_L_MODULE_ENC
```

対話プロンプトへ `FLASH` と入力した場合だけUF2がコピーされる。コピー完了後、UF2ドライブは自動的にアンマウントされ、コントローラーが再起動する。macOSでドライブ取り外しの通知が出た場合も、まずスクリプトの終了状態とコントローラーの再起動を確認する。

もう片側も更新する場合は、完了した側のUSBを外してから「2. 利用者が書き込みreadyにする」へ戻る。

## 5. 書き込み後に確認する

1. UF2ドライブが消え、対象側が再起動したことを確認する。
2. 左側を書き込んだ場合は、左側をUSB接続したままキー入力と対象機能を確認する。
3. USBを外し、左右両方の電源をONにする。
4. 数秒待ち、左右が接続することを確認する。
5. 既存Bluetooth接続でキー入力と対象機能を確認する。
6. 変更箇所に応じた実機確認を行う。左エンコーダーなら、低速1ノッチ、上下方向、連続回転、回転後のキー入力、Bluetoothフリーズの有無を確認する。

右側はperipheralなので、右側だけをUSB接続しても通常のキーボード入力がMacへ出ない場合がある。右側の確認は、左右両方を起動して左側central経由で行う。

通常のUF2更新ではBluetooth設定は維持される。HID記述子を変更しておらず、`settings_reset` も使っていない場合は、最初からmacOS側のペアリングを削除しない。

## `settings_reset` を使う場合

`settings_reset` は通常更新用ではない。Bluetoothプロファイル、左右のsplit bond、その他の永続設定を消去する復旧手順である。

次の場合にのみ、影響と復旧順序を確認して使用を検討する。

- 左右が再接続しない。
- centralまたはperipheralの役割を変更した。
- コントローラーを交換した。
- HID記述子変更後に、通常の再ペアリングだけでは復旧しない。

使用時は原則として両側へ `settings_reset` を書き、その後、左・右それぞれの通常UF2を再度書き込む。保存済みBluetooth接続も消えるため、macOS側でデバイスを削除して再ペアリングする。

## readyにならない場合

1. USBケーブルがデータ通信対応か確認する。
2. USBハブを外し、Mac本体へ直接接続する。
3. USB接続後、リセットボタンを素早く2回押し直す。
4. Finderだけでなく `/Volumes` に新しいドライブがあるか確認する。
5. 左右を同時接続していないことを確認する。
6. リセットボタンの位置が不明なら、それ以上操作せず写真で確認する。

ブートローダードライブが現れない状態では、UF2書き込みを実行しない。

## 参照資料

- [ZMK: Installing ZMK](https://zmk.dev/docs/user-setup)
- [ZMK: Building and Flashing](https://zmk.dev/docs/development/local-toolchain/build-flash)
- [ZMK: Connection Issues](https://zmk.dev/docs/troubleshooting/connection-issues)
- [Seeed Studio: XIAO nRF52840 with Zephyr](https://wiki.seeedstudio.com/XIAO-nRF52840-Zephyr-RTOS/)
