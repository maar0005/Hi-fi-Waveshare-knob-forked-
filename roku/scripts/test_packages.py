import hashlib
import importlib.util
from pathlib import Path
from zipfile import ZipFile
spec = importlib.util.spec_from_file_location('packaging', Path(__file__).with_name('package.py'))
p = importlib.util.module_from_spec(spec)
spec.loader.exec_module(p)
for profile in ['controller', 'screensaver']:
    file = p.package(profile)
    first = hashlib.sha256(file.read_bytes()).digest()
    assert first == hashlib.sha256(p.package(profile).read_bytes()).digest(), 'Non-deterministic ZIP'
    with ZipFile(file) as z:
        names = z.namelist()
        assert 'manifest' in names and 'source/Main.brs' in names
        assert 'images/icon-hd.png' in names and 'images/splash-hd.png' in names
        assert 'source/Model.brs' in names and 'components/BridgeTask.brs' in names
        assert not any(n.startswith('../') or 'node_modules' in n or 'tests/' in n for n in names)
        entry = z.read('source/Main.brs').decode()
        manifest = z.read('manifest').decode()
        assert manifest.endswith('\n')
        art = z.read('components/ArtScene.brs').decode()
        assert 'loadDisplayMode = "scaleToFit"' in art, 'Second centered crop would lose subjects'
        assert 'roUrlTransfer' not in art, 'Network transfer on render thread'
        assert 'Pin listening zone' in z.read('components/SettingsScene.xml').decode()
        if profile == 'screensaver':
            assert 'screensaver_title=' in manifest
            assert 'sub Main(' not in entry
            assert 'RunScreenSaver()' in entry and 'RunScreenSaverSettings()' in entry
            assert not any('ControllerScene' in n for n in names)
            assert 'artInit(true)' in z.read('components/ArtScene.brs').decode()
        else:
            assert 'screensaver_title=' not in manifest
            assert 'RunScreenSaver' not in entry
            assert 'components/ControllerScene.brs' in names
print('PASS reproducible packages, entry points and read-only screensaver boundary')
