"""Compile and run one frozen variant after resolving memory paths in generated copies."""
from pathlib import Path
import argparse,json,subprocess,sys
ROOT=Path(__file__).resolve().parents[1]
def run(cmd,cwd,label):
    actual=['cmd.exe','/d','/s','/c',subprocess.list2cmdline(list(map(str,cmd)))] if str(cmd[0]).endswith('.bat') else list(map(str,cmd))
    r=subprocess.run(actual,cwd=cwd,capture_output=True);(cwd/(label+'.stdout.log')).write_bytes(r.stdout);(cwd/(label+'.stderr.log')).write_bytes(r.stderr)
    with (cwd/'commands.jsonl').open('a',encoding='utf-8') as f:f.write(json.dumps(dict(command=list(map(str,cmd)),exit_status=r.returncode,stdout=label+'.stdout.log',stderr=label+'.stderr.log'))+'\n')
    if r.returncode:raise RuntimeError(f'{label} failed; inspect {cwd}')
    return r.stdout.decode('utf-8',errors='replace')
def main():
    p=argparse.ArgumentParser();p.add_argument('--variant',required=True);p.add_argument('--vivado-bin',type=Path,required=True);p.add_argument('--output',type=Path,required=True);a=p.parse_args()
    records=json.loads((ROOT/'build/variants.json').read_text(encoding='utf-8'));v=records[a.variant];out=a.output.resolve();out.mkdir(parents=True,exist_ok=False);src=out/'sources';src.mkdir();files=[]
    for rel in v['sources']:
        f=ROOT/rel;data=f.read_text(encoding='utf-8').replace('"data/memory/','"'+ROOT.as_posix()+'/data/memory/');target=src/f.name;target.write_text(data,encoding='utf-8');files.append(target)
    prj=''.join(f'{"sv" if f.suffix==".sv" else "verilog"} work "{f.as_posix()}"\n' for f in files)
    prj+=f'verilog work "{(a.vivado_bin.parent/"data/verilog/src/glbl.v").as_posix()}"\n';(out/'sources.prj').write_text(prj,encoding='ascii')
    run([a.vivado_bin/'xvlog.bat','-prj','sources.prj'],out,'compile');run([a.vivado_bin/'xelab.bat',v['testbench'],'glbl','-L','unisims_ver','-timescale','1ns/1ps','-s','submission_sim'],out,'elaborate');(out/'run.tcl').write_text('run all\nexit\n')
    log=run([a.vivado_bin/'xsim.bat','submission_sim','-tclbatch','run.tcl'],out,'simulation')
    assert v['pass_marker'] in log and not any(x in log for x in ['Fatal:','ERROR:','cannot be opened for reading'])
    (out/'summary.json').write_text(json.dumps(dict(status='PASS_RELOCATED_XSIM',variant=a.variant,marker=v['pass_marker']),indent=2)+'\n');print('RELOCATED_XSIM_PASS',a.variant)
if __name__=='__main__':main()
