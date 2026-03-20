# collect_demonstration.py: debug and run notes

This note summarizes why `collect_demonstration.py` failed before and what was changed to make it run with keyboard control.

## What failed before

1. Debug run failed early with:

- `AssertionError` at `assert os.path.exists(args.bddl_file)`

Cause: the debug argument for `--bddl-file` used an invalid path with duplicated filename.

2. Terminal run failed later with:

- `ImportError: cannot import name 'SpaceMouse' from robosuite.devices`

Cause: your installed `robosuite` package / device setup did not match this script's default `--device spacemouse` path.

3. Keyboard run then failed with:

- `TypeError: add_keypress_callback() takes 2 positional arguments but 3 were given`

Cause: viewer callback API differs across robosuite versions.
Some versions expect `add_keypress_callback("any", fn)`, others expect `add_keypress_callback(fn)`.

## What was changed

### 1) Keyboard callback compatibility in script

File changed:
- `safelibero/scripts/collect_demonstration.py`

Change summary:
- Added `import inspect`.
- In keyboard initialization, detect callback method signatures using `inspect.signature(...)`.
- Register callbacks with the correct argument form:
  - if method has 2 parameters -> call with `"any", callback`
  - otherwise -> call with only `callback`
- Keep safe fallback on missing viewer callback attributes.

This removes the callback signature mismatch and allows keyboard control to work.

### 2) Use keyboard in launcher/script commands

Files changed:
- `.vscode/launch.json`
- `collect_own_dataset.sh`

Change summary:
- Added `--device keyboard`.
- Corrected `--bddl-file` path in debug config to a real file path.

## Working command

Always activate env first:

```bash
source /home/seaclear/miniconda3/etc/profile.d/conda.sh
conda activate safelibero
```

Then run:

```bash
./collect_own_dataset.sh
```

## Debug from VS Code

Use Run and Debug and choose the config:

- `Collect demonstration`

It now uses:
- `--device keyboard`
- valid `--bddl-file` path

## Notes

- The EGL errors shown during crash cleanup (`Exception ignored in ... EGL...`) are usually secondary cleanup noise after the primary exception.
- If you want SpaceMouse later, we can add a version-compatible import fallback for `SpaceMouse` too.
