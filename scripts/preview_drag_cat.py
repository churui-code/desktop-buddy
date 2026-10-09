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
held = np.array(Image.open(FRAME_DIR / "pose-4.png").convert("RGBA"))
reference = np.array(Image.open(FRAME_DIR / "held-reference.png").convert("RGBA"))
held_diff = np.abs(held.astype(np.int16) - reference.astype(np.int16))
held_visible = (held[:, :, 3] > 0) | (reference[:, :, 3] > 0)
rest_before = np.array(Image.open(FRAME_DIR / "assembled-rest.png").convert("RGBA")).astype(np.int16)
rest_after = np.array(Image.open(FRAME_DIR / "rest-after-drag.png").convert("RGBA")).astype(np.int16)
recovery_difference = int(np.abs(rest_before - rest_after).max())
report = {
    "source_canvas": [1254, 1254],
    "render_size": list(frames[0].size),
    "body_geometry": "three painted pickup bodies, reverse playback and dedicated landing contact; endpoint physics",
    "painted_frame_indices_seen": sorted({s["painted_frame"] for s in samples if s["painted_frame"] >= 0}),
    "painted_body_aspect_ratio_preserved": all(s["uniform_body_scale"] for s in samples),
    "minimum_body_opacity": min(s["body_alpha"] for s in samples),
    "minimum_head_opacity": min(s["head_alpha"] for s in samples),
    "original_head_texture_retained": all(s["same_head_texture"] for s in samples),
    "minimum_posture": min(s["posture"] for s in samples),
    "maximum_posture": max(s["posture"] for s in samples),
    "animation_frame_count": len(frames),
    "held_alpha_max_difference": int(held_diff[:, :, 3].max()),
    "held_visible_channel_max_difference": int(held_diff[held_visible].max()),
    "rest_recovery_channel_max_difference": recovery_difference,
    "opaque_viewport_edge_pixels": edge_pixels,
    "native_window_size": [320, 320],
    "native_window_alpha_threshold": 3,
}
(ROOT / "previews/drag-cat-v5.qa.json").write_text(json.dumps(report, indent=2) + "\n")
print(json.dumps(report, indent=2))
if (report["minimum_body_opacity"] != 1 or report["minimum_head_opacity"] != 1
        or not report["original_head_texture_retained"]
        or report["minimum_posture"] != 0 or report["maximum_posture"] != 1
        or report["held_alpha_max_difference"] > 3
        or report["held_visible_channel_max_difference"] > 4
        or recovery_difference > 1
        or report["painted_frame_indices_seen"] != [0, 1, 2, 3]
        or not report["painted_body_aspect_ratio_preserved"] or edge_pixels):
    raise SystemExit("Opacity, texture reuse, endpoint coverage or window clipping check failed.")
output = ROOT / "previews/cat-drag-swing-v5.webp"
frames[0].save(output, save_all=True, append_images=frames[1:], duration=42,
               loop=0, lossless=True, method=4)
# Arrange Godot's key-pose renders for review without changing the artwork.
poses = Image.new("RGBA", (1920, 344))
for index in range(5):
    poses.alpha_composite(Image.open(FRAME_DIR / f"pose-{index}.png").convert("RGBA"), (index * 320, 0))
    ImageDraw.Draw(poses).text((index * 320 + 120, 324), f"{index * 25}%", fill="white")
poses.alpha_composite(Image.open(FRAME_DIR / "landing-contact.png").convert("RGBA"), (1600, 0))
ImageDraw.Draw(poses).text((1710, 324), "Contact", fill="white")
poses.save(ROOT / "previews/cat-pickup-poses-v5.png")
print(output)
