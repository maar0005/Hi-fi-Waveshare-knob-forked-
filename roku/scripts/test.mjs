import { spawnSync } from 'node:child_process';
for (const files of [
  ['shared/components/SettingsScene.brs', 'shared/source/Settings.brs', 'shared/source/Model.brs', 'tests/discovery_ui.brs'],
  ['shared/source/Model.brs', 'shared/source/Discovery.brs', 'tests/discovery.brs'],
  ['shared/source/Model.brs', 'shared/source/Settings.brs', 'shared/source/LibraryModel.brs', 'shared/components/BridgeLibrary.brs', 'shared/components/BridgeTask.brs', 'tests/client.brs'],
  ['shared/source/Model.brs', 'shared/source/LibraryModel.brs', 'shared/components/BridgeLibrary.brs', 'shared/components/BridgeTask.brs', 'tests/library.brs'],
  ['shared/source/Model.brs', 'shared/source/LibraryModel.brs', 'controller/components/LibraryPanel.brs', 'tests/library_ui.brs'],
  ['shared/source/Model.brs', 'shared/components/ArtScene.brs', 'tests/art.brs'],
  ['controller/components/ControllerScene.brs', 'tests/remote.brs']
]) {
  const result = spawnSync(process.execPath, ['node_modules/brs/bin/cli.js', '--root', 'tests', ...files], {encoding: 'utf8'});
  process.stdout.write(result.stdout ?? '');
  process.stderr.write(result.stderr ?? '');
  if (result.status !== 0 || !result.stdout?.includes('PASS all') || result.stdout.includes('FAIL:')) process.exit(1);
}
const packages = spawnSync('python3', ['scripts/test_packages.py'], {stdio: 'inherit'});
process.exit(packages.status ?? 1);
