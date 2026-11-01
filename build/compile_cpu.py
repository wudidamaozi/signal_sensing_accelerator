"""Rebuild frozen CPU-only firmware; verify binary identity before using it."""
from pathlib import Path
from hashlib import sha256
import argparse,subprocess,json
ROOT=Path(__file__).resolve().parents[1]

def main():
    p=argparse.ArgumentParser();p.add_argument('--task',choices=['classification','occupancy'],required=True);p.add_argument('--toolchain-bin',type=Path,required=True);p.add_argument('--output',type=Path,required=True);a=p.parse_args()
    src=ROOT/'src/firmware/cpu_only'/a.task;out=a.output.resolve();out.mkdir(parents=True,exist_ok=False)
    source=src/('firmware.c' if a.task=='classification' else 'occupancy_compare_cpu.c')
    flags=['-march=rv32im','-mabi=ilp32','-mno-div','-Os','-ffreestanding','-fno-builtin','-fno-stack-protector','-ffunction-sections','-fdata-sections','-msmall-data-limit=0','-Wall','-Wextra','-nostdlib','-nostartfiles','-Wl,--gc-sections','-Wl,--build-id=none']
    commands=[[str(a.toolchain_bin/'riscv-none-elf-gcc.exe'),*flags,'-T',str(src/'linker.ld'),'-I',str(src),str(source),'-lgcc','-o',str(out/'program.elf')],
              [str(a.toolchain_bin/'riscv-none-elf-objcopy.exe'),'-O','binary',str(out/'program.elf'),str(out/'program.bin')]]
    records=[]
    for label,cmd in zip(['compile','objcopy'],commands):
        r=subprocess.run(cmd,cwd=out,capture_output=True);(out/(label+'.stdout.log')).write_bytes(r.stdout);(out/(label+'.stderr.log')).write_bytes(r.stderr)
        records.append(dict(command=cmd,exit_status=r.returncode));assert r.returncode==0,(label,r.returncode)
    actual=(out/'program.bin').read_bytes();expected=(src/'program.bin').read_bytes();assert actual==expected,'Rebuilt firmware differs from archived board firmware'
    words=[int.from_bytes(actual[i:i+4].ljust(4,b'\0'),'little') for i in range(0,len(actual),4)]
    mem=ROOT/f'data/memory/{a.task}_cpu'/('full_network.hex' if a.task=='classification' else 'program.hex')
    assert words==[int(v,16) for v in mem.read_text().split()],'Firmware/memory initialization mismatch'
    (out/'program.hex').write_text(''.join(f'{v:08x}\n' for v in words),encoding='ascii')
    result=dict(status='PASS_CPU_FIRMWARE_IDENTITY',task=a.task,bytes=len(actual),sha256=sha256(actual).hexdigest(),commands=records,board_operated=False)
    (out/'summary.json').write_text(json.dumps(result,indent=2));print(json.dumps(result))
if __name__=='__main__':main()
