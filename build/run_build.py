"""Rebuild one complete PL design using the preserved Vivado recipe; does not program FPGA."""
from pathlib import Path
import argparse,json,re,subprocess
ROOT=Path(__file__).resolve().parents[1]
def main():
    p=argparse.ArgumentParser();p.add_argument('--variant',required=True);p.add_argument('--vivado-bin',type=Path,required=True);a=p.parse_args()
    v=json.loads((ROOT/'build/variants.json').read_text(encoding='utf-8'))[a.variant];out=ROOT/'build/output'/a.variant;out.mkdir(parents=True,exist_ok=False);src=out/'prepared_sources';src.mkdir()
    text=(ROOT/f'build/scripts/{a.variant}.tcl').read_text(encoding='utf-8')
    text=text.replace('set root [file normalize [file join [file dirname [info script]] ../..]]','set root {'+ROOT.as_posix()+'}')
    for rel in v['sources']:
        if rel in v['tb_sources']:continue
        f=ROOT/rel;target=src/f.name;target.write_text(f.read_text(encoding='utf-8').replace('"data/memory/','"'+ROOT.as_posix()+'/data/memory/'),encoding='utf-8');text=text.replace('[file join $root '+rel+']','{'+target.as_posix()+'}')
    (out/'run.tcl').write_text(text,encoding='utf-8')
    cmd=[str(a.vivado_bin/'vivado.bat'),'-mode','batch','-source',str(out/'run.tcl')];r=subprocess.run(['cmd.exe','/d','/s','/c',subprocess.list2cmdline(cmd)],cwd=ROOT,capture_output=True);(out/'stdout.log').write_bytes(r.stdout);(out/'stderr.log').write_bytes(r.stderr)
    if r.returncode:raise RuntimeError('Vivado failed; inspect '+str(out))
    assert (out/'board.bit').is_file(),'No bitstream produced'
    print('BUILD_COMPLETE_NO_BOARD',out)
if __name__=='__main__':main()
