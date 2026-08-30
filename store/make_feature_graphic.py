from PIL import Image, ImageDraw, ImageFont

W, H = 1024, 500
BG = (0, 0, 0)
ORANGE = (250, 129, 31)
GRAY = (160, 160, 160)

img = Image.new("RGB", (W, H), BG)

icon = Image.open("/Users/neharohilla/Desktop/calorie_tracker/store/ic_launcher_512.png").convert("RGB")
crop = icon.crop((26, 36, 486, 480))
crop = crop.resize((270, int(270 * crop.height / crop.width)), Image.LANCZOS)
img.paste(crop, (100, (H - crop.height) // 2))

draw = ImageDraw.Draw(img)
font_bold = ImageFont.truetype("/System/Library/Fonts/Supplemental/Arial Bold.ttf", 90)
font_reg = ImageFont.truetype("/System/Library/Fonts/Supplemental/Arial.ttf", 38)

draw.text((430, 148), "Cal Matters", font=font_bold, fill=(255, 255, 255))
draw.text((432, 280), "Snap it. AI logs your meal.", font=font_reg, fill=ORANGE)

img.save("/Users/neharohilla/Desktop/calorie_tracker/store/feature_graphic_1024x500.png")
print("saved")
