#!/usr/bin/env python3
"""Render reviewed Alpha comparisons and previews against published firmware."""

from __future__ import annotations

import argparse
import html
import json
import re
import shutil
from pathlib import Path



TARGETS = (
    ("dial", "flash-dial.html"),
    ("frame", "flash-frame.html"),
    ("rlcd", "flash-rlcd.html"),
    ("joy", "flash-joy.html"),
    ("halo", "flash-halo.html"),
    ("tough", "flash-tough.html"),
    ("m5dial", "flash-m5dial.html"),
    ("sticks3", "flash-sticks3.html"),
    ("stopwatch", "flash-stopwatch.html"),
    ("stackchan", "flash-stackchan.html"),
)


def render(template: str, replacements: dict[str, str]) -> str:
    for token, value in replacements.items():
        template = template.replace("{{" + token + "}}", value)

    # Site previews exercise current HTML/CSS while deliberately flashing the
    # last published alpha. Absolute paths keep manifests and downloads on the
    # firmware origin without copying release artifacts into every PR preview.
    template = re.sub(
        r'manifest="(?:\./)?(manifest-[^"]+\.json)"',
        r'manifest="/alpha/\1"',
        template,
    )
    template = re.sub(
        r'href="\./(hiphi_[^"]+\.bin)"',
        r'href="/alpha/\1"',
        template,
    )
    return template


START = '<!-- alpha-comparison:start -->'
END = '<!-- alpha-comparison:end -->'


def inline(text):
    text = html.escape(text)
    text = re.sub(r'\*\*([^*]+)\*\*', r'<strong>\1</strong>', text)
    return re.sub(
        r'\[([^\]]+)\]\((https://[^\s)]+)\)',
        r'<a href="\2">\1</a>', text,
    )


def parse_notes(source):
    lines = source.splitlines()
    match = re.fullmatch(
        r'# Alpha v(\d+\.\d+\.\d+-alpha\.\d+) compared with Stable v(\d+\.\d+\.\d+)',
        lines[0] if lines else '',
    )
    if not match:
        raise ValueError('Alpha changelog needs exact alpha and stable versions')
    sections = {}
    section = None
    for line in lines[1:]:
        if line.startswith('## '):
            section = line[3:]
            if section in sections:
                raise ValueError('Duplicate alpha changelog section')
            sections[section] = []
        elif line.strip():
            if section is None:
                raise ValueError('Alpha changelog content must belong to a section')
            sections[section].append(line)
    compatibility = [name for name in sections if re.fullmatch(r'Requires UHC v[0-9]+', name)]
    if len(compatibility) != 1:
        raise ValueError('Alpha changelog needs a UHC version requirement')
    required = {compatibility[0], "What's different", 'Testing status'}
    if set(sections) != required or any(not sections[k] for k in required):
        raise ValueError('Alpha changelog needs compatibility, changes and testing status')
    if any(not line.startswith('- ') for line in sections["What's different"]):
        raise ValueError('Alpha changes must be Markdown bullet points')
    return match.groups(), sections


def comparison(source, version):
    (alpha, stable), sections = parse_notes(source)
    if alpha != version:
        raise ValueError(f'Update alpha-changelog.md for {version}; notes describe {alpha}')
    compatibility = next(name for name in sections if name.startswith('Requires UHC v'))
    paragraphs = lambda name: ''.join(f'<p>{inline(x)}</p>' for x in sections[name])
    changes = ''.join(f'<li>{inline(x[2:])}</li>' for x in sections["What's different"])
    return (
        '<section class="alpha-comparison" aria-labelledby="alpha-comparison-title">'
        '<div class="alpha-comparison-heading">'
        '<h2 id="alpha-comparison-title">What’s different from Stable?</h2>'
        f'<p>Alpha v{alpha} compared with Stable v{stable}.</p></div>'
        '<div class="alpha-comparison-content">'
        '<aside class="alpha-compatibility" aria-labelledby="alpha-compatibility-title">'
        f'<h3 id="alpha-compatibility-title">{inline(compatibility)}</h3>'
        f'{paragraphs(compatibility)}</aside>'
        f'<div><ul class="alpha-changes">{changes}</ul>'
        '<details class="alpha-testing"><summary>What has been tested?</summary>'
        f'{paragraphs("Testing status")}</details>'
        f'<p><a href="https://github.com/muness/roon-knob/releases/tag/v{alpha}">'
        'Read the full alpha release notes</a></p></div></div></section>'
    )


