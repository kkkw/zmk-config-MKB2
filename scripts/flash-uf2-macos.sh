#!/usr/bin/env bash

set -euo pipefail

usage() {
    cat <<'EOF'
Usage:
  scripts/flash-uf2-macos.sh --firmware PATH --expect ARTIFACT [options]

Required:
  --firmware PATH   UF2 file to flash
  --expect NAME     Expected artifact name without .uf2

Options:
  --volume PATH     UF2 bootloader volume (auto-detected when omitted)
  --yes             Skip the interactive FLASH confirmation
  --dry-run         Validate and display the operation without copying
  -h, --help        Show this help

Example:
  scripts/flash-uf2-macos.sh \
    --firmware firmware/zmk-config-MKB2/main/MKB_L_MODULE_ENC.uf2 \
    --expect MKB_L_MODULE_ENC
EOF
}

die() {
    printf 'Error: %s\n' "$*" >&2
    exit 1
}

firmware=""
expected_artifact=""
volume=""
assume_yes=false
dry_run=false
volume_root="${UF2_VOLUME_ROOT:-/Volumes}"

while [[ $# -gt 0 ]]; do
    case "$1" in
        --firmware)
            [[ $# -ge 2 ]] || die "--firmware requires a path"
            firmware="$2"
            shift 2
            ;;
        --expect)
            [[ $# -ge 2 ]] || die "--expect requires an artifact name"
            expected_artifact="$2"
            shift 2
            ;;
        --volume)
            [[ $# -ge 2 ]] || die "--volume requires a path"
            volume="$2"
            shift 2
            ;;
        --yes)
            assume_yes=true
            shift
            ;;
        --dry-run)
            dry_run=true
            shift
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            die "unknown argument: $1"
            ;;
    esac
done

[[ -n "$firmware" ]] || die "--firmware is required"
[[ -n "$expected_artifact" ]] || die "--expect is required"
[[ -f "$firmware" ]] || die "firmware not found: $firmware"
[[ -s "$firmware" ]] || die "firmware is empty: $firmware"
[[ "$firmware" == *.uf2 ]] || die "firmware must have a .uf2 extension"

firmware_name="$(basename "$firmware")"
expected_name="${expected_artifact}.uf2"
[[ "$firmware_name" == "$expected_name" ]] ||
    die "firmware name '$firmware_name' does not match expected '$expected_name'"

header="$(od -An -tx1 -N8 "$firmware" | tr -d '[:space:]')"
footer="$(dd if="$firmware" bs=1 skip=508 count=4 2>/dev/null | od -An -tx1 | tr -d '[:space:]')"
[[ "$header" == "5546320a57515d9e" && "$footer" == "306fb10a" ]] ||
    die "firmware does not have valid UF2 block magic"

[[ -d "$volume_root" ]] || die "volume root not found: $volume_root"
volume_root="$(cd "$volume_root" && pwd -P)"

find_info_file() {
    find "$1" -maxdepth 1 -type f -iname 'INFO_UF2.TXT' -print -quit 2>/dev/null
}

if [[ -z "$volume" ]]; then
    candidates=()
    for candidate in "$volume_root"/*; do
        [[ -d "$candidate" ]] || continue
        if [[ -n "$(find_info_file "$candidate")" ]]; then
            candidates+=("$candidate")
        fi
    done

    case "${#candidates[@]}" in
        0)
            die "no UF2 bootloader volume found under $volume_root; connect the target and double-press reset"
            ;;
        1)
            volume="${candidates[0]}"
            ;;
        *)
            printf 'Multiple UF2 bootloader volumes found:\n' >&2
            printf '  %s\n' "${candidates[@]}" >&2
            die "specify one with --volume"
            ;;
    esac
fi

[[ -d "$volume" ]] || die "volume not found: $volume"
volume="$(cd "$volume" && pwd -P)"
case "$volume/" in
    "$volume_root"/*/) ;;
    *) die "volume must be directly under $volume_root: $volume" ;;
esac

info_file="$(find_info_file "$volume")"
[[ -n "$info_file" ]] || die "INFO_UF2.TXT not found on volume: $volume"

checksum="$(shasum -a 256 "$firmware" | awk '{print $1}')"
destination="$volume/$firmware_name"

printf '%s\n' "UF2 flash operation"
printf '  Firmware : %s\n' "$firmware"
printf '  Artifact : %s\n' "$expected_artifact"
printf '  SHA-256  : %s\n' "$checksum"
printf '  Volume   : %s\n' "$volume"
printf '  UF2 info : %s\n' "$(head -n 1 "$info_file" | tr -d '\r')"
printf '  Copy to  : %s\n' "$destination"

if [[ "$dry_run" == true ]]; then
    printf '%s\n' "Dry run complete; nothing was copied."
    exit 0
fi

if [[ "$assume_yes" != true ]]; then
    printf '%s' "Type FLASH to write this firmware: "
    read -r confirmation
    [[ "$confirmation" == "FLASH" ]] || die "flash cancelled"
fi

cp "$firmware" "$destination"

printf '%s\n' "UF2 copy completed. The controller may unmount and restart automatically."
