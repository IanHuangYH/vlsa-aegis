#!/usr/bin/env bash
set -euo pipefail

# Run AEGIS evaluation in headless environments (no physical display).
# - Activates main/.venv
# - Sets PYTHONPATH and MUJOCO_GL=egl (default)
# - Sanitizes LD_LIBRARY_PATH to avoid MATLAB libEGL conflicts
# - Optionally starts Xvfb when MUJOCO_GL=glx and DISPLAY is missing
# - Runs main/main_aegis.py
#
# Usage:
#   bash run_aegis_headless.sh
#   bash run_aegis_headless.sh --task-suite-name safelibero_spatial --safety-level I --task-index 0 --episode-index 0 1 2 3 4 5 --video-out-path data/libero/videos

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "${ROOT_DIR}"

if [[ ! -f "main/.venv/bin/activate" ]]; then
  echo "[error] main/.venv not found. Please finish AEGIS environment setup first."
  exit 1
fi

# shellcheck disable=SC1091
source main/.venv/bin/activate

export PYTHONPATH="${PYTHONPATH:-}:$PWD/safelibero"

# Remove MATLAB paths from LD_LIBRARY_PATH, which can shadow system EGL and
# cause: ImportError: eglQueryDevicesEXT is not available.
sanitize_ld_library_path() {
  local old_ld new_ld part
  old_ld="${LD_LIBRARY_PATH:-}"
  new_ld=""

  IFS=':' read -r -a _ld_parts <<< "$old_ld"
  for part in "${_ld_parts[@]}"; do
    [[ -z "$part" ]] && continue
    case "$part" in
      *MATLAB*|*Matlab*|*matlab*)
        ;;
      *)
        if [[ -z "$new_ld" ]]; then
          new_ld="$part"
        else
          new_ld="$new_ld:$part"
        fi
        ;;
    esac
  done

  # Ensure system GL/EGL paths are first.
  export LD_LIBRARY_PATH="/usr/lib/x86_64-linux-gnu:/usr/local/cuda/lib64${new_ld:+:$new_ld}"
}

sanitize_ld_library_path

# Default to EGL backend to avoid Xvfb/GLX issues on many headless servers.
export MUJOCO_GL="${MUJOCO_GL:-egl}"
if [[ "${MUJOCO_GL}" == "egl" ]]; then
  export PYOPENGL_PLATFORM="egl"
fi

XVFB_PID=""

find_free_display() {
  local d
  for d in $(seq 99 130); do
    if [[ ! -e "/tmp/.X${d}-lock" && ! -S "/tmp/.X11-unix/X${d}" ]]; then
      echo ":${d}"
      return 0
    fi
  done
  return 1
}

if [[ "${MUJOCO_GL}" == "glx" && -z "${DISPLAY:-}" ]]; then
  XVFB_BIN="$(command -v Xvfb || true)"
  if [[ -z "${XVFB_BIN}" && -x "$HOME/.conda/envs/safelibero/bin/Xvfb" ]]; then
    XVFB_BIN="$HOME/.conda/envs/safelibero/bin/Xvfb"
  fi

  if [[ -z "${XVFB_BIN}" ]]; then
    echo "[error] Xvfb not found. Install it first."
    echo "[hint] Ubuntu: sudo apt-get install -y xvfb"
    echo "[hint] Conda : conda install -c conda-forge xorg-xvfb"
    exit 1
  fi

  DISPLAY_CANDIDATE="$(find_free_display || true)"
  if [[ -z "${DISPLAY_CANDIDATE}" ]]; then
    echo "[error] No free X display slot found in :99-:130"
    exit 1
  fi

  "${XVFB_BIN}" "${DISPLAY_CANDIDATE}" -screen 0 1400x900x24 >/tmp/xvfb_aegis.log 2>&1 &
  XVFB_PID=$!
  sleep 1

  if ! kill -0 "${XVFB_PID}" 2>/dev/null; then
    echo "[error] Failed to start Xvfb on ${DISPLAY_CANDIDATE}."
    echo "[hint] Check log: /tmp/xvfb_aegis.log"
    exit 1
  fi

  export DISPLAY="${DISPLAY_CANDIDATE}"
  echo "[info] Started Xvfb on ${DISPLAY} (pid=${XVFB_PID})"
fi

cleanup() {
  if [[ -n "${XVFB_PID}" ]]; then
    kill "${XVFB_PID}" >/dev/null 2>&1 || true
  fi
}
trap cleanup EXIT

if [[ $# -eq 0 ]]; then
  set -- \
    --task-suite-name safelibero_goal \
    --safety-level II \
    --task-index 0 \
    --episode-index 0 1 2 3 4 5 \
    --video-out-path eval_logs/safelibero_goal/videos
fi

echo "[info] MUJOCO_GL=${MUJOCO_GL}"
echo "[info] DISPLAY=${DISPLAY:-<empty>}"
echo "[info] Running: python main/main_aegis.py $*"
python main/main_aegis.py "$@"
