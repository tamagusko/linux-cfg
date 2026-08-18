#!/usr/bin/env bash
#
# Scaffold a uv-managed ML project with the correct GPU wheels.
#
#   ./scripts/new-ml-project.sh myproject           # PyTorch (default)
#   ./scripts/new-ml-project.sh myproject tensorflow
#
# Why this exists: the framework is chosen per project, not per machine.
# PyTorch is the default here; TensorFlow stays available for the embedded and
# TFLite work without either being installed system-wide, where they would
# fight over CUDA versions.

set -euo pipefail
IFS=$'\n\t'

NAME="${1:?usage: new-ml-project.sh NAME [pytorch|tensorflow]}"
FRAMEWORK="${2:-pytorch}"

command -v uv >/dev/null 2>&1 || { echo "uv not installed — run stages/40-dev.sh" >&2; exit 1; }

[[ -e "$NAME" ]] && { echo "refusing to overwrite existing path: $NAME" >&2; exit 1; }

uv init "$NAME"
cd "$NAME"

# Pin an interpreter so a system Python bump cannot break this project.
uv python pin 3.13

case "$FRAMEWORK" in
    pytorch)
        # --torch-backend=auto detects the GPU and selects the matching CUDA
        # wheel index. Choosing that index by hand is how people end up
        # silently training on CPU.
        uv add torch torchvision --torch-backend=auto
        uv add ultralytics opencv-python numpy pandas matplotlib
        ;;
    tensorflow)
        # TensorFlow ships CUDA support in the [and-cuda] extra.
        uv add 'tensorflow[and-cuda]'
        uv add numpy pandas matplotlib
        ;;
    *)
        echo "unknown framework: $FRAMEWORK (expected pytorch or tensorflow)" >&2
        exit 1
        ;;
esac

cat > check_gpu.py <<'PY'
"""Confirm the GPU is actually visible to the framework."""

try:
    import torch

    print(f"torch {torch.__version__}")
    print(f"cuda available: {torch.cuda.is_available()}")
    if torch.cuda.is_available():
        print(f"device: {torch.cuda.get_device_name(0)}")
except ImportError:
    import tensorflow as tf

    print(f"tensorflow {tf.__version__}")
    print(f"gpus: {tf.config.list_physical_devices('GPU')}")
PY

echo
echo "Created $NAME ($FRAMEWORK). Verify the GPU is visible:"
echo "  cd $NAME && uv run check_gpu.py"
