#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p build/SettingsSmoke.app
sim_sdk="$(xcrun --sdk iphonesimulator --show-sdk-path)"
sim_arch="$(uname -m)"
xcrun --sdk iphonesimulator clang -isysroot "$sim_sdk" \
  -target "${sim_arch}-apple-ios15.0-simulator" -fobjc-arc -fblocks -Wall -Wextra -Werror \
  -framework Foundation -framework UIKit -framework CoreFoundation \
  tests/SettingsSmoke.m -o build/SettingsSmoke.app/SettingsSmoke
python3 - <<'PY'
import plistlib
from pathlib import Path
p=Path('build/SettingsSmoke.app/Info.plist')
p.write_bytes(plistlib.dumps({'CFBundleIdentifier':'com.551.glowiconposition.smoke','CFBundleExecutable':'SettingsSmoke','CFBundleName':'SettingsSmoke','CFBundlePackageType':'APPL','CFBundleVersion':'1','CFBundleShortVersionString':'1.0','LSRequiresIPhoneOS':True,'UIDeviceFamily':[1],'UILaunchScreen':{}}))
PY
codesign --force --sign - build/SettingsSmoke.app
xcrun simctl list devices available --json > build/simulators.json
sim_id="$(python3 - <<'PY'
import json
j=json.load(open('build/simulators.json'))
phones=[d for runtime,devices in j['devices'].items() if 'iOS' in runtime for d in devices if d['isAvailable'] and 'iPhone' in d['name']]
assert phones, 'No available iPhone simulator runtime'
phones.sort(key=lambda d: (d['state']!='Booted', d['name']))
print(phones[0]['udid'])
PY
)"
xcrun simctl boot "$sim_id" 2>/dev/null || true
xcrun simctl bootstatus "$sim_id" -b
xcrun simctl install "$sim_id" build/SettingsSmoke.app
xcrun simctl launch "$sim_id" com.551.glowiconposition.smoke
container="$(xcrun simctl get_app_container "$sim_id" com.551.glowiconposition.smoke data)"
for attempt in {1..30}; do
  if [ -f "$container/Documents/settings-smoke.txt" ]; then break; fi
  sleep 1
done
cp "$container/Documents/settings-smoke.txt" build/settings-smoke.txt
cat build/settings-smoke.txt
grep -q '^PASS:' build/settings-smoke.txt
xcrun simctl io "$sim_id" screenshot build/settings-preview.png
