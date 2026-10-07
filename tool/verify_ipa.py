"""Validate install-critical host and extension metadata before handing off an IPA."""
import argparse
import json
import plistlib
import zipfile

parser = argparse.ArgumentParser()
parser.add_argument('ipa')
parser.add_argument('version')
parser.add_argument('build')
args = parser.parse_args()
with zipfile.ZipFile(args.ipa) as archive:
    assert archive.testzip() is None, 'Corrupt archive'
    host_path = 'Payload/Runner.app/'
    widget_path = host_path + 'PlugIns/ScooterLockWidget.appex/'
    bundles = []
    for path in [host_path, widget_path]:
        info = plistlib.loads(archive.read(path + 'Info.plist'))
        for key in ['CFBundleName', 'CFBundleExecutable', 'CFBundleIdentifier']:
            value = info.get(key)
            assert isinstance(value, str) and value.strip() and '$(' not in value, (path, key, value)
        assert info['CFBundleShortVersionString'] == args.version, (path, 'version')
        assert info['CFBundleVersion'] == args.build, (path, 'build')
        assert path + info['CFBundleExecutable'] in archive.namelist(), (path, 'executable')
        metadata = json.loads(archive.read(path + 'Metadata.appintents/extract.actionsdata'))
        assert metadata['actions']['ToggleScooterLockIntent']['openAppWhenRun'] is False
        bundles.append(info)
    host, widget = bundles
    assert widget['CFBundleIdentifier'].startswith(host['CFBundleIdentifier'] + '.')
    assert widget['NSExtension']['NSExtensionPointIdentifier'] == 'com.apple.widgetkit-extension'
print('PASS: IPA integrity, required bundle keys, executable paths, versions, widget and intent metadata')
