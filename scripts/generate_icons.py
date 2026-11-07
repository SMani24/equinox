#!/usr/bin/env python3
import os
import math
from PIL import Image, ImageDraw, ImageFont, ImageFilter

ARTIFACT_DIR = "/home/smani24/.gemini/antigravity/brain/4e10f13d-da04-4704-9836-3557b9275cf6"
ICONS_OUT_DIR = os.path.join(ARTIFACT_DIR, "icons")
ASSETS_ICONS_DIR = "/home/smani24/Desktop/Repositories/Equinox/assets/icons"

os.makedirs(ICONS_OUT_DIR, exist_ok=True)
os.makedirs(ASSETS_ICONS_DIR, exist_ok=True)

SCALE = 2
SIZE = 512 * SCALE  # 1024x1024 for 2x supersampling

def create_base_squircle(draw, size, bg_color1=(11, 13, 20), bg_color2=(22, 27, 38)):
    # Render rich radial / diagonal gradient squircle
    radius = int(size * 0.22)
    # Subtle dark gradient
    for y in range(size):
        ratio = y / size
        r = int(bg_color1[0] * (1 - ratio) + bg_color2[0] * ratio)
        g = int(bg_color1[1] * (1 - ratio) + bg_color2[1] * ratio)
        b = int(bg_color1[2] * (1 - ratio) + bg_color2[2] * ratio)
        draw.line([(0, y), (size, y)], fill=(r, g, b))

    # Mask to squircle / rounded rect
    mask = Image.new("L", (size, size), 0)
    mask_draw = ImageDraw.Draw(mask)
    margin = int(size * 0.04)
    mask_draw.rounded_rectangle([margin, margin, size - margin, size - margin], radius=radius, fill=255)
    return mask

def draw_squircle_border(draw, size, color=(255, 255, 255, 30), width=3):
    margin = int(size * 0.04)
    radius = int(size * 0.22)
    draw.rounded_rectangle([margin, margin, size - margin, size - margin], radius=radius, outline=color, width=width)

# 1. Celestial Equilibrium (Sun & Moon Equinox)
def render_icon_1():
    img = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    mask = create_base_squircle(draw, SIZE, (10, 12, 18), (20, 24, 36))
    
    cx, cy = SIZE // 2, SIZE // 2
    r = int(SIZE * 0.32)
    
    # Outer glow
    for dr in range(25, 0, -5):
        alpha = int(40 * (1 - dr / 25))
        draw.ellipse([cx - r - dr, cy - r - dr, cx + r + dr, cy + r + dr], outline=(16, 185, 129, alpha), width=3)
    
    # Left: Radiant Emerald Sun Arc (180 deg)
    draw.pieslice([cx - r, cy - r, cx + r, cy + r], 90, 270, fill=(16, 185, 129))
    
    # Sun rays
    for angle in range(110, 260, 25):
        rad = math.radians(angle)
        x1 = cx + (r + 15) * math.cos(rad)
        y1 = cy + (r + 15) * math.sin(rad)
        x2 = cx + (r + 55) * math.cos(rad)
        y2 = cy + (r + 55) * math.sin(rad)
        draw.line([(x1, y1), (x2, y2)], fill=(52, 211, 153), width=int(10 * SCALE))
        
    # Right: Amethyst Twilight Moon Arc
    draw.pieslice([cx - r, cy - r, cx + r, cy + r], 270, 450, fill=(139, 92, 246))
    # Moon crescent cut
    cr_offset = int(r * 0.42)
    draw.ellipse([cx + cr_offset - int(r*0.75), cy - int(r*0.75), cx + cr_offset + int(r*0.75), cy + int(r*0.75)], fill=(20, 24, 36))
    
    # Center Equinox Divider
    draw.line([(cx, cy - r - 20), (cx, cy + r + 20)], fill=(255, 255, 255, 240), width=int(6 * SCALE))
    # Meridian star
    draw.ellipse([cx - 16, cy - 16, cx + 16, cy + 16], fill=(255, 255, 255))
    
    draw_squircle_border(draw, SIZE)
    img.putalpha(mask)
    return img

