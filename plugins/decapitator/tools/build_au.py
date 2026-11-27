#!/usr/bin/env python3
"""Build a separate AU from our Rust model and local interface assets."""
from pathlib import Path
from datetime import datetime,timezone
import subprocess,shutil,plistlib,json,hashlib,re,os
root=Path(__file__).resolve().parents[1]
subprocess.run(['cargo','build','--release','--offline','--manifest-path',str(root/'Cargo.toml')],check=True)
bundle=root/'target/Decapitator.component';mac=bundle/'Contents/MacOS';resources=bundle/'Contents/Resources'
mac.mkdir(parents=True,exist_ok=True);resources.mkdir(exist_ok=True)
assets=['DecapitatorBackground_2x.png','WM_KNOB_PULTEC_95.png','WM_KNOB_PULTEC_64.png','WM_LIGHTEDPUSHBUTTON_50.png','WM_ANIMATED_SWITCH_HALFSIZE_VERT.png','WM_DECAPITATOR_METER.jpg']
for name in assets:shutil.copyfile(root/'assets/interface'/name,resources/name)
shutil.copyfile(root/'assets/roundboys-faceplate-generated.png',resources/'RoundBoysFaceplate.png')
records=[]
names=[json.loads('"'+name+'"')for name in re.findall(r'name: "((?:[^"\\]|\\.)*)"',(root/'src/factory_presets.rs').read_text())]
categories=json.loads((root/'factory-categories.json').read_text())
if len(names)!=47:raise ValueError('Unexpected factory preset table')
for index,name in enumerate(names):
    category=categories[name]
    records.append({'index':index,'name':name,'category':category})
with(resources/'FactoryPresets.plist').open('wb')as f:plistlib.dump(records,f)
info={'CFBundleIdentifier' :'dev.stanalysis.Decapitator','CFBundleExecutable':'Decapitator','CFBundleName':'Decapitator',
'CFBundlePackageType':'BNDL','CFBundleInfoDictionaryVersion':'6.0','CFBundleVersion':os.environ.get('ROUNDBOYS_BUILD_NUMBER','3'),'CFBundleShortVersionString':os.environ.get('ROUNDBOYS_VERSION','0.1.0'),
'AudioComponents':[{'type':'aufx','subtype':'Dcp1','manufacturer':'StDv','name':'RoundBoys: Decapitator','description':'Decapitator',
                    'factoryFunction':'DCDevFactory','version':65536,'sandboxSafe':True}]}
with(bundle/'Contents/Info.plist').open('wb')as f:plistlib.dump(info,f)
command=['xcrun','clang++','-std=c++17','-fobjc-arc','-mmacosx-version-min=11.0','-bundle','-O2',str(root/'native/bridge.mm'),str(root/'native/editor.mm'),str(root/'native/presets.mm'),
str(root/'target/release/libdecapitator.a'),'-framework','AudioToolbox','-framework','Cocoa','-framework','UniformTypeIdentifiers','-framework','Security','-framework','SystemConfiguration','-o',str(mac/'Decapitator')]
subprocess.run(command,check=True);subprocess.run(['codesign','--force','--sign','-',str(bundle)],check=True)
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
files=[root/'Cargo.toml',*sorted((root/'src').rglob('*.rs')),*sorted((root/'native').glob('*.mm')),*sorted((root/'native').glob('*.h'))]
record={'created_utc':datetime.now(timezone.utc).isoformat(),'binary_sha256':sha(mac/'Decapitator'),'sources':{str(p.relative_to(root)):sha(p)for p in files},'assets':{p.name:sha(p)for p in resources.iterdir()if p.is_file()},'command':command}
(root/'target/build-manifest.json').write_text(json.dumps(record,indent=2)+'\n');print(bundle)
