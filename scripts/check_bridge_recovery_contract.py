#!/usr/bin/env python3
"""Keep #284 recovery and network lifecycle shared by every ESP controller."""
from pathlib import Path

root = Path(__file__).resolve().parent.parent
for target in ('idf_app', 'frame_app', 'rlcd_app', 'atom_app', 'tough_app', 'm5_beta_app', 'halo_app'):
    cmake = (root / target / 'main/CMakeLists.txt').read_text()
    for source in ('bridge_client.c', 'wifi_manager.c', 'platform/platform_bridge_cache_esp.c'):
        assert cmake.count(f'"../../common/{source}"') == 1, (target, source)
    for path in (root / target / 'main').glob('*'):
        if path.suffix in ('.c', '.cpp', '.cc'):
            assert 'bridge_client_set_network_ready(' not in path.read_text(), path
workflow = (root / '.github/workflows/docker.yml').read_text()
for check in ('scripts/test_connection_runtime.sh', 'tests/run_wifi_provisioning_lifecycle.sh',
              'scripts/test_bridge_cache.sh', 'scripts/check_bridge_recovery_contract.py'):
    assert check in workflow, f'Missing required CI guard: {check}'
print('Shared bridge recovery contract passed for all seven controller builds / ten targets')
