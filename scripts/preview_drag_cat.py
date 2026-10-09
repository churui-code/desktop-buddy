"""Validate and encode actual Godot renders; does not edit sprite artwork."""
import json
import argparse
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[1]
parser = argparse.ArgumentParser()
parser.add_argument("--version", default="v6")
version = parser.parse_args().version
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
held = np.array(Image.open(FRAME_DIR / "pose-10.png").convert("RGBA"))
reference = np.array(Image.open(FRAME_DIR / "held-reference.png").convert("RGBA"))
held_diff = np.abs(held.astype(np.int16) - reference.astype(np.int16))
held_visible = (held[:, :, 3] > 0) | (reference[:, :, 3] > 0)
rest_before = np.array(Image.open(FRAME_DIR / "assembled-rest.png").convert("RGBA")).astype(np.int16)
rest_after = np.array(Image.open(FRAME_DIR / "rest-after-drag.png").convert("RGBA")).astype(np.int16)
recovery_difference = int(np.abs(rest_before - rest_after).max())
report = {
    "source_canvas": [1254, 1254],
    "render_size": list(frames[0].size),
    "body_geometry": "nine painted pickup bodies, reverse playback and dedicated landing contact; endpoint physics",
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
(ROOT / f"previews/drag-cat-{version}.qa.json").write_text(json.dumps(report, indent=2) + "\n")
print(json.dumps(report, indent=2))
if (report["minimum_body_opacity"] != 1 or report["minimum_head_opacity"] != 1
        or not report["original_head_texture_retained"]
        or report["minimum_posture"] != 0 or report["maximum_posture"] != 1
        or report["held_alpha_max_difference"] > 3
        or report["held_visible_channel_max_difference"] > 4
        or recovery_difference > 1
        or report["painted_frame_indices_seen"] != list(range(10))
        or not report["painted_body_aspect_ratio_preserved"] or edge_pixels):
    raise SystemExit("Opacity, texture reuse, endpoint coverage or window clipping check failed.")
output = ROOT / f"previews/cat-drag-swing-{version}.webp"
frames[0].save(output, save_all=True, append_images=frames[1:], duration=42,
               loop=0, lossless=True, method=4)
# Review actual pickup/release frames at half speed, without the long hold.
review = frames[:30] + frames[106:]
review[0].save(ROOT / f"previews/cat-pickup-release-{version}.webp",
               save_all=True, append_images=review[1:], duration=84,
               loop=0, lossless=True, method=4)
# Arrange actual GPU poses, keeping source art intact.
poses = Image.new("RGBA", (1920, 688))
progress = [0, 14, 22.5, 31, 40, 49, 58, 67, 75, 83.5, 100]
for index, value in enumerate(progress):
    x, y = (index % 6) * 320, (index // 6) * 344
    poses.alpha_composite(Image.open(FRAME_DIR / f"pose-{index}.png").convert("RGBA"), (x, y))
    ImageDraw.Draw(poses).text((x + 120, y + 324), f"{value}%", fill="white")
poses.alpha_composite(Image.open(FRAME_DIR / "landing-contact.png").convert("RGBA"), (1600, 344))
ImageDraw.Draw(poses).text((1720, 668), "Contact", fill="white")
poses.save(ROOT / f"previews/cat-pickup-poses-{version}.png")
print(output)
