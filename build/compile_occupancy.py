"""Recompile the selected occupancy firmware and require exact binary identity."""
from pathlib import Path
import argparse,hashlib,json,os,subprocess
ROOT=Path(__file__).resolve().parents[1]
def main():
    p=argparse.ArgumentParser();p.add_argument('--toolchain-prefix',required=True);p.add_argument('--output',type=Path,required=True);a=p.parse_args();out=a.output.resolve();out.mkdir(parents=True,exist_ok=False);src=ROOT/'src/firmware/occupancy';identity=json.loads((src/'build_identity.json').read_text(encoding='utf-8'));suffix='.exe' if os.name=='nt' else ''
    gcc=a.toolchain_prefix+'gcc'+suffix;objcopy=a.toolchain_prefix+'objcopy'+suffix
    cmd=[gcc,*identity['compiler_flags'],'-Wall','-Wextra','-nostdlib','-nostartfiles','-Wl,--gc-sections','-Wl,--build-id=none','-T',str(src/'linker.ld'),'-I',str(src),str(src/'firmware.c'),'-lgcc','-o',str(out/'program.elf')]
    for name,command in [('gcc',cmd),('objcopy',[objcopy,'-O','binary',str(out/'program.elf'),str(out/'program.bin')])]:
        r=subprocess.run(command,capture_output=True);(out/(name+'.stdout.log')).write_bytes(r.stdout);(out/(name+'.stderr.log')).write_bytes(r.stderr);assert r.returncode==0,name
    h=hashlib.sha256((out/'program.bin').read_bytes()).hexdigest();assert h==identity['firmware_sha256'];print('FIRMWARE_EXACT_PASS',h)
if __name__=='__main__':main()
