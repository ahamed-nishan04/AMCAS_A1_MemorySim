#!/usr/bin/env bash
# Run the container-built gem5.opt inside its container.
#
# The image's binary links libpython3.12, which Fedora 44 does not ship, so
# gem5 is both built and run in the container.  :z is required under SELinux.
#
# The repository root is mounted at /work, so paths passed to gem5 must be the
# container's view: /work/gem5/..., /work/gapbs/..., /work/PartE/...
ROOT=$(cd "$(dirname "$0")" && pwd)
RUNNER=$(command -v docker || command -v podman) || {
    echo "neither docker nor podman found: sudo dnf install podman"; exit 1; }
exec "$RUNNER" run -u "$(id -u):$(id -g)" --volume "$ROOT:/work:z" -w /work --rm \
  ghcr.io/gem5/ubuntu-24.04_all-dependencies:latest \
  /work/gem5/build/X86/gem5.opt "$@"
