"""Check and encode Godot renders. This script does not edit character art."""
import json
import argparse
from pathlib import Path
import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
parser = argparse.ArgumentParser()
parser.add_argument("--version", choices=["v4", "v5"], default="v5")
version = parser.parse_args().version
FRAME_DIR = ROOT / "previews/layered-rendered"
reference = np.array(Image.open(FRAME_DIR / "master-rest.png").convert("RGBA"))
assembled = np.array(Image.open(FRAME_DIR / "assembled-rest.png").convert("RGBA"))
# Compare the entire cat, including all four paws and the original seated tail.
# Ignore RGB of fully transparent pixels; compare alpha and visible colors.
visible = (reference[:, :, 3] > 0) | (assembled[:, :, 3] > 0)
diff = np.abs(assembled.astype(int) - reference.astype(int))
idle_frames = []
idle_max_difference = 0
for phase in range(16):
    idle = Image.open(FRAME_DIR / f"idle-{phase:02d}.png").convert("RGBA")
    actual = np.array(idle).astype(int)
    expected = np.array(Image.open(FRAME_DIR / f"idle-reference-{phase:02d}.png").convert("RGBA")).astype(int)
    covered = (actual[:, :, 3] > 0) | (expected[:, :, 3] > 0)
    idle_max_difference = max(idle_max_difference, int(np.abs(actual - expected)[covered].max()))
    idle_frames.append(idle)
report = {
    "source_canvas": [1254, 1254],
    "body_comparison": "full original seated atlas, including limbs and tail",
    "render_size": list(Image.open(FRAME_DIR / "master-rest.png").size),
    "rest_alpha_max_difference": int(diff[:, :, 3].max()),
    "rest_visible_channel_max_difference": int(diff[visible].max()),
    "rest_visible_mean_channel_difference": float(diff[visible].mean()),
    "rest_changed_visible_pixels": int(np.any(diff > 0, axis=2)[visible].sum()),
    "idle_phases_compared": len(idle_frames),
    "idle_cycle_max_visible_channel_difference": idle_max_difference,
}
output_report = ROOT / f"previews/layered-cat-{version}.qa.json"
output_report.write_text(json.dumps(report, indent=2) + "\n")
print(json.dumps(report, indent=2))
if report["rest_alpha_max_difference"] > 2 or report["rest_visible_channel_max_difference"] > 3 or idle_max_difference > 3:
    raise SystemExit("Seated body or tail differs from the original master; inspect mesh and layer masks.")
paths = sorted(FRAME_DIR.glob("[0-9][0-9][0-9].png"))
if len(paths) != 80:
    raise SystemExit("Expected 80 animation renders.")
frames = [Image.open(path).convert("RGBA") for path in paths]
output = ROOT / f"previews/cat-layered-head-pet-{version}.webp"
frames[0].save(output, save_all=True, append_images=frames[1:], duration=42,
               loop=0, lossless=True, method=4)
idle_frames[0].save(ROOT / f"previews/cat-idle-{version}.webp", save_all=True,
                    append_images=idle_frames[1:], duration=200, loop=0, lossless=True, method=4)
print(output)
