"""Check and encode Godot renders. This script does not edit character art."""
import json
from pathlib import Path
import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
FRAME_DIR = ROOT / "previews/layered-rendered"
reference = np.array(Image.open(FRAME_DIR / "master-rest.png").convert("RGBA"))
assembled = np.array(Image.open(FRAME_DIR / "assembled-rest.png").convert("RGBA"))
# Ignore RGB of fully transparent pixels; compare alpha and visible colors.
visible = (reference[:, :, 3] > 0) | (assembled[:, :, 3] > 0)
diff = np.abs(assembled.astype(int) - reference.astype(int))
report = {
    "source_canvas": [1254, 1254],
    "render_size": list(Image.open(FRAME_DIR / "master-rest.png").size),
    "rest_alpha_max_difference": int(diff[:, :, 3].max()),
    "rest_visible_channel_max_difference": int(diff[visible].max()),
    "rest_visible_mean_channel_difference": float(diff[visible].mean()),
    "rest_changed_visible_pixels": int(np.any(diff > 0, axis=2)[visible].sum()),
}
output_report = ROOT / "previews/layered-cat-v1.qa.json"
output_report.write_text(json.dumps(report, indent=2) + "\n")
print(json.dumps(report, indent=2))
if report["rest_alpha_max_difference"] > 1 or report["rest_visible_channel_max_difference"] > 2:
    raise SystemExit("Static reconstruction differs from the master; inspect the layer masks.")
paths = sorted(FRAME_DIR.glob("[0-9][0-9][0-9].png"))
if len(paths) != 80:
    raise SystemExit("Expected 80 animation renders.")
frames = [Image.open(path).convert("RGBA") for path in paths]
output = ROOT / "previews/cat-layered-head-pet-v1.webp"
frames[0].save(output, save_all=True, append_images=frames[1:], duration=42,
               loop=0, lossless=True, method=4)
print(output)
