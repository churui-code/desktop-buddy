"""Check and encode Godot renders. This script does not edit character art."""
import json
import argparse
from pathlib import Path
import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
parser = argparse.ArgumentParser()
parser.add_argument("--version", choices=["v3"], default="v3")
version = parser.parse_args().version
FRAME_DIR = ROOT / "previews/layered-rendered"
reference = np.array(Image.open(FRAME_DIR / "master-rest.png").convert("RGBA"))
assembled = np.array(Image.open(FRAME_DIR / "assembled-rest.png").convert("RGBA"))
# The body now uses the hanging-source mesh at both endpoints. Compare the
# unchanged master head above its neck, excluding the intentionally new body.
head_rows = int(reference.shape[0] / 2 + (710 - 627) * 0.19)
reference = reference[:head_rows]
assembled = assembled[:head_rows]
# Ignore RGB of fully transparent pixels; compare alpha and visible colors.
visible = (reference[:, :, 3] > 0) | (assembled[:, :, 3] > 0)
diff = np.abs(assembled.astype(int) - reference.astype(int))
report = {
    "source_canvas": [1254, 1254],
    "head_comparison_rows": head_rows,
    "body_comparison": "excluded: body uses the unified mesh",
    "render_size": list(Image.open(FRAME_DIR / "master-rest.png").size),
    "head_alpha_max_difference": int(diff[:, :, 3].max()),
    "head_visible_channel_max_difference": int(diff[visible].max()),
    "head_visible_mean_channel_difference": float(diff[visible].mean()),
    "head_changed_visible_pixels": int(np.any(diff > 0, axis=2)[visible].sum()),
}
output_report = ROOT / f"previews/layered-cat-{version}.qa.json"
output_report.write_text(json.dumps(report, indent=2) + "\n")
print(json.dumps(report, indent=2))
if report["head_alpha_max_difference"] > 1 or report["head_visible_channel_max_difference"] > 2:
    raise SystemExit("Original head differs from the master; inspect transforms and layer masks.")
paths = sorted(FRAME_DIR.glob("[0-9][0-9][0-9].png"))
if len(paths) != 80:
    raise SystemExit("Expected 80 animation renders.")
frames = [Image.open(path).convert("RGBA") for path in paths]
output = ROOT / f"previews/cat-layered-head-pet-{version}.webp"
frames[0].save(output, save_all=True, append_images=frames[1:], duration=42,
               loop=0, lossless=True, method=4)
print(output)