# 2. The Chrono Dial
def render_icon_2():
    img = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    mask = create_base_squircle(draw, SIZE, (12, 14, 20), (18, 22, 30))
    
    cx, cy = SIZE // 2, SIZE // 2
    r = int(SIZE * 0.34)
    
    # Outer Dial ring
    track_w = int(14 * SCALE)
    # Upper half: Emerald (+ Work)
    draw.arc([cx - r, cy - r, cx + r, cy + r], 180, 360, fill=(16, 185, 129), width=track_w)
    # Lower half: Coral (- Rest)
    draw.arc([cx - r, cy - r, cx + r, cy + r], 0, 180, fill=(244, 63, 94), width=track_w)
    
    # Hour tick marks
    for h in range(12):
        angle = h * 30
        rad = math.radians(angle)
        t_in = r - 25 * SCALE
        t_out = r - 10 * SCALE
        x1 = cx + t_in * math.cos(rad)
        y1 = cy + t_in * math.sin(rad)
        x2 = cx + t_out * math.cos(rad)
        y2 = cy + t_out * math.sin(rad)
        color = (255, 255, 255, 200) if h % 3 == 0 else (255, 255, 255, 80)
        draw.line([(x1, y1), (x2, y2)], fill=color, width=int(3 * SCALE if h % 3 == 0 else 1.5 * SCALE))
        
    # Floating Precision Needle at 12 o'clock (Zero equilibrium)
    needle_top = cy - int(r * 0.85)
    needle_w = int(6 * SCALE)
    draw.polygon([
        (cx - needle_w, cy),
        (cx, needle_top),
        (cx + needle_w, cy),
        (cx, cy + 25 * SCALE)
    ], fill=(255, 255, 255))
    
    # Glowing center pivot
    draw.ellipse([cx - 18 * SCALE, cy - 18 * SCALE, cx + 18 * SCALE, cy + 18 * SCALE], fill=(6, 182, 212))
    draw.ellipse([cx - 8 * SCALE, cy - 8 * SCALE, cx + 8 * SCALE, cy + 8 * SCALE], fill=(255, 255, 255))
    
    draw_squircle_border(draw, SIZE)
    img.putalpha(mask)
    return img

