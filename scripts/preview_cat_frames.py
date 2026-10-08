"""Inspect generated frames and encode review animations without altering source PNGs."""
import json
from pathlib import Path

import numpy as np
from PIL import Image


ROOT = Path(__file__).resolve().parents[1]
ASSETS = ROOT / "assets" / "pets" / "cat"
OUTPUT = ROOT / "previews"
NAMES = ["idle-base-v1.png", "blink-half-v1.png", "blink-closed-v1.png"]


def main():
    images = [Image.open(ASSETS / name).convert("RGBA") for name in NAMES]
    size = images[0].size
    if any(image.size != size for image in images):
        raise ValueError("Blink frames must share one canvas size.")
    arrays = [np.array(image) for image in images]
    width, height = size
    eye_region = np.zeros((height, width), dtype=bool)
    for left, top, right, bottom in [(0.30, 0.34, 0.45, 0.49), (0.53, 0.34, 0.68, 0.49)]:
        eye_region[int(top * height):int(bottom * height), int(left * width):int(right * width)] = True
    base_alpha = arrays[0][:, :, 3] > 32
    report = {"canvas": list(size), "frames": []}
    for name, image, array in zip(NAMES, images, arrays):
        alpha = array[:, :, 3]
        if any(alpha[y, x] != 0 for y, x in [(0, 0), (0, width - 1), (height - 1, 0), (height - 1, width - 1)]):
            raise ValueError(f"{name} does not have transparent corners.")
        foreground = alpha > 32
        stable_pixels = base_alpha & foreground & ~eye_region
        rgb_difference = np.abs(array[:, :, :3].astype(float) - arrays[0][:, :, :3].astype(float))
        report["frames"].append({
            "file": name,
            "alpha_bbox": list(image.getchannel("A").getbbox()),
            "visible_alpha_bbox": list(Image.fromarray((foreground * 255).astype(np.uint8)).getbbox()),
            "silhouette_iou": round(float((base_alpha & foreground).sum() / (base_alpha | foreground).sum()), 6),
            "mean_rgb_difference_outside_eyes_0_to_255": round(float(rgb_difference[stable_pixels].mean()), 4),
        })
    OUTPUT.mkdir(exist_ok=True)
    # Encode frames rendered by Godot with the production eye-region shader.
    # All source PNGs stay unchanged.
    small = [Image.open(OUTPUT / "rendered" / f"{name}.png").convert("RGBA")
             for name in ["open", "half", "closed"]]
    rendered = [np.array(image) for image in small]
    render_width, render_height = small[0].size
    rendered_eye_region = np.zeros((render_height, render_width), dtype=bool)
    for left, top, right, bottom in [(0.315, 0.335, 0.450, 0.480), (0.545, 0.335, 0.675, 0.480)]:
        rendered_eye_region[int(top * render_height):int(bottom * render_height) + 1,
                            int(left * render_width):int(right * render_width) + 1] = True
    report["rendered_outside_eye_max_difference"] = []
    for frame in rendered[1:]:
        difference = np.abs(frame.astype(int) - rendered[0].astype(int))
        outside_max = int(difference[~rendered_eye_region].max())
        if outside_max != 0:
            raise ValueError("Rendered body differs outside the eye regions.")
        if difference[rendered_eye_region].sum() == 0:
            raise ValueError("Rendered blink eyes do not change.")
        report["rendered_outside_eye_max_difference"].append(outside_max)
    (OUTPUT / "cat-blink-v1.qa.json").write_text(json.dumps(report, indent=2) + "\n")
    sequence = [small[index] for index in [0, 1, 2, 1, 0]]
    durations = [1800, 40, 80, 40, 40]
    sequence[0].save(OUTPUT / "cat-blink-v1.webp", save_all=True, append_images=sequence[1:],
                     duration=durations, loop=0, lossless=True, method=6)
    # The slow version makes registration changes easier to review.
    sequence[0].save(OUTPUT / "cat-blink-slow-v1.webp", save_all=True, append_images=sequence[1:],
                     duration=[700, 300, 400, 300, 700], loop=0, lossless=True, method=6)
    print(json.dumps(report, indent=2))


if __name__ == "__main__":
    main()
