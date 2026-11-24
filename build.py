"""Build the Magisk ZIP from unmodified firmware files on the host."""

import argparse
import hashlib
import io
import json
import subprocess
import tempfile
from pathlib import Path, PurePosixPath
from zipfile import ZIP_DEFLATED, ZipFile, ZipInfo


ROOT = Path(__file__).resolve().parent
SUPPORTED_BUILD = 'PJD110_16.0.2.400(CN01)'
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


def patch_specs():
    return json.loads((ROOT / 'patches.json').read_text(encoding='utf-8'))


def build(stock):
    specs = patch_specs()
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


def build_from_phone(serial):
    adb = ['adb', '-s', serial] if serial else ['adb']

    def run(*args):
        result = subprocess.run([*adb, *args], capture_output=True, text=True, timeout=60)
        if result.returncode:
            detail = result.stderr.strip() or result.stdout.strip()
            raise ValueError(f'adb {args[0]} failed: {detail}')
        return result.stdout.strip()

    model = run('shell', 'getprop', 'ro.product.model')
    display_id = run('shell', 'getprop', 'ro.build.display.id')
    if (model, display_id) != ('PJD110', SUPPORTED_BUILD):
        raise ValueError(f'Expected PJD110 on {SUPPORTED_BUILD}, got {model!r} on {display_id!r}')

    scratch = ROOT / '.tmp'
    scratch.mkdir(exist_ok=True)
    with tempfile.TemporaryDirectory(prefix='adb-stock-', dir=scratch) as directory:
        stock = Path(directory)
        for spec in patch_specs().values():
            source = PurePosixPath(spec['device_path'])
            print(f'Reading /{source}', flush=True)
            run('pull', f'/{source}', str(stock / source.name))
        return build(stock)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    source = parser.add_mutually_exclusive_group(required=True)
    source.add_argument('--stock', type=Path, help='Directory of stock files')
    source.add_argument('--from-phone', action='store_true', help='Read stock files over ADB')
    parser.add_argument('--serial', help='ADB serial number when using --from-phone')
    parser.add_argument('--output', type=Path, default=Path('dist/PJD110-Camera-Unified-v5.zip'),
                        help='Path for the new ZIP (default: %(default)s)')
    args = parser.parse_args()
    if args.serial and not args.from_phone:
        parser.error('--serial requires --from-phone')
    try:
        if args.output.exists():
            raise FileExistsError(f'{args.output} already exists. Choose another --output path.')
        data = build_from_phone(args.serial) if args.from_phone else build(args.stock)
        args.output.parent.mkdir(parents=True, exist_ok=True)
        with args.output.open('xb') as target:
            target.write(data)
    except FileNotFoundError as err:
        if err.filename == 'adb':
            parser.exit(1, 'Build failed: Install Android SDK Platform-Tools and add adb to PATH.\n')
        parser.exit(1, f'Build failed: {err}\n')
    except subprocess.TimeoutExpired:
        parser.exit(1, 'Build failed: ADB timed out. Check the USB connection and authorization.\n')
    except (OSError, ValueError) as err:
        parser.exit(1, f'Build failed: {err}\n')
    print(f'{sha256(data)}  {args.output}')


if __name__ == '__main__':
    main()
