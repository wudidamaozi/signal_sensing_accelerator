"""Portable PYNQ checks. File-only by default; no import-time device access."""
from pathlib import Path
import argparse
import hashlib
import json
import re


def sha256(path):
    h = hashlib.sha256()
    with Path(path).open('rb') as stream:
        for chunk in iter(lambda: stream.read(1048576), b''):
            h.update(chunk)
    return h.hexdigest()


def check_files(root, record):
    root = Path(root).resolve()
    pair = []
    for suffix in ('bit', 'hwh'):
        relative = Path(record[suffix])
        path = (root / relative).resolve()
        if relative.is_absolute() or not path.is_relative_to(root) or path.suffix != '.' + suffix:
            raise ValueError('Invalid overlay path')
        expected = record[suffix + '_sha256']
        if not isinstance(expected, str) or not re.fullmatch('[0-9a-fA-F]{64}', expected):
            raise ValueError('Actual SHA256 required')
        if sha256(path) != expected.lower():
            raise ValueError('Overlay SHA256 mismatch')
        pair.append(path)
    if pair[0].stem != pair[1].stem or pair[0].parent != pair[1].parent:
        raise ValueError('Matching .bit/.hwh pair required')
    for field in ('base_address', 'address_range'):
        if type(record[field]) is not int or record[field] < 0 or record[field] % 4:
            raise ValueError('Aligned integer map required')
    if record['address_range'] < 4 or not isinstance(record['ip_name'], str) or not record['ip_name']:
        raise ValueError('Explicit IP and nonempty window required')
    return pair[0]


def checked_overlay(root, record, overlay_class=None, program=False):
    bit = check_files(root, record)
    if overlay_class is None:
        from pynq import Overlay
        overlay_class = Overlay
    overlay = overlay_class(str(bit), download=False)
    info = overlay.ip_dict.get(record['ip_name'])
    if info is None or int(info['phys_addr']) != record['base_address'] or int(info['addr_range']) != record['address_range']:
        raise ValueError('HWH map differs from manifest')
    if program:
        overlay.download()
    return overlay


class BoundedMMIO:
    def __init__(self, base, size, mmio_class=None):
        if type(base) is not int or base < 0 or base % 4 or type(size) is not int or size < 4 or size % 4:
            raise ValueError('Aligned base and positive word-sized range required')
        if mmio_class is None:
            from pynq import MMIO
            mmio_class = MMIO
        self.size = size
        self.mmio = mmio_class(base, size)

    def _offset(self, offset):
        if type(offset) is not int or offset < 0 or offset % 4 or offset + 4 > self.size:
            raise ValueError('Unaligned or out-of-range MMIO')

    def read32(self, offset):
        self._offset(offset)
        return int(self.mmio.read(offset)) & 0xffffffff

    def write32(self, offset, value):
        self._offset(offset)
        if type(value) is not int or not 0 <= value <= 0xffffffff:
            raise ValueError('Expected uint32')
        self.mmio.write(offset, value)


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--root', type=Path, required=True)
    p.add_argument('--manifest', type=Path, required=True)
    p.add_argument('--inspect-hwh', action='store_true')
    p.add_argument('--program', action='store_true')
    a = p.parse_args()
    record = json.loads(a.manifest.read_text(encoding='utf-8-sig'))
    check_files(a.root, record)
    status = 'PASS_FILES_ONLY'
    if a.inspect_hwh or a.program:
        checked_overlay(a.root, record, program=a.program)
        status = 'PASS_PROGRAMMED' if a.program else 'PASS_HWH_NO_DOWNLOAD'
    print(json.dumps({'status': status, 'board_programmed': a.program}))


if __name__ == '__main__':
    main()
