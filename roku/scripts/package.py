"""Build two reproducible developer ZIPs; never include credentials or device settings."""
import argparse
import hashlib
import shutil
import subprocess
from pathlib import Path
from zipfile import ZipFile, ZipInfo, ZIP_DEFLATED
ROOT = Path(__file__).resolve().parents[1]

def stage(profile):
    target = ROOT / '.out' / profile
    if target.exists():
        shutil.rmtree(target)
    shutil.copytree(ROOT / 'shared', target)
    shutil.copytree(ROOT / profile, target, dirs_exist_ok=True)
    return target

def package(profile):
    target = stage(profile)
    output = ROOT / 'dist' / f'hiphi-roku-{profile}.zip'
    output.parent.mkdir(exist_ok=True)
    with ZipFile(output, 'w') as archive:
        for file in sorted(target.rglob('*')):
            if not file.is_file():
                continue
            info = ZipInfo(file.relative_to(target).as_posix(), (2020, 1, 1, 0, 0, 0))
            info.compress_type = ZIP_DEFLATED
            info.external_attr = 0o100644 << 16
            archive.writestr(info, file.read_bytes())
    return output

if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--stage-only', choices=['controller', 'screensaver'])
    args = parser.parse_args()
    if args.stage_only:
        stage(args.stage_only)
    else:
        outputs = [package(p) for p in ['controller', 'screensaver']]
        (ROOT / 'dist' / 'SHA256.txt').write_text(''.join(f'{hashlib.sha256(p.read_bytes()).hexdigest()}  {p.name}\n' for p in outputs))
        sha = subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=ROOT, text=True).strip()
        dirty = subprocess.check_output(['git', 'status', '--porcelain', '--', 'roku'], cwd=ROOT, text=True).strip()
        (ROOT / 'dist' / 'BUILDINFO.txt').write_text(f'commit={sha}\nsource_dirty={bool(dirty)}\nTargets are unqualified until exact-artifact hardware tests pass.\n')
        shutil.copyfile(ROOT / 'README.md', ROOT / 'dist' / 'README.md')
        for p in outputs:
            print(p)