# 3. Geometric 'E' Prism
def render_icon_3():
    img = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    mask = create_base_squircle(draw, SIZE, (8, 10, 16), (15, 18, 28))
    
    cx, cy = SIZE // 2, SIZE // 2
    
    # 3 Floating Precision Beams
    beam_w = int(240 * SCALE)
    beam_h = int(32 * SCALE)
    x_left = cx - int(120 * SCALE)
    
    # Vertical connecting spine on left
    spine_x = x_left
    spine_y1 = cy - int(120 * SCALE)
    spine_y2 = cy + int(120 * SCALE)
    draw.rounded_rectangle([spine_x, spine_y1, spine_x + beam_h, spine_y2 + beam_h], radius=int(12*SCALE), fill=(99, 102, 241))
    
    # Top Beam: Emerald Focus (+Work)
    draw.rounded_rectangle([x_left, spine_y1, x_left + beam_w, spine_y1 + beam_h], radius=int(12*SCALE), fill=(16, 185, 129))
    # Mid Beam: Pure Diamond Fulcrum
    draw.rounded_rectangle([x_left, cy - beam_h//2, x_left + int(beam_w * 0.72), cy + beam_h//2], radius=int(12*SCALE), fill=(248, 250, 252))
    # Bottom Beam: Amethyst Calm (-Rest)
    draw.rounded_rectangle([x_left, spine_y2, x_left + beam_w, spine_y2 + beam_h], radius=int(12*SCALE), fill=(168, 85, 247))
    
    # Center Equilibrium indicator dot
    draw.ellipse([x_left + beam_w - 20, cy - 10, x_left + beam_w + 10, cy + 20], fill=(6, 182, 212))
    
    draw_squircle_border(draw, SIZE)
    img.putalpha(mask)
    return img

# 4. Glassmorphism Hourglass
def render_icon_4():
    img = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    mask = create_base_squircle(draw, SIZE, (10, 11, 18), (22, 26, 40))
    
    cx, cy = SIZE // 2, SIZE // 2
    h = int(180 * SCALE)
    w = int(140 * SCALE)
    
    # Top triangle (Emerald chamber)
    draw.polygon([(cx - w, cy - h), (cx + w, cy - h), (cx, cy)], fill=(16, 185, 129, 210))
    # Top sand level
    draw.polygon([(cx - int(w*0.7), cy - int(h*0.4)), (cx + int(w*0.7), cy - int(h*0.4)), (cx, cy)], fill=(52, 211, 153))
    
    # Bottom triangle (Amethyst chamber)
    draw.polygon([(cx, cy), (cx + w, cy + h), (cx - w, cy + h)], fill=(139, 92, 246, 210))
    # Bottom sand pile
    draw.polygon([(cx - int(w*0.8), cy + h), (cx + int(w*0.8), cy + h), (cx, cy + int(h*0.45))], fill=(192, 132, 252))
    
    # Stream of light down center
    draw.line([(cx, cy - 20), (cx, cy + int(h*0.5))], fill=(255, 255, 255), width=int(5 * SCALE))
    
    # Horizontal Equinox Horizon Ring at waist
    draw.ellipse([cx - int(w*0.6), cy - int(16*SCALE), cx + int(w*0.6), cy + int(16*SCALE)], outline=(255, 255, 255, 230), width=int(5*SCALE))
    
    # Hourglass Frame lines
    draw.line([(cx - w, cy - h), (cx + w, cy - h)], fill=(255, 255, 255, 200), width=int(8*SCALE))
    draw.line([(cx - w, cy + h), (cx + w, cy + h)], fill=(255, 255, 255, 200), width=int(8*SCALE))
    
    draw_squircle_border(draw, SIZE)
    img.putalpha(mask)
    return img

# 5. Orbital Yin-Yang
def render_icon_5():
    img = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    mask = create_base_squircle(draw, SIZE, (10, 13, 22), (18, 22, 34))
    
    cx, cy = SIZE // 2, SIZE // 2
    r = int(SIZE * 0.32)
    
    # Base circle: Emerald left half
    draw.pieslice([cx - r, cy - r, cx + r, cy + r], 90, 270, fill=(16, 185, 129))
    # Base circle: Violet right half
    draw.pieslice([cx - r, cy - r, cx + r, cy + r], 270, 450, fill=(236, 72, 153))
    
    # Top inner circle (Emerald)
    r_half = r // 2
    draw.ellipse([cx - r_half, cy - r, cx + r_half, cy], fill=(16, 185, 129))
    # Bottom inner circle (Violet)
    draw.ellipse([cx - r_half, cy, cx + r_half, cy + r], fill=(236, 72, 153))
    
    # Contrasting pearls
    p_r = int(22 * SCALE)
    draw.ellipse([cx - p_r, cy - r_half - p_r, cx + p_r, cy - r_half + p_r], fill=(255, 255, 255))
    draw.ellipse([cx - p_r, cy + r_half - p_r, cx + p_r, cy + r_half + p_r], fill=(15, 23, 42))
    
    # Ambient outer orbital glow
    draw.arc([cx - r - 20, cy - r - 20, cx + r + 20, cy + r + 20], 0, 360, fill=(255, 255, 255, 40), width=int(3*SCALE))
    
    draw_squircle_border(draw, SIZE)
    img.putalpha(mask)
    return img

# 6. Minimalist Balance Scales
def render_icon_6():
    img = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    mask = create_base_squircle(draw, SIZE, (9, 12, 18), (17, 21, 32))
    
    cx, cy = SIZE // 2, SIZE // 2
    
    # Triangular Fulcrum Base
    f_w = int(50 * SCALE)
    f_h = int(90 * SCALE)
    draw.polygon([(cx, cy - int(20*SCALE)), (cx + f_w, cy + f_h), (cx - f_w, cy + f_h)], fill=(71, 85, 105))
    
    # Horizontal Beam (Perfect Balance)
    beam_w = int(180 * SCALE)
    beam_h = int(8 * SCALE)
    draw.rounded_rectangle([cx - beam_w, cy - int(24*SCALE), cx + beam_w, cy - int(16*SCALE)], radius=int(4*SCALE), fill=(248, 250, 252))
    
    # Left Pan: Emerald Prism (+ Productive)
    pan_drop = int(80 * SCALE)
    left_x = cx - int(beam_w * 0.85)
    draw.line([(left_x, cy - int(20*SCALE)), (left_x, cy + pan_drop)], fill=(148, 163, 184), width=int(2*SCALE))
    # Pan disc
    draw.ellipse([left_x - int(35*SCALE), cy + pan_drop, left_x + int(35*SCALE), cy + pan_drop + int(14*SCALE)], fill=(16, 185, 129))
    # Glowing cube on left
    draw.rounded_rectangle([left_x - int(22*SCALE), cy + pan_drop - int(45*SCALE), left_x + int(22*SCALE), cy + pan_drop], radius=int(5*SCALE), fill=(52, 211, 153))
    
    # Right Pan: Rose Sphere (- Rest)
    right_x = cx + int(beam_w * 0.85)
    draw.line([(right_x, cy - int(20*SCALE)), (right_x, cy + pan_drop)], fill=(148, 163, 184), width=int(2*SCALE))
    draw.ellipse([right_x - int(35*SCALE), cy + pan_drop, right_x + int(35*SCALE), cy + pan_drop + int(14*SCALE)], fill=(244, 63, 94))
    # Glowing sphere on right
    draw.ellipse([right_x - int(24*SCALE), cy + pan_drop - int(48*SCALE), right_x + int(24*SCALE), cy + pan_drop], fill=(251, 113, 133))
    
    # Center Pivot Gem
    draw.ellipse([cx - int(14*SCALE), cy - int(30*SCALE), cx + int(14*SCALE), cy - int(2*SCALE)], fill=(6, 182, 212))
    
    draw_squircle_border(draw, SIZE)
    img.putalpha(mask)
    return img

# 7. Total Eclipse Corona
def render_icon_7():
    img = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    mask = create_base_squircle(draw, SIZE, (6, 8, 14), (14, 16, 24))
    
    cx, cy = SIZE // 2, SIZE // 2
    r = int(SIZE * 0.28)
    
    # Multi-layered glowing corona
    for dr in range(70, 0, -6):
        alpha = int(90 * (1 - dr / 70))
        # Left half emerald
        draw.arc([cx - r - dr, cy - r - dr, cx + r + dr, cy + r + dr], 90, 270, fill=(16, 185, 129, alpha), width=int(8*SCALE))
        # Right half electric violet
        draw.arc([cx - r - dr, cy - r - dr, cx + r + dr, cy + r + dr], 270, 450, fill=(168, 85, 247, alpha), width=int(8*SCALE))
    
    # Jet black moon silhouette
    draw.ellipse([cx - r, cy - r, cx + r, cy + r], fill=(8, 10, 16))
    
    # Subtle inner eclipse rim light
    draw.arc([cx - r, cy - r, cx + r, cy + r], 90, 270, fill=(52, 211, 153), width=int(4*SCALE))
    draw.arc([cx - r, cy - r, cx + r, cy + r], 270, 450, fill=(192, 132, 252), width=int(4*SCALE))
    
    # Diamond flare at 12 o'clock (Equinox point)
    draw.ellipse([cx - int(16*SCALE), cy - r - int(16*SCALE), cx + int(16*SCALE), cy - r + int(16*SCALE)], fill=(255, 255, 255))
    
    draw_squircle_border(draw, SIZE)
    img.putalpha(mask)
    return img

# 8. Obsidian Facet Gem
def render_icon_8():
    img = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    mask = create_base_squircle(draw, SIZE, (10, 12, 18), (18, 22, 32))
    
    cx, cy = SIZE // 2, SIZE // 2
    s = int(160 * SCALE)
    
    # Diamond / Hexagon Isometric Gem
    p_top = (cx, cy - s)
    p_right = (cx + s, cy)
    p_bottom = (cx, cy + s)
    p_left = (cx - s, cy)
    p_center = (cx, cy)
    
    # Top-Left Facet: Emerald Glow
    draw.polygon([p_top, p_center, p_left], fill=(16, 185, 129, 230))
    # Bottom-Left Facet: Cyan Glow
    draw.polygon([p_left, p_center, p_bottom], fill=(6, 182, 212, 210))
    # Top-Right Facet: Violet Calm
    draw.polygon([p_top, p_right, p_center], fill=(139, 92, 246, 230))
    # Bottom-Right Facet: Pink Calm
    draw.polygon([p_center, p_right, p_bottom], fill=(236, 72, 153, 210))
    
    # Facet edge highlights
    for p1, p2 in [(p_top, p_bottom), (p_left, p_right), (p_top, p_left), (p_top, p_right), (p_bottom, p_left), (p_bottom, p_right)]:
        draw.line([p1, p2], fill=(255, 255, 255, 180), width=int(4*SCALE))
        
    draw_squircle_border(draw, SIZE)
    img.putalpha(mask)
    return img

# 9. Kinetic Chrono Rings
def render_icon_9():
    img = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    mask = create_base_squircle(draw, SIZE, (11, 14, 22), (19, 24, 38))
    
    cx, cy = SIZE // 2, SIZE // 2
    
    # Ring 1: Outer Productive Arc (Emerald)
    r1 = int(SIZE * 0.35)
    draw.arc([cx - r1, cy - r1, cx + r1, cy + r1], 140, 380, fill=(16, 185, 129), width=int(14*SCALE))
    # Orb on Ring 1
    orb1_rad = math.radians(380)
    draw.ellipse([cx + r1*math.cos(orb1_rad) - 15, cy + r1*math.sin(orb1_rad) - 15, cx + r1*math.cos(orb1_rad) + 15, cy + r1*math.sin(orb1_rad) + 15], fill=(52, 211, 153))
    
    # Ring 2: Mid Rest Arc (Coral)
    r2 = int(SIZE * 0.25)
    draw.arc([cx - r2, cy - r2, cx + r2, cy + r2], 20, 200, fill=(244, 63, 94), width=int(12*SCALE))
    orb2_rad = math.radians(20)
    draw.ellipse([cx + r2*math.cos(orb2_rad) - 13, cy + r2*math.sin(orb2_rad) - 13, cx + r2*math.cos(orb2_rad) + 13, cy + r2*math.sin(orb2_rad) + 13], fill=(251, 113, 133))
    
    # Ring 3: Center Equilibrium Circle (White)
    r3 = int(SIZE * 0.14)
    draw.arc([cx - r3, cy - r3, cx + r3, cy + r3], 0, 360, fill=(255, 255, 255), width=int(8*SCALE))
    draw.ellipse([cx - 10, cy - 10, cx + 10, cy + 10], fill=(6, 182, 212))
    
    draw_squircle_border(draw, SIZE)
    img.putalpha(mask)
    return img

# 10. Golden Equinox 'Q' Loop
def render_icon_10():
    img = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    mask = create_base_squircle(draw, SIZE, (10, 12, 19), (20, 24, 36))
    
    cx, cy = SIZE // 2, SIZE // 2 - int(20 * SCALE)
    r = int(SIZE * 0.27)
    loop_w = int(22 * SCALE)
    
    # Continuous Gradient Loop: Emerald -> Cyan -> Purple -> Coral
    draw.arc([cx - r, cy - r, cx + r, cy + r], 135, 225, fill=(16, 185, 129), width=loop_w) # Emerald
    draw.arc([cx - r, cy - r, cx + r, cy + r], 225, 315, fill=(6, 182, 212), width=loop_w)  # Cyan
    draw.arc([cx - r, cy - r, cx + r, cy + r], 315, 405, fill=(168, 85, 247), width=loop_w) # Violet
    draw.arc([cx - r, cy - r, cx + r, cy + r], 45, 135, fill=(244, 63, 94), width=loop_w)   # Coral
    
    # 45-degree Axial Tilt Tail (forming the iconic 'Q' / Chrono balance)
    tail_rad = math.radians(45)
    tx1 = cx + int(r * 0.6 * math.cos(tail_rad))
    ty1 = cy + int(r * 0.6 * math.sin(tail_rad))
    tx2 = cx + int((r + 90 * SCALE) * math.cos(tail_rad))
    ty2 = cy + int((r + 90 * SCALE) * math.sin(tail_rad))
    draw.line([(tx1, ty1), (tx2, ty2)], fill=(255, 255, 255), width=int(18 * SCALE))
    
    # Luminous Core Star
    draw.ellipse([cx - 14*SCALE, cy - 14*SCALE, cx + 14*SCALE, cy + 14*SCALE], fill=(255, 255, 255))
    
    draw_squircle_border(draw, SIZE)
    img.putalpha(mask)
    return img

RENDERERS = [
    ("Icon 1", "Celestial Equilibrium", "Sun & Moon Equinox duality with meridian axis", render_icon_1),
    ("Icon 2", "Chrono Equilibrium Dial", "Precision dial with emerald work / coral rest arcs", render_icon_2),
    ("Icon 3", "Prism Monogram 'E'", "Modern architectural E prism with balanced light beams", render_icon_3),
    ("Icon 4", "Hourglass Flux", "Glassmorphism hourglass with emerald flux & calm violet", render_icon_4),
    ("Icon 5", "Orbital Yin-Yang", "Dynamic comet orbital duality in emerald & electric violet", render_icon_5),
    ("Icon 6", "Scales of Time", "Minimalist balance beam weighing work prism & rest sphere", render_icon_6),
    ("Icon 7", "Eclipse Corona", "Equinox eclipse with emerald solar flare & violet twilight", render_icon_7),
    ("Icon 8", "Obsidian Facet Gem", "3D isometric faceted crystal with radiant neon reflections", render_icon_8),
    ("Icon 9", "Kinetic Chrono Rings", "Triple concentric kinetic flow rings with orbital pulse beads", render_icon_9),
    ("Icon 10", "Equinox 'Q' Loop", "Chrono loop with 45-degree axial tilt beam and core star", render_icon_10),
]

def main():
    saved_paths = []
    generated_images = []
    
    for i, (num, title, desc, fn) in enumerate(RENDERERS, 1):
        full_img = fn()
        # Downsample to 512x512 with LANCZOS for gorgeous antialiasing
        final_img = full_img.resize((512, 512), Image.Resampling.LANCZOS)
        
        clean_title = title.lower().replace(' ', '_').replace("'", '')
        filename = f"icon_{i:02d}_{clean_title}.png"
        path1 = os.path.join(ICONS_OUT_DIR, filename)
        path2 = os.path.join(ASSETS_ICONS_DIR, filename)
        
        final_img.save(path1, "PNG")
        final_img.save(path2, "PNG")
        saved_paths.append((path1, num, title, desc))
        generated_images.append(final_img)
        print(f"Rendered {num}: {title} -> {path1}")

    # Now render a 2x5 showcase image
    showcase_w = 1800
    showcase_h = 920
    showcase = Image.new("RGBA", (showcase_w, showcase_h), (11, 13, 20, 255))
    s_draw = ImageDraw.Draw(showcase)
    
    try:
        font_num = ImageFont.truetype("/usr/share/fonts/fonts-go/Go-Bold.ttf", 26)
        font_title = ImageFont.truetype("/usr/share/fonts/fonts-go/Go-Bold.ttf", 19)
        font_desc = ImageFont.truetype("/usr/share/fonts/fonts-go/Go-Medium.ttf", 14)
    except:
        font_num = font_title = font_desc = ImageFont.load_default()
        
    s_draw.text((60, 36), "EQUINOX APP ICON DESIGNS (10 OPTIONS)", font=font_num, fill=(248, 250, 252))
    s_draw.text((60, 72), "Select your favorite design to replace the default launcher icon", font=font_desc, fill=(148, 163, 184))
    
    icon_display_size = 190
    col_w = 330
    row_h = 360
    start_x = 75
    start_y = 120
    
    for idx, (img, (path, num, title, desc)) in enumerate(zip(generated_images, saved_paths)):
        r_idx = idx // 5
        c_idx = idx % 5
        
        x = start_x + c_idx * col_w
        y = start_y + r_idx * row_h
        
        thumb = img.resize((icon_display_size, icon_display_size), Image.Resampling.LANCZOS)
        showcase.paste(thumb, (x, y), thumb)
        
        # Labels below icon
        s_draw.text((x, y + icon_display_size + 14), num, font=font_title, fill=(16, 185, 129))
        s_draw.text((x, y + icon_display_size + 38), title, font=font_title, fill=(248, 250, 252))
        
        # Word wrap desc
        words = desc.split(" ")
        line1 = " ".join(words[:4])
        line2 = " ".join(words[4:])
        s_draw.text((x, y + icon_display_size + 64), line1, font=font_desc, fill=(148, 163, 184))
        if line2:
            s_draw.text((x, y + icon_display_size + 84), line2, font=font_desc, fill=(148, 163, 184))
            
    showcase_path = os.path.join(ARTIFACT_DIR, "icons_showcase.png")
    showcase.save(showcase_path, "PNG")
    showcase.save(os.path.join(ASSETS_ICONS_DIR, "icons_showcase.png"), "PNG")
    print(f"Showcase image created at: {showcase_path}")

    # Also automatically set Icon 1 (Celestial Equilibrium) into Android mipmap sizes as high-polish default!
    mipmap_targets = [
        ("mipmap-mdpi", 48),
        ("mipmap-hdpi", 72),
        ("mipmap-xhdpi", 96),
        ("mipmap-xxhdpi", 144),
        ("mipmap-xxxhdpi", 192),
    ]
    primary_icon = generated_images[0] # Icon 1: Celestial Equilibrium
    for folder, px in mipmap_targets:
        out_f = f"/home/smani24/Desktop/Repositories/Equinox/android/app/src/main/res/{folder}/ic_launcher.png"
        resized = primary_icon.resize((px, px), Image.Resampling.LANCZOS)
        resized.save(out_f, "PNG")
        print(f"Saved {px}x{px} launcher icon to {out_f}")

if __name__ == "__main__":
    main()
