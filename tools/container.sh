#!/usr/bin/env bash
# Run the whole assignment inside a pinned-toolchain container.
#
#   bash tools/container.sh build              # build the image (once, ~3 min)
#   bash tools/container.sh all                # build tools + verify everything
#   bash tools/container.sh run <command...>   # run anything inside
#   bash tools/container.sh shell              # interactive shell inside
#
# The repository is bind-mounted at /work, so everything the container builds
# -- gem5/, gapbs/, tools/ramulator2/, PartB/cacti/cacti, PartC/nvsim -- lands
# in your working tree and persists. Only the toolchain lives in the image.
#
# Why this exists: Fedora 44 ships GCC 16, CMake 4.3 and Python 3.14, all newer
# than CACTI, NVSim, Ramulator 2.0a and gem5 target. Those are C++ toolchain
# conflicts, not Python ones, so virtualenvs cannot fix them. This pins the
# toolchain instead of fighting it.
set -euo pipefail

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
IMAGE="${IMAGE:-amcas-a1:latest}"

RUNNER=$(command -v podman || command -v docker) || {
    echo "neither podman nor docker found."
    echo "  sudo dnf install podman"
    exit 1
}
echo "using $(basename "$RUNNER"), image $IMAGE, repo $ROOT"

# podman maps the host user into the container by default; docker needs --user.
USERFLAG=()
[ "$(basename "$RUNNER")" = "docker" ] && USERFLAG=(--user "$(id -u):$(id -g)")

in_container () {
    local TTY=()
    [ -t 0 ] && TTY=(-it)
    # Only forward FF/MAXI/etc if the HOST shell actually set them. A
    # hardcoded fallback here would override tools/env.sh's own defaults
    # (baking in a stale value like FF=50000000, which overshoots the bfs
    # kernel) even when the caller asked for nothing. Bare variable
    # expansion into --env "NAME=$val" only happens when $val is non-empty,
    # so env.sh's own defaults apply exactly when nothing was requested.
    ENVFLAGS=()
    for v in FF MAXI TRACE_ACCESSES JOBS PARALLEL NPROC; do
        [ -n "${!v:-}" ] && ENVFLAGS+=(--env "$v=${!v}")
    done
    "$RUNNER" run --rm "${TTY[@]}" "${USERFLAG[@]}" \
        --volume "$ROOT:/work:z" \
        --workdir /work \
        --env "A1_ROOT=/work" \
        --env "PROTOCOL_BUFFERS_PYTHON_IMPLEMENTATION=python" \
        "${ENVFLAGS[@]}" \
        "$IMAGE" "$@"
}

case "${1:-all}" in
    build)
        "$RUNNER" build -t "$IMAGE" -f "$ROOT/tools/Dockerfile" "$ROOT/tools"
        echo "image $IMAGE ready"
        ;;
    gem5)
        in_container bash -c "rm -rf /work/gem5/build && bash tools/build_tools.sh gem5"
        ;;
    verify)
        shift
        in_container bash verify_all.sh "$@"
        ;;
    all)
        "$RUNNER" image exists "$IMAGE" 2>/dev/null || \
        "$RUNNER" image inspect "$IMAGE" >/dev/null 2>&1 || {
            echo "image not found; building it first"
            "$RUNNER" build -t "$IMAGE" -f "$ROOT/tools/Dockerfile" "$ROOT/tools"
        }
        # `deps` is skipped: the image already provides them.
        in_container bash tools/build_tools.sh cacti nvsim ramulator gem5 gapbs
        in_container bash verify_all.sh
        ;;
    run)
        shift
        in_container "$@"
        ;;
    shell)
        in_container bash
        ;;
    *)
        sed -n '2,12p' "${BASH_SOURCE[0]}"
        exit 1
        ;;
esac
