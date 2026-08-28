#!/usr/bin/env bash

set -euo pipefail

usage() {
    cat <<'EOF'
Usage:
  scripts/build-zmk-local.sh [options]

Options:
  --target NAME   MKB_L_MODULE_ENC, MKB_R_MODULE_TBv4, or both
                  (default: MKB_L_MODULE_ENC)
  --pristine      Recreate the selected target's build directory
  --update        Force west update even when config/west.yml is unchanged
  -h, --help      Show this help

Output:
  build/local/<artifact>.uf2
EOF
}

die() {
    printf 'Error: %s\n' "$*" >&2
    exit 1
}

target="MKB_L_MODULE_ENC"
pristine=false
force_update=false

while [[ $# -gt 0 ]]; do
    case "$1" in
        --target)
            [[ $# -ge 2 ]] || die "--target requires a value"
            target="$2"
            shift 2
            ;;
        --pristine)
            pristine=true
            shift
            ;;
        --update)
            force_update=true
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

case "$target" in
    MKB_L_MODULE_ENC|MKB_R_MODULE_TBv4|both) ;;
    *) die "unsupported target: $target" ;;
esac

command -v docker >/dev/null 2>&1 || die "docker is not installed"
docker info >/dev/null 2>&1 || die "Docker Desktop is not running or is not accessible"

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
repo_root="$(cd "$script_dir/.." && pwd -P)"
image="${ZMK_BUILD_IMAGE:-zmkfirmware/zmk-build-arm:stable}"
workspace_volume="${ZMK_WORKSPACE_VOLUME:-zmk-config-mkb2-workspace}"
manifest_sha="$(shasum -a 256 "$repo_root/config/west.yml" | awk '{print $1}')"

docker volume create "$workspace_volume" >/dev/null

printf 'Local ZMK build\n'
printf '  Target    : %s\n' "$target"
printf '  Image     : %s\n' "$image"
printf '  Workspace : %s\n' "$workspace_volume"
printf '  Pristine  : %s\n' "$pristine"
printf '  Update    : %s\n' "$force_update"

docker run --rm \
    --volume "$workspace_volume:/workspace" \
    --volume "$repo_root:/repo" \
    --env "BUILD_TARGET=$target" \
    --env "PRISTINE_BUILD=$pristine" \
    --env "FORCE_WEST_UPDATE=$force_update" \
    --env "MANIFEST_SHA=$manifest_sha" \
    --env "CCACHE_DIR=/workspace/.ccache" \
    --env "CCACHE_MAXSIZE=2G" \
    --env "CCACHE_COMPILERCHECK=content" \
    --env "CCACHE_IGNOREOPTIONS=--specs=picolibc.specs" \
    "$image" \
    bash /repo/scripts/build-zmk-container.sh
