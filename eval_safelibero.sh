# 1. Clear any conflicting paths
export PYTHONPATH=$PYTHONPATH:$PWD/safelibero

# # 2. Add the specific directory where you found libEGL_nvidia.so.0
# # Putting it first ensures it overrides generic Mesa drivers
# export LD_LIBRARY_PATH=/usr/lib/x86_64-linux-gnu:$LD_LIBRARY_PATH
# export LD_LIBRARY_PATH=/usr/local/cuda/lib64:$LD_LIBRARY_PATH


# # 3. Explicitly point to the NVIDIA vendor file you found
# export __EGL_VENDOR_LIBRARY_FILENAMES=/usr/share/glvnd/egl_vendor.d/10_nvidia.json

# # 4. Set MuJoCo to EGL mode (GPU rendering)
# MUJOCO_GL=egl
# # export MUJOCO_EGL_DEVICE_ID=0

# export LD_PRELOAD=/usr/lib/x86_64-linux-gnu/libEGL_nvidia.so.0
# export LD_PRELOAD=/usr/lib/x86_64-linux-gnu/libGLEW.so:/usr/lib/x86_64-linux-gnu/libEGL.so.1



##########################################################

# 2. Use GLX backend (EGL extension is unavailable on this server)
unset LD_PRELOAD
export MUJOCO_GL=egl
export LD_LIBRARY_PATH=/usr/lib/x86_64-linux-gnu:$LD_LIBRARY_PATH
export __EGL_VENDOR_LIBRARY_FILENAMES=/usr/share/glvnd/egl_vendor.d/10_nvidia.json

# 3. If running headless, start a virtual display via conda Xvfb (no sudo needed)
if [ -z "${DISPLAY}" ]; then
    XVFB_BIN="${CONDA_PREFIX}/bin/Xvfb"
    if [ -x "${XVFB_BIN}" ]; then
        "${XVFB_BIN}" :99 -screen 0 1400x900x24 >/tmp/xvfb_safelibero.log 2>&1 &
        XVFB_PID=$!
        trap 'kill ${XVFB_PID} >/dev/null 2>&1 || true' EXIT
        export DISPLAY=:99
    else
        echo "[error] DISPLAY is empty and ${XVFB_BIN} not found."
        echo "[hint] Activate safelibero env and install xorg-xserver-xvfb in that env."
        exit 1
    fi
fi

python main_demo_dummy.py \
    --task-suite-name safelibero_goal \
    --safety-level II \
    --task-index 0 \
    --episode-index 0 1 2 3 4 5 \
    --video-out-path eval_logs/safelibero_goal/videos