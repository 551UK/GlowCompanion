#!/usr/bin/env python3
"""Build a root-owned DEB with standard-library tar/ar support, then verify it."""
import gzip
import io
import pathlib
import plistlib
import struct
import tarfile

ROOT = pathlib.Path(__file__).resolve().parent
fields = dict(line.split(': ', 1) for line in (ROOT / 'control').read_text().splitlines())
assert fields['Architecture'] == 'iphoneos-arm64'
plist = plistlib.loads((ROOT / 'GlowIconPosition.plist').read_bytes())
assert plist == {'Filter': {'Bundles': ['com.apple.springboard']}}
def validate_macho(image_bytes):
    assert image_bytes[:4] == b'\xca\xfe\xba\xbe', 'Expected universal signed Mach-O'
    arch_count = struct.unpack_from('>I', image_bytes, 4)[0]
    arches = [struct.unpack_from('>IIIII', image_bytes, 8 + 20*i) for i in range(arch_count)]
    assert {(a[0], a[1] & 0xffffff) for a in arches} == {(0x100000c, 0), (0x100000c, 2)}
    for cpu, subtype, offset, size, align in arches:
        image = image_bytes[offset:offset + size]
        assert image[:4] == b'\xcf\xfa\xed\xfe'
        assert struct.unpack_from('<I', image, 12)[0] == 6  # MH_DYLIB
        ncmds = struct.unpack_from('<I', image, 16)[0]
        pos = 32
        signed = ios = False
        for _ in range(ncmds):
            cmd, cmdsize = struct.unpack_from('<II', image, pos)
            assert cmdsize >= 8
            if cmd == 0x1d:
                sigoff, sigsize = struct.unpack_from('<II', image, pos + 8)
                signed = sigsize > 0 and sigoff + sigsize <= len(image)
            if cmd == 0x32:
                ios = struct.unpack_from('<I', image, pos + 8)[0] == 2
            if cmd == 0x25:
                ios = True
            pos += cmdsize
        assert signed and ios, 'Each slice must be signed for iOS'

binary = (ROOT / 'build/GlowIconPosition.dylib').read_bytes()
prefs_binary = (ROOT / 'build/GlowIconPositionPrefs').read_bytes()
validate_macho(binary)
validate_macho(prefs_binary)


def tar_gz(entries, include_directories=False):
    stream = io.BytesIO()
    with tarfile.open(fileobj=stream, mode='w', format=tarfile.USTAR_FORMAT) as archive:
        if include_directories:
            directories = {'.'}
            for name, _, _ in entries:
                parent = pathlib.PurePosixPath(name).parent
                while str(parent) != '.':
                    directories.add('./' + str(parent))
                    parent = parent.parent
            for name in sorted(directories, key=lambda d: (d.count('/'), d)):
                item = tarfile.TarInfo(name + '/')
                item.type = tarfile.DIRTYPE
                item.mode = 0o755
                item.uid = item.gid = 0
                item.uname = item.gname = 'root'
                item.mtime = 0
                archive.addfile(item)
        for name, data, mode in entries:
            item = tarfile.TarInfo(name)
            item.size, item.mode = len(data), mode
            item.uid = item.gid = 0
            item.uname = item.gname = 'root'
            item.mtime = 0
            archive.addfile(item, io.BytesIO(data))
    return gzip.compress(stream.getvalue(), mtime=0)

control_entries = [('./control', (ROOT / 'control').read_bytes(), 0o644),
                   ('./postinst', (ROOT / 'postinst').read_bytes(), 0o755)]
control = tar_gz(control_entries)
base = './var/jb/Library/MobileSubstrate/DynamicLibraries/'
entries = [(base + 'GlowIconPosition.dylib', binary, 0o755),
           (base + 'GlowIconPosition.plist', (ROOT / 'GlowIconPosition.plist').read_bytes(), 0o644)]
bundle = './var/jb/Library/PreferenceBundles/GlowIconPositionPrefs.bundle/'
loader = './var/jb/Library/PreferenceLoader/Preferences/'
entries.append((bundle + 'GlowIconPositionPrefs', prefs_binary, 0o755))
for name in ['Info.plist', 'Root.plist']:
    content = (ROOT / 'prefs' / name).read_bytes()
    plistlib.loads(content)
    entries.append((bundle + name, content, 0o644))
entry_bytes = (ROOT / 'prefs/entry.plist').read_bytes()
entry = plistlib.loads(entry_bytes)['entry']
assert entry['bundle'] == 'GlowIconPositionPrefs'
assert entry['detail'] == plistlib.loads((ROOT / 'prefs/Info.plist').read_bytes())['NSPrincipalClass']
assert entry['icon'] == 'GlowIconPosition.png'
entries.append((loader + 'GlowIconPosition.plist', entry_bytes, 0o644))
for scale, suffix in [(1, ''), (2, '@2x'), (3, '@3x')]:
    icon = (ROOT / 'prefs/icons' / f'icon{suffix}.png').read_bytes()
    assert icon[:8] == b'\x89PNG\r\n\x1a\n'
    assert struct.unpack_from('>II', icon, 16) == (29 * scale, 29 * scale)
    # Support loaders that resolve icons beside the entry plist or in the bundle.
    entries.extend([(loader + f'GlowIconPosition{suffix}.png', icon, 0o644),
                    (bundle + f'GlowIconPosition{suffix}.png', icon, 0o644),
                    (bundle + f'icon{suffix}.png', icon, 0o644)])
assert len({e[0] for e in entries}) == len(entries)
data = tar_gz(entries, include_directories=True)
out = bytearray(b'!<arch>\n')
for name, body in [('debian-binary', b'2.0\n'), ('control.tar.gz', control), ('data.tar.gz', data)]:
    header = f'{name + "/":<16}{0:<12}{0:<6}{0:<6}{"100644":<8}{len(body):<10}`\n'.encode('ascii')
    assert len(header) == 60
    out.extend(header + body)
    if len(body) % 2:
        out.extend(b'\n')
path = ROOT / 'packages' / f'{fields["Package"]}_{fields["Version"]}_{fields["Architecture"]}.deb'
path.parent.mkdir(exist_ok=True)
path.write_bytes(out)
# Confirm payload inventory and byte identity; never ship the supplied Glow DEB.
with tarfile.open(fileobj=io.BytesIO(data), mode='r:gz') as archive:
    assert [m.name for m in archive.getmembers() if m.isfile()] == [e[0] for e in entries]
    members = {m.name: m for m in archive.getmembers()}
    for name, _, _ in entries:
        parent = pathlib.PurePosixPath(name).parent
        while str(parent) != '.':
            directory = members['./' + str(parent)]
            assert directory.isdir() and directory.mode == 0o755
            assert directory.uid == directory.gid == 0
            parent = parent.parent
    for name, content, mode in entries:
        item = archive.getmember(name)
        assert item.uid == item.gid == 0 and item.mode == mode
        assert archive.extractfile(item).read() == content
print(f'Validated DEB: {path.name} ({path.stat().st_size} bytes)')

with tarfile.open(fileobj=io.BytesIO(control), mode='r:gz') as archive:
    assert archive.getmember('./postinst').mode == 0o755
    assert archive.extractfile('./postinst').read() == (ROOT / 'postinst').read_bytes()
