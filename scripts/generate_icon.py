"""Optional design utility; Pillow is NOT an app/build dependency. The PNG is included."""
import json
from pathlib import Path

from PIL import Image, ImageDraw

root = Path(__file__).resolve().parents[1] / "MiDinero/Resources/Assets.xcassets"
destination = root / "AppIcon.appiconset"
destination.mkdir(parents=True, exist_ok=True)
scale = 3
image = Image.new("RGB", (1024 * scale, 1024 * scale), "#3634A4")
draw = ImageDraw.Draw(image)


def rect(box, radius, fill):
    draw.rounded_rectangle(tuple(v * scale for v in box), radius=radius * scale, fill=fill)


rect((238, 185, 786, 839), 84, "#FFFFFF")
rect((324, 302, 665, 334), 16, "#3634A4")
rect((324, 400, 579, 432), 16, "#3634A4")
rect((324, 498, 504, 530), 16, "#3634A4")
draw.ellipse(tuple(v * scale for v in (548, 584, 854, 890)), fill="#3634A4", outline="#FFFFFF", width=20 * scale)
rect((679, 662, 723, 812), 15, "#FFFFFF")
rect((626, 715, 776, 759), 15, "#FFFFFF")
image.resize((1024, 1024), Image.Resampling.LANCZOS).save(destination / "AppIcon.png")
(root / "Contents.json").write_text(json.dumps({"info": {"author": "xcode", "version": 1}}, indent=2) + "\n", encoding="utf-8", newline="\n")
(destination / "Contents.json").write_text(json.dumps({
    "images": [{"filename": "AppIcon.png", "idiom": "universal", "platform": "ios", "size": "1024x1024"}],
    "info": {"author": "xcode", "version": 1}
}, indent=2) + "\n", encoding="utf-8", newline="\n")
print("Generated RGB 1024x1024 AppIcon.png and asset catalogs")
