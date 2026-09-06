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
plist = plistlib.loads((ROOT / 'GlowCompanion.plist').read_bytes())
assert plist == {'Filter': {'Bundles': ['com.apple.springboard']}}
binary = (ROOT / 'build/GlowCompanion.dylib').read_bytes()
assert binary[:4] == b'\xca\xfe\xba\xbe', 'Expected universal signed Mach-O'
arch_count = struct.unpack_from('>I', binary, 4)[0]
arches = [struct.unpack_from('>IIIII', binary, 8 + 20*i) for i in range(arch_count)]
assert {(a[0], a[1] & 0xffffff) for a in arches} == {(0x100000c, 0), (0x100000c, 2)}
for cpu, subtype, offset, size, align in arches:
    image = binary[offset:offset + size]
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


def tar_gz(entries):
    stream = io.BytesIO()
    with tarfile.open(fileobj=stream, mode='w', format=tarfile.USTAR_FORMAT) as archive:
        for name, data, mode in entries:
            item = tarfile.TarInfo(name)
            item.size, item.mode = len(data), mode
            item.uid = item.gid = 0
            item.uname = item.gname = 'root'
            item.mtime = 0
            archive.addfile(item, io.BytesIO(data))
    return gzip.compress(stream.getvalue(), mtime=0)

control = tar_gz([('./control', (ROOT / 'control').read_bytes(), 0o644)])
base = './var/jb/Library/MobileSubstrate/DynamicLibraries/'
entries = [(base + 'GlowCompanion.dylib', binary, 0o755),
           (base + 'GlowCompanion.plist', (ROOT / 'GlowCompanion.plist').read_bytes(), 0o644)]
data = tar_gz(entries)
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
    assert archive.getnames() == [e[0] for e in entries]
    for name, content, mode in entries:
        item = archive.getmember(name)
        assert item.uid == item.gid == 0 and item.mode == mode
        assert archive.extractfile(item).read() == content
print(f'Validated DEB: {path.name} ({path.stat().st_size} bytes)')
