#!/usr/bin/env python3
"""Build a separate development AU. Do not install it or change the original."""
from pathlib import Path
import hashlib,json,plistlib,shutil,subprocess,os
from datetime import datetime,timezone
root=Path(__file__).resolve().parents[1]
subprocess.run(['cargo','build','--offline','--release','--manifest-path',str(root/'Cargo.toml')],check=True)
bundle=root/'target/LittleRadiator.component'
mac=bundle/'Contents/MacOS'; resources=bundle/'Contents/Resources'
mac.mkdir(parents=True,exist_ok=True);resources.mkdir(exist_ok=True)
assets=['WM_LITTLE_RADIATOR_BACKGROUND_IMAGE.png','WM_KNOB_ALTEC_LARGE.png','WM_ANIMATED_SWITCH_HALFSIZE_VERT.png']
source=root/'assets/interface'
for asset in assets: shutil.copyfile(source/asset,resources/asset)
shutil.copyfile(root/'assets/roundboys-faceplate-generated.png',resources/'RoundBoysFaceplate.png')
info={'CFBundleIdentifier':'dev.stanalysis.LittleRadiator','CFBundleExecutable':'LittleRadiator',
      'CFBundleName':'Little Radiator','CFBundlePackageType':'BNDL','CFBundleInfoDictionaryVersion':'6.0','CFBundleVersion':os.environ.get('ROUNDBOYS_BUILD_NUMBER','3'),'CFBundleShortVersionString':os.environ.get('ROUNDBOYS_VERSION','0.1.0'),
      'AudioComponents':[{'type':'aufx','subtype':'LrD1','manufacturer':'StDv','name':'RoundBoys: Little Radiator',
                          'description':'Little Radiator','factoryFunction':'LRDevFactory','version':65536,'sandboxSafe':True}]}
with (bundle/'Contents/Info.plist').open('wb') as stream: plistlib.dump(info,stream)
subprocess.run(['xcrun','clang++','-std=c++17','-fobjc-arc','-mmacosx-version-min=11.0','-bundle','-O2',str(root/'native/bridge.mm'),
                str(root/'target/release/liblittle_radiator.a'),'-framework','AudioToolbox','-framework','Cocoa','-framework','UniformTypeIdentifiers',
                '-framework','Security','-framework','SystemConfiguration','-o',str(mac/'LittleRadiator')],check=True)
subprocess.run(['codesign','--force','--sign','-',str(bundle)],check=True)
files=[root/'Cargo.toml',root/'native/bridge.mm',*sorted((root/'src').rglob('*.rs'))]
digest=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
record={'created_utc':datetime.now(timezone.utc).isoformat(),'binary_sha256':digest(mac/'LittleRadiator'),
        'sources':{str(p.relative_to(root)):digest(p) for p in files},
        'assets':{a:digest(resources/a) for a in assets+['RoundBoysFaceplate.png']},
        'note':'Original image assets stay local. The user confirms permission to reproduce the interface.'}
(root/'target/build-manifest.json').write_text(json.dumps(record,indent=2)+'\n')
print(bundle)
