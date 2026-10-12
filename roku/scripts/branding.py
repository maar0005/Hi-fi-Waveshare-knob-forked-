"""Render Roku branding from the established HiPhi mark; requires ImageMagick."""
from pathlib import Path
import subprocess
ROOT = Path(__file__).resolve().parents[1]
FONT = ROOT / 'branding/FamiljenGrotesk.ttf'
MARK = ROOT / 'branding/hiphi-logo-512.png'
for profile, title in [('controller', 'HiPhi Control'), ('screensaver', 'HiPhi Artwork')]:
    output = ROOT / profile / 'images'
    output.mkdir(exist_ok=True)
    for kind, dimensions in [('icon', [('fhd',540,405), ('hd',290,218)]), ('splash', [('fhd',1920,1080), ('hd',1280,720)])]:
        for resolution, width, height in dimensions:
            scale = width / (540 if kind == 'icon' else 1920)
            mark_size, top, text_top, font_size = ((330, 10, 338, 42) if kind == 'icon' else (480, 180, 690, 76))
            subprocess.run(['magick', '-size', f'{width}x{height}', 'xc:#101012', '(', str(MARK), '-resize', f'{int(mark_size*scale)}x{int(mark_size*scale)}', ')', '-gravity', 'north', '-geometry', f'+0+{int(top*scale)}', '-composite', '-font', str(FONT), '-pointsize', str(int(font_size*scale)), '-fill', '#EEE8DA', '-gravity', 'north', '-annotate', f'+0+{int(text_top*scale)}', title, str(output/f'{kind}-{resolution}.png')], check=True)
