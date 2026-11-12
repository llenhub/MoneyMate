"""Regenerate MoneyMate's launcher and browser icons (requires Pillow)."""

from pathlib import Path
from PIL import Image, ImageDraw

image = Image.new("RGB", (512, 512), "#123d33")
draw = ImageDraw.Draw(image)
draw.rounded_rectangle((132, 169, 380, 345), radius=39, fill="#d8f1e5")
draw.rounded_rectangle((277, 223, 396, 296), radius=22, fill="#5bbb90")
draw.ellipse((307, 250, 326, 269), fill="#123d33")
draw.line([(170, 292), (213, 258), (242, 275), (267, 249)], fill="#276a51", width=12, joint="curve")


def write(path, size):
    image.resize((size, size), Image.Resampling.LANCZOS).save(path, optimize=True)


for size in (192, 512):
    write(Path(f"web/icons/Icon-{size}.png"), size)
    write(Path(f"web/icons/Icon-maskable-{size}.png"), size)
write(Path("web/favicon.png"), 48)

for density, size in (("mdpi", 48), ("hdpi", 72), ("xhdpi", 96), ("xxhdpi", 144), ("xxxhdpi", 192)):
    write(Path(f"android/app/src/main/res/mipmap-{density}/ic_launcher.png"), size)
