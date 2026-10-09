"""Validate and encode actual Godot renders; does not edit sprite artwork."""
import json
from pathlib import Path

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
FRAME_DIR = ROOT / "previews/drag-rendered"
reference = np.array(Image.open(FRAME_DIR / "master-rest.png").convert("RGBA"))
assembled = np.array(Image.open(FRAME_DIR / "assembled-rest.png").convert("RGBA"))
visible = (reference[:, :, 3] > 0) | (assembled[:, :, 3] > 0)
diff = np.abs(reference.astype(np.int16) - assembled.astype(np.int16))
paths = sorted(FRAME_DIR.glob("[0-9][0-9][0-9].png"))
if len(paths) != 144:
    raise SystemExit("Expected 144 drag animation frames.")
frames = [Image.open(path).convert("RGBA") for path in paths]
edge_pixels = sum(
    int(np.count_nonzero(np.concatenate((a[0], a[-1], a[:, 0], a[:, -1]))))
    for a in (np.array(frame)[:, :, 3] >= 3 for frame in frames)
)
outside_native_window = sum(
    int(np.count_nonzero(a[:32])) + int(np.count_nonzero(a[-32:]))
    + int(np.count_nonzero(a[32:-32, :32])) + int(np.count_nonzero(a[32:-32, -32:]))
    for a in (np.array(frame)[:, :, 3] >= 3 for frame in frames)
)
report = {
    "source_canvas": [1254, 1254],
    "render_size": list(frames[0].size),
    "part_count": 7,
    "rest_alpha_max_difference": int(diff[:, :, 3].max()),
    "rest_visible_channel_max_difference": int(diff[visible].max()),
    "rest_changed_visible_pixels": int(np.any(diff > 0, axis=2)[visible].sum()),
    "animation_frame_count": len(frames),
    "opaque_viewport_edge_pixels": edge_pixels,
    "opaque_pixels_outside_native_256_window": outside_native_window,
    "native_window_alpha_threshold": 3,
}
(ROOT / "previews/drag-cat-v2.qa.json").write_text(json.dumps(report, indent=2) + "\n")
print(json.dumps(report, indent=2))
if report["rest_visible_channel_max_difference"] > 2 or edge_pixels or outside_native_window:
    raise SystemExit("Split pose differs from its master or swing clips the viewport.")
output = ROOT / "previews/cat-drag-swing-v2.webp"
frames[0].save(output, save_all=True, append_images=frames[1:], duration=42,
               loop=0, lossless=True, method=4)
print(output)
