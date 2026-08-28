# スクロールと安定性の初期調査

調査日: 2026-08-28

## 目的

- Bluetooth 接続のチャタリング、フリーズ、起動不能を避ける。
- 左手側 EC11 エンコーダーの上下スクロールを確実かつ滑らかにする。
- 複数要因を同時に変えず、実機で原因を切り分けられる変更順序を定める。

## 確認した構成

- 左手側は split central で、左 ENC モジュールが EC11 エンコーダーを定義している。
- `config/MKB.keymap` は `zmk,behavior-sensor-rotate` から `&msc SCRL_UP` / `SCRL_DOWN` を呼び出す。
- `boards/shields/MKB/MKB_L_ENC.overlay` は `steps = <24>`、`triggers-per-rotation = <10>` を設定している。
- `config/west.yml` は `te9no/zmk` のコミット `2ae914a28d179fffb8fdd72080e44ef719f49973` を固定している。

## 主な判断

- 現在の `tap-ms = <100>` と既定スクロール速度10は、16ms周期の整数化により、解放前の累計が通常0.96に留まる。端数が解放時に破棄される実装では、無反応または不安定な反応の原因になり得る。
- 長い `tap-ms` は連続回転時に behavior queue の解放イベントを遅らせる。まず HID 記述子を変えず、短い `tap-ms` と明示的な速度で1ノッチ1イベントを安定させる。
- `CONFIG_ZMK_POINTING_SMOOTH_SCROLLING` は固定中の ZMK fork に存在する。ただし HID 記述子を変えるため、通常解像度の動作を確立した後に別変更として試験し、設定リセットと再ペアリングを含める。
- レポート周期の短縮は電力消費や BLE 遅延へ影響し得るため、既定16msは実機検証で必要性が示されるまで変更しない。
- `zmk-input-processor-scroll-inertia` は連続するポインティング入力向けで、EC11 の sensor-rotate 経路へそのまま適用するものではない。
- `zmk-config-high-resolution-scroll-wheel` は AS5600 磁気角度センサーの実証構成であり、EC11 設定として直接流用できない。
- ZMK revision、split/BLE stack、エンコーダー設定を同時に変更しない。

## 参照資料

### 公式 ZMK

- [Sensor Rotation Behaviors](https://zmk.dev/docs/keymaps/behaviors/sensor-rotate)
- [Behavior Configuration](https://zmk.dev/docs/config/behaviors)

### 実装例・技術解説

- [zmk-input-processor-scroll-inertia](https://github.com/mjmjm0101/zmk-input-processor-scroll-inertia)
- [zmk-config-high-resolution-scroll-wheel](https://github.com/adolto/zmk-config-high-resolution-scroll-wheel)
- [ZMK Input Processor チートシート](https://zenn.dev/kot149/articles/zmk-input-processor-cheat-sheet)
- [ZMK スクロール関連の解説](https://zenn.dev/hrksg777/articles/70b59dd39ab807?locale=en)

### MeKaBu とモジュール構成

- [MeKaBu BOOTH](https://mekabukb.booth.pm/)
- [MeKaBu Keyboard Review](https://green-keys.info/mekabu-keyboard-review/)
- [Modulable Keyboard Developer](https://modulable-keyboard-developer.github.io/)
- [MeKaBu モジュール交換式狭ピッチ無線キーボード](https://hebino-tawagoto.com/%E3%80%90mekabu%E3%80%91%E3%83%A2%E3%82%B8%E3%83%A5%E3%83%BC%E3%83%AB%E4%BA%A4%E6%8F%9B%E5%BC%8F%E7%8B%AD%E3%83%94%E3%83%83%E3%83%81%E7%84%A1%E7%B7%9A%E3%82%AD%E3%83%BC%E3%83%9C%E3%83%BC%E3%83%89/)
- [RaZiLy: MeKaBu 関連記事 1](https://note.com/razily/n/nea1575614710)
- [RaZiLy: MeKaBu 関連記事 2](https://note.com/razily/n/na8a57fd5f764)
- [nykx: MeKaBu 関連記事](https://note.com/nykx/n/n0d5ab941d519)
- [nine_00909: MeKaBu 関連記事](https://note.com/nine_00909/n/nc14a9a1e4431)
- [jeisnow_0702: MeKaBu 関連記事](https://note.com/jeisnow_0702/n/n61dae526a57f)

## 次の検証順序

1. 通常解像度のまま、1ノッチで確実に1スクロールイベントが出る速度と短い `tap-ms` を設定する。
2. ビルド後、低速1ノッチ、連続回転、回転方向、Bluetooth 接続中の入力遅延を実機確認する。
3. 通常解像度の基準を保存してから、高解像度スクロールを独立した変更として試す。
4. 高解像度試験では設定リセット、ホスト側ペアリング削除、再ペアリングを行い、スクロール量と BLE 安定性を比較する。

実機で確認できていない項目は、コード確認だけで解決済みとしない。
