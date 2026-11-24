"""Build the Magisk ZIP from unmodified firmware files on the host."""

import argparse
import hashlib
import io
import json
from pathlib import Path, PurePosixPath
from zipfile import ZIP_DEFLATED, ZipFile, ZipInfo


ROOT = Path(__file__).resolve().parent
MODULE_FILES = (
    'check-map.awk', 'customize.sh', 'module.prop',
    'post-fs-data.sh', 'service.sh', 'skip_mount',
)


def sha256(data):
    return hashlib.sha256(data).hexdigest()


def patch_file(stock, name, spec):
    original = (stock / PurePosixPath(spec['device_path']).name).read_bytes()
    if sha256(original) != spec['stock_sha256']:
        raise ValueError(f'{name}: stock checksum does not match')

    result = bytearray()
    cursor = 0
    for edit in spec['edits']:
        offset = edit['offset']
        before = bytes.fromhex(edit['before'])
        end = offset + len(before)
        if not cursor <= offset <= end <= len(original) or original[offset:end] != before:
            raise ValueError(f'{name}: unexpected bytes at offset {offset}')
        result.extend(original[cursor:offset])
        result.extend(bytes.fromhex(edit['after']))
        cursor = end
    result.extend(original[cursor:])
    if sha256(result) != spec['patched_sha256']:
        raise ValueError(f'{name}: patched checksum does not match')
    return bytes(result)


def build(stock):
    specs = json.loads((ROOT / 'patches.json').read_text(encoding='utf-8'))
    files = {name: (ROOT / 'module' / name).read_bytes() for name in MODULE_FILES}
    files.update((name, patch_file(stock, name, spec)) for name, spec in specs.items())
    files['contents.sha256'] = ''.join(
        f'{sha256(data)}  {name}\n' for name, data in sorted(files.items()) if name != 'customize.sh'
    ).encode('ascii')
    output = io.BytesIO()
    with ZipFile(output, 'w') as archive:
        for name, data in sorted(files.items()):
            info = ZipInfo(name)
            info.compress_type = ZIP_DEFLATED
            info.external_attr = (0o100755 if name.endswith('.sh') else 0o100644) << 16
            archive.writestr(info, data)
    return output.getvalue()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--stock', type=Path, required=True, help='Directory of stock files')
    parser.add_argument('--output', type=Path, required=True, help='Path for the new ZIP')
    args = parser.parse_args()
    try:
        data = build(args.stock)
        args.output.parent.mkdir(parents=True, exist_ok=True)
        with args.output.open('xb') as target:
            target.write(data)
    except (OSError, ValueError) as err:
        parser.exit(1, f'Build failed: {err}\n')
    print(f'{sha256(data)}  {args.output}')


if __name__ == '__main__':
    main()
