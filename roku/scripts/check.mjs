import { ProgramBuilder } from 'brighterscript';
import { resolve } from 'node:path';
import { spawnSync } from 'node:child_process';
for (const profile of ['controller', 'screensaver']) {
  const stage = resolve('.out', profile);
  const stageResult = spawnSync('python3', ['scripts/package.py', '--stage-only', profile], {stdio: 'inherit'});
  if (stageResult.status !== 0) process.exit(stageResult.status ?? 1);
  const builder = new ProgramBuilder();
  await builder.run({rootDir: stage, files: ['source/**/*', 'components/**/*', 'manifest'], createPackage: false, copyToStaging: false, diagnosticFilters: [], logLevel: 'warn'});
  const errors = builder.getDiagnostics().filter(d => d.severity === 1);
  if (errors.length) process.exit(1);
  console.log(`${profile}: BrightScript and SceneGraph validation passed`);
}
