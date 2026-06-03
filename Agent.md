# Futhesia Moduora (MeKaBu) - AI Agent用開発ガイド

このファイルは、AIエージェントが本リポジトリ（Futhesia Moduora / MeKaBuのZMK設定）を理解し、安全かつ効率的に編集・拡張・メンテナンスを行うためのガイドラインです。

---

## 1. プロジェクト概要

本プロジェクトは、モジュール式の無線分割型キーボード「**Futhesia Moduora（メカブ）**」の ZMK Firmware 設定リポジトリです。

- **MCU（コントローラボード）**: [Seeeduino Xiao BLE](https://zmk.dev/docs/hardware) (`seeeduino_xiao_ble`) を左右に搭載。
- **モジュール構造**: 左右のベースシールドに、トラックボール（TB）、ジョイスティック（JOY）、エンコーダ（ENC）、タッチパッド（TPD）、RZT（ろくじたん・スクロール）などの多様な入力モジュールを着脱・差し替え可能な構造。
- **キーマトリックス配線**: **Charlieplexing** (`zmk,kscan-gpio-charlieplex`) を使用。
- **5方向スイッチ**: 左右のメイン基板にそれぞれ配置されているジョイスティック状のスイッチ。
- **その他**: OLEDディスプレイ (SSD1306, 128x32)、RGB LED。
- **設定ソフトウェア**: [ZMK Studio](https://zmk.dev/docs/features/studio) や [DYA Studio](https://github.com/cormoran/zmk-module-settings-rpc) に対応。

---

## 2. ディレクトリ・ファイル構成

主要なファイルおよびディレクトリの役割は以下の通りです。

```text
./
│  build.yaml ・・・・・・・・・ ビルドするファームウェアの定義（左右の組み合わせなど）
│
├─.github/workflows/
│      build.yml ・・・・・・・・ GitHub ActionsによるUF2ビルドワークフロー
│      draw-keymap.yml ・・・・・ キーマップ画像ファイル自動生成用
│
├─boards/shields/MKB/ ・・・・・ シールド（キーボード基板およびモジュール）の定義
│      Kconfig.defconfig ・・・・ 共通Kconfig定義
│      Kconfig.shield ・・・・・ 各シールド（Baseおよび各モジュール）の定義
│      MKB.dtsi ・・・・・・・・ キーマトリックス（RCマクロ）、レイアウト、エンコーダの基礎定義
│      MKB.zmk.yml
│      MKB_pinctrl_L.dtsi ・・・・ 左手OLED等用ピン配置設定
│      MKB_pinctrl_R.dtsi ・・・・ 右手OLED等用ピン配置設定
│
│      [左手用モジュール定義]
│      MKB_L_Base.conf ・・・・・ 左手共通config
│      MKB_L_Base.overlay ・・・・ kscan、input-listener、OLED等の設定
│      MKB_L_ENC.conf / .overlay  ロータリーエンコーダモジュール
│      MKB_L_JOY.conf / .overlay  アナログスティック＆エンコーダモジュール
│      MKB_L_KEY.conf / .overlay  キーモジュール
│      MKB_L_RZT.conf / .overlay  ろくじたん（スクロール）モジュール
│      MKB_L_TB.conf / .overlay   トラックボールモジュール（PMW3610光学センサ）
│      MKB_L_TPD.conf / .overlay  トラックパッドモジュール
│
│      [右手用モジュール定義]
│      MKB_R_Base.conf / .overlay
│      MKB_R_ENC.conf / .overlay
│      MKB_R_JOY.conf / .overlay
│      MKB_R_KEY.conf / .overlay
│      MKB_R_RZT.conf / .overlay
│      MKB_R_TB.conf / .overlay   トラックボールモジュール（最新版はTBv4）
│      MKB_R_TBv3.conf / .overlay （旧開発版）トラックボールモジュール（通常は使用しない）
│      MKB_R_TPD.conf / .overlay
│
├─config/
│      kle.json ・・・・・・・・・ Keyboard Layout Editor用JSON
│      MKB.json ・・・・・・・・・ Keymap Drawer用JSON
│      MKB.keymap ・・・・・・・・ キーマップ（レイヤ定義、キーアサイン、センサーバインド）
│      west.yml ・・・・・・・・・ 外部モジュール・カスタムドライバ（PMW3610等）の定義
│
├─snippets/Default/
│      Default.overlay ・・・・・ 各モジュールのinput-listenerおよび入力処理（方向反転等）の定義
│      snippet.yml ・・・・・・・ スニペット定義
│
├─firmware/
│  └─main/firmware/ ・・・・・・ ビルド済みのuf2ファイル格納先
│
└─keymap-drawer/
       MKB.svg ・・・・・・・・・ 自動描画されたキーマップ画像
```

---

## 3. モジュール構成とビルドUF2のマッピング

[build.yaml](file:///Users/yuya/workspace/zmk-config-MKB2/build.yaml) に基づき、使用するモジュールの組み合わせに応じて、それぞれ以下のUF2ファイルをビルドし、マイコンに書き込みます。

- **標準構成（左手エンコーダ、右手トラックボール）**:
  - 左手用: `MKB_L_MODULE_ENC.uf2`
  - 右手用: `MKB_R_MODULE_TBv4.uf2`（※ `TBv3` ではない）
- **左手アナログスティック、右手トラックボール構成**:
  - 左手用: `MKB_L_MODULE_JOY.uf2`
  - 右手用: `MKB_R_MODULE_TBv4.uf2`
- **両手トラックボール構成**:
  - 左手用: `MKB_L_MODULE_TB.uf2`
  - 右手用: `MKB_R_MODULE_TBv4.uf2`

---

## 4. 主要な技術仕様と編集時のルール

### A. 物理入力リスナーと入力処理（スニペット）
トラックボールやアナログスティック、トラックパッドからの物理的な入力処理は [snippets/Default/Default.overlay](file:///Users/yuya/workspace/zmk-config-MKB2/snippets/Default/Default.overlay) 内で定義されています。

- **例: トラックパッド (`trackpad_listener`) の上下スクロール方向を反転したい場合**
  `Default.overlay` 内の `trackpad_listener` で `input-processors` の変換処理（`INPUT_TRANSFORM_Y_INVERT` 等）を設定します。
  ```dts
  trackpad_listener: trackpad_listener {
      compatible = "zmk,input-listener";
      status = "okay";
      device = <&trackpad_split>;
      
      input-processors = <&zip_xy_transform (INPUT_TRANSFORM_XY_SWAP)>,
                         <&zip_xy_transform INPUT_TRANSFORM_Y_INVERT>, // Y軸（上下）の反転
                         <&scroll_runtime_input_processor>;

      scroller {
          layers = <5>;
          input-processors = <&zip_xy_transform (INPUT_TRANSFORM_XY_SWAP)>,
                             <&zip_xy_transform INPUT_TRANSFORM_Y_INVERT>,
                             <&zip_xy_to_scroll_mapper>, 
                             <&scroll_runtime_input_processor>;
      };
  };
  ```

### B. 5方向スイッチの対応キー
5方向スイッチは左右それぞれ5つのキーイベントを生成します。[MKB.dtsi](file:///Users/yuya/workspace/zmk-config-MKB2/boards/shields/MKB/MKB.dtsi) のマトリックス変換定義において、以下の位置にマッピングされています。
```dts
// 5方向スイッチ（左手側、右手側）のキー位置
RC( 3, 5)  RC( 2, 5)  RC( 4, 5)  RC( 1, 5)  RC( 0, 5)     RC( 2,11)  RC( 0,11)  RC( 4,11)  RC( 3,11)  RC( 1,11)
```
[MKB.keymap](file:///Users/yuya/workspace/zmk-config-MKB2/config/MKB.keymap) では、この方向キー部分の動作をレイヤごとに任意に変更できます。

### C. 外部モジュールの定義
[west.yml](file:///Users/yuya/workspace/zmk-config-MKB2/config/west.yml) にて `te9no` 氏のフォークを含む各種ドライバや追加機能をロードしています。
モジュールや ZMK のバージョンを変更する場合は、ドライバーやライブラリのAPI変更（例: `zmk,input-listener` の構造）との整合性に配慮してください。