def render_alpha_comparisons(directory: Path):
    updates = []
    for page in directory.glob('*.html'):
        text = page.read_text()
        if START not in text:
            continue
        if 'data-channel="alpha"' in text:
            match = re.search(r'class="context-line"[^>]*>[^<]* / v([^<]+)<', text)
            if not match:
                raise ValueError(f'{page.name}: missing alpha version')
            version = match[1]
            # Unreleased firmware previews have their own provenance notice;
            # never show released-alpha claims for a different development build.
            if version.endswith('-dev') or version.startswith('pr-'):
                content = ''
            else:
                notes = (directory / 'assets/alpha-changelog.md').read_text()
                content = comparison(notes, version)
        else:
            content = ''
        updated, count = re.subn(
            re.escape(START) + r'.*?' + re.escape(END),
            lambda _: START + content + END, text, flags=re.DOTALL,
        )
        if count != 1:
            raise ValueError(f'{page.name}: expected one comparison slot')
        updates.append((page, updated))
    # Validate every page before changing any file.
    for page, text in updates:
        page.write_text(text)


def main() -> None:
    from version_firmware_site_assets import prepare_site
    parser = argparse.ArgumentParser()
    parser.add_argument("--web-dir", type=Path, required=True)
    parser.add_argument("--published-alpha-dir", type=Path, required=True)
    parser.add_argument("--output-dir", type=Path, required=True)
    parser.add_argument("--pr-number", required=True)
    parser.add_argument("--head-sha", required=True)
    parser.add_argument("--run-url", required=True)
    args = parser.parse_args()

    manifest = json.loads(
        (args.published_alpha_dir / "manifest-frame.json").read_text()
    )
    version = manifest["version"]
    output = args.output_dir
    output.mkdir(parents=True, exist_ok=True)
    shutil.copytree(args.web_dir / "assets", output / "assets", dirs_exist_ok=True)

    index = (args.web_dir / "index.html").read_text()
    for channel in ("stable", "beta", "alpha"):
        index = index.replace(f'href="./{channel}/"', f'href="/{channel}/"')
    (output / "index.html").write_text(index)

    short_sha = args.head_sha[:12]
    notice = (
        '<div class="channel-notice alpha"><strong>Site-only PR preview.</strong>'
        f'<p>UI from PR #{args.pr_number} commit <code>{short_sha}</code>; '
        f'Flash actions use the already-published alpha v{version} binaries. '
        f'<a href="{args.run_url}">Preview run ↗</a></p></div>'
    )
    common = {
        "VERSION": version,
        "RELEASE_CHANNEL": "alpha",
        "RELEASE_CHANNEL_NAME": "Site preview",
        "RELEASE_CHANNEL_NOTICE": notice,
        "RELEASE_LINK": (
            f'<a href="https://github.com/muness/roon-knob/pull/{args.pr_number}">'
            f'Review PR #{args.pr_number} ↗</a>'
        ),
    }
    template = (args.web_dir / "flash.html").read_text()
    (output / "flash.html").write_text(
        render(template, {**common, "TARGET_FILTER": ""})
    )
    for target, filename in TARGETS:
        (output / filename).write_text(
            render(template, {**common, "TARGET_FILTER": target})
        )

    prepare_site(output)
    unresolved = list(output.glob("*.html"))
    for page in unresolved:
        text = page.read_text()
        if re.search(r"\{\{[^}]+\}\}", text):
            raise SystemExit(f"unresolved template token in {page}")
        if 'manifest="./manifest-' in text:
            raise SystemExit(f"relative preview manifest in {page}")


if __name__ == "__main__":
    main()
