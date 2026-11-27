#!/usr/bin/env python3
"""Build the independent Little AlterBoy Audio Unit."""
from pathlib import Path
from datetime import datetime, timezone
import subprocess, shutil, plistlib, json, hashlib, os, re
root = Path(__file__).resolve().parents[1]
subprocess.run(['cargo', 'build', '--offline', '--release', '--manifest-path', str(root / 'Cargo.toml')], check=True)
bundle = root / 'target/LittleAlterBoy.component'
mac = bundle / 'Contents/MacOS'
resources = bundle / 'Contents/Resources'
mac.mkdir(parents=True, exist_ok=True)
resources.mkdir(exist_ok=True)
assets = ['LittleAlterBoy_BG_72dpi.png', 'MicroShiftKnobMovie_Medium_DD_1.png', 'PushButton_Red_20.png', 'GraySquareLEDButton32.png']
for name in assets:
    shutil.copyfile(root / 'assets/interface' / name, resources / name)
shutil.copyfile(root / 'assets/roundboys-faceplate-generated.png', resources / 'RoundBoysFaceplate.png')
names = [json.loads('"' + value + '"') for value in re.findall(r'name: "((?:[^"\\]|\\.)*)"', (root / 'src/factory_presets.rs').read_text())]
if len(names) != 12:
    raise ValueError('Unexpected factory preset table')
records = [{'index': index, 'name': name, 'category': ''} for index, name in enumerate(names)]
with (resources / 'FactoryPresets.plist').open('wb') as stream:
    plistlib.dump(records, stream)
info = {
    'CFBundleIdentifier': 'dev.roundboys.LittleAlterBoy',
    'CFBundleExecutable': 'LittleAlterBoy', 'CFBundleName': 'Little AlterBoy',
    'CFBundlePackageType': 'BNDL', 'CFBundleInfoDictionaryVersion': '6.0',
    'CFBundleVersion': os.environ.get('ROUNDBOYS_BUILD_NUMBER', '1'),
    'CFBundleShortVersionString': os.environ.get('ROUNDBOYS_VERSION', '0.1.0'),
    'AudioComponents': [{'type': 'aumf', 'subtype': 'Lab1', 'manufacturer': 'StDv',
                         'name': 'RoundBoys: Little AlterBoy', 'description': 'Little AlterBoy',
                         'factoryFunction': 'LABFactory', 'version': 65536, 'sandboxSafe': True}]
}
with (bundle / 'Contents/Info.plist').open('wb') as stream:
    plistlib.dump(info, stream)
command = ['xcrun', 'clang++', '-std=c++17', '-fobjc-arc', '-mmacosx-version-min=11.0', '-bundle', '-O2',
           str(root / 'native/bridge.mm'), str(root / 'native/editor.mm'), str(root / 'native/presets.mm'),
           str(root / 'target/release/liblittle_alter_boy.a'), '-framework', 'AudioToolbox', '-framework', 'Cocoa',
           '-framework', 'UniformTypeIdentifiers', '-framework', 'Security', '-framework', 'SystemConfiguration',
           '-o', str(mac / 'LittleAlterBoy')]
subprocess.run(command, check=True)
subprocess.run(['codesign', '--force', '--sign', '-', bundle], check=True)
def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()
files = [root / 'Cargo.toml', *sorted((root / 'src').rglob('*.rs')), *sorted((root / 'native').glob('*.mm')), *sorted((root / 'native').glob('*.h'))]
record = {'created_utc': datetime.now(timezone.utc).isoformat(), 'binary_sha256': sha(mac / 'LittleAlterBoy'),
          'sources': {str(path.relative_to(root)): sha(path) for path in files},
          'assets': {path.name: sha(path) for path in resources.iterdir() if path.is_file()}, 'command': command}
(root / 'target/build-manifest.json').write_text(json.dumps(record, indent=2) + '\n')
print(bundle)
