# Composes three real Simulator screenshots side by side for the article and README.
# Run from the repo root after Scripts/simulator-screenshots.sh: python3 docs/src/compose_simulator.py
from PIL import Image, ImageDraw, ImageFont

names = ["replay-27-oct", "spec-lint", "monitors"]
labels = ["27 Oct: 4 of 12 refused", "Spec lint", "Who noticed?"]
ims = [Image.open(f"Demo/Screenshots/{n}.png").convert("RGB") for n in names]
s = 0.42
w, h = int(ims[0].width * s), int(ims[0].height * s)
pad, top = 36, 76
out = Image.new("RGB", (pad + 3 * (w + pad), h + top + pad), "#f6f8fa")
d = ImageDraw.Draw(out)
font = ImageFont.load_default()
for path in ["/usr/share/fonts/opentype/inter/Inter-SemiBold.otf",
             "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf",
             "/System/Library/Fonts/Supplemental/Arial Bold.ttf"]:
    try:
        font = ImageFont.truetype(path, 30)
        break
    except OSError:
        continue
for i, im in enumerate(ims):
    x = pad + i * (w + pad)
    d.text((x, 24), labels[i], fill="#1f2328", font=font)
    out.paste(im.resize((w, h), Image.LANCZOS), (x, top))
    d.rectangle([x - 1, top - 1, x + w, top + h], outline="#d0d7de", width=2)
out.save("docs/simulator.png", optimize=True)
print(out.size)
