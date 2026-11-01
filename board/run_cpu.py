"""Explicit volatile USB/JTAG programming of a frozen CPU-only benchmark."""
from pathlib import Path
from hashlib import sha256
import argparse,json,subprocess,os,re
ROOT=Path(__file__).resolve().parents[1]

def main():
    p=argparse.ArgumentParser();p.add_argument('--task',choices=['classification','occupancy'],required=True);p.add_argument('--program',action='store_true',required=True);p.add_argument('--output',type=Path,required=True);p.add_argument('--vivado-bin',type=Path);a=p.parse_args()
    tools=a.vivado_bin or Path(os.environ['EDGEAI_VIVADO_BIN']);variant=a.task+'_cpu';assets=ROOT/'board/benchmarks'/variant
    meta=json.loads((ROOT/f'report/evidence/{variant}/board.json').read_text(encoding='utf8'))
    for name,key in [('board.bit','bit_sha256'),('debug.ltx','ltx_sha256')]:assert sha256((assets/name).read_bytes()).hexdigest()==meta[key]
    out=a.output.resolve();out.mkdir(parents=True,exist_ok=False)
    cmd=[str(tools/'vivado.bat'),'-mode','batch','-source',str(ROOT/f'board/program_{variant}.tcl'),'-tclargs',str(assets)]
    r=subprocess.run(['cmd.exe','/d','/s','/c',subprocess.list2cmdline(cmd)],cwd=out,capture_output=True)
    (out/'stdout.log').write_bytes(r.stdout);(out/'stderr.log').write_bytes(r.stderr)
    (out/'command.json').write_text(json.dumps(dict(command=cmd,exit_status=r.returncode),indent=2));assert r.returncode==0,'Vivado failed; inspect output logs'
    rows=re.findall(r'^CPU_BOARD_PASS run=(\d+) cycles0=(\d+) cycles1=(\d+) no_flash$',r.stdout.decode('utf8',errors='replace').replace('\r\n','\n'),re.M)
    cycles=[int(v) for row in rows for v in row[1:]];assert len(rows)==2 and cycles==meta['cycles'],'Board cycles do not match frozen benchmark'
    result=dict(status='CPU_ONLY_BOARD_PASS',task=a.task,cycles=cycles,board_measured=True,bit_sha256=meta['bit_sha256'],model_sha256=meta['model_sha256'],programmed_volatile_only=True)
    (out/'summary.json').write_text(json.dumps(result,indent=2));print(json.dumps(result))
if __name__=='__main__':main()
