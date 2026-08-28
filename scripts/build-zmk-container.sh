#!/usr/bin/env bash

set -euo pipefail

workspace=/workspace
repo=/repo
manifest_marker="$workspace/.manifest-sha"

cd "$workspace"

copy_config() {
    rm -rf "$workspace/config"
    mkdir -p "$workspace/config"
    cp -a "$repo/config/." "$workspace/config/"
}

prepare_workspace() {
    copy_config

    if [[ ! -d "$workspace/.west" ]]; then
        (cd "$workspace" && west init -l config)
    fi

    current_manifest_sha=""
    if [[ -f "$manifest_marker" ]]; then
        current_manifest_sha="$(cat "$manifest_marker")"
    fi

    if [[ "$FORCE_WEST_UPDATE" == true || "$current_manifest_sha" != "$MANIFEST_SHA" ]]; then
        printf '%s\n' "Updating west dependencies..."
        west update --fetch-opt=--filter=tree:0 -o=--depth=1
        printf '%s\n' "$MANIFEST_SHA" > "$manifest_marker"
    else
        printf '%s\n' "west dependencies are current; skipping update."
    fi

    west zephyr-export

    mkdir -p "$workspace/.ccache" "$workspace/build" "$repo/build/local"
}

build_target() {
    artifact="$1"
    shield="$2"
    snippet="$3"
    build_dir="$workspace/build/$artifact"
    output="$repo/build/local/$artifact.uf2"

    printf '\nBuilding %s...\n' "$artifact"

    if [[ "$PRISTINE_BUILD" == true ]]; then
        rm -rf "$build_dir"
    fi

    if [[ -f "$build_dir/build.ninja" ]]; then
        west build -d "$build_dir"
    else
        west build \
            -s "$workspace/zmk/app" \
            -d "$build_dir" \
            -b seeeduino_xiao_ble \
            -S "$snippet" \
            -- \
            -DZMK_CONFIG="$workspace/config" \
            -DSHIELD="$shield" \
            -DZMK_EXTRA_MODULES="$repo" \
            -DCMAKE_C_COMPILER_LAUNCHER=ccache \
            -DCMAKE_CXX_COMPILER_LAUNCHER=ccache
    fi

    [[ -s "$build_dir/zephyr/zmk.uf2" ]] || {
        printf 'Error: UF2 output not found for %s\n' "$artifact" >&2
        exit 1
    }

    cp "$build_dir/zephyr/zmk.uf2" "$output.tmp"
    mv "$output.tmp" "$output"
    shasum -a 256 "$output"
}

prepare_workspace

case "$BUILD_TARGET" in
    MKB_L_MODULE_ENC)
        build_target \
            MKB_L_MODULE_ENC \
            "MKB_L_Base MKB_L_ENC rgbled_adapter nice_oled" \
            "Default zmk-usb-logging studio-rpc-usb-uart"
        ;;
    MKB_R_MODULE_TBv4)
        build_target \
            MKB_R_MODULE_TBv4 \
            "MKB_R_Base MKB_R_TB rgbled_adapter nice_oled" \
            "zmk-usb-logging studio-rpc-usb-uart"
        ;;
    both)
        build_target \
            MKB_L_MODULE_ENC \
            "MKB_L_Base MKB_L_ENC rgbled_adapter nice_oled" \
            "Default zmk-usb-logging studio-rpc-usb-uart"
        build_target \
            MKB_R_MODULE_TBv4 \
            "MKB_R_Base MKB_R_TB rgbled_adapter nice_oled" \
            "zmk-usb-logging studio-rpc-usb-uart"
        ;;
    *)
        printf 'Error: unsupported target: %s\n' "$BUILD_TARGET" >&2
        exit 1
        ;;
esac

printf '\nccache statistics:\n'
ccache --show-stats
printf '\nFirmware output directory: %s\n' "$repo/build/local"
