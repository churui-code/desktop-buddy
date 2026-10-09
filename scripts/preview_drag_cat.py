"""Validate and encode actual Godot renders; does not edit sprite artwork."""
import json
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[1]
FRAME_DIR = ROOT / "previews/drag-rendered"
paths = sorted(FRAME_DIR.glob("[0-9][0-9][0-9].png"))
if len(paths) != 144:
    raise SystemExit("Expected 144 drag animation frames.")
frames = [Image.open(path).convert("RGBA") for path in paths]
samples = json.loads((FRAME_DIR / "pose-samples.json").read_text())
if len(samples) != len(frames):
    raise SystemExit("Missing runtime pose samples.")
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
    "body_geometry": "one connected mesh interpolating seated and hanging endpoints",
    "minimum_body_opacity": min(s["body_alpha"] for s in samples),
    "minimum_head_opacity": min(s["head_alpha"] for s in samples),
    "original_head_texture_retained": all(s["same_head_texture"] for s in samples),
    "minimum_posture": min(s["posture"] for s in samples),
    "maximum_posture": max(s["posture"] for s in samples),
    "animation_frame_count": len(frames),
    "opaque_viewport_edge_pixels": edge_pixels,
    "opaque_pixels_outside_native_256_window": outside_native_window,
    "native_window_alpha_threshold": 3,
}
(ROOT / "previews/drag-cat-v3.qa.json").write_text(json.dumps(report, indent=2) + "\n")
print(json.dumps(report, indent=2))
if (report["minimum_body_opacity"] != 1 or report["minimum_head_opacity"] != 1
        or not report["original_head_texture_retained"]
        or report["minimum_posture"] != 0 or report["maximum_posture"] != 1
        or edge_pixels or outside_native_window):
    raise SystemExit("Opacity, texture reuse, endpoint coverage or window clipping check failed.")
output = ROOT / "previews/cat-drag-swing-v3.webp"
frames[0].save(output, save_all=True, append_images=frames[1:], duration=42,
               loop=0, lossless=True, method=4)
# Arrange Godot's key-pose renders for review without changing the artwork.
poses = Image.new("RGBA", (1600, 344))
for index in range(5):
    poses.alpha_composite(Image.open(FRAME_DIR / f"pose-{index}.png").convert("RGBA"), (index * 320, 0))
    ImageDraw.Draw(poses).text((index * 320 + 120, 324), f"{index * 25}%", fill="white")
poses.save(ROOT / "previews/cat-pickup-poses-v3.png")
print(output)
