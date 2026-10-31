"""Offline package acceptance: hashes, independent integer reference and reusable skills."""
from pathlib import Path
import argparse,hashlib,json,subprocess,sys,xml.etree.ElementTree as ET
import numpy as np
ROOT=Path(__file__).resolve().parents[1];sys.path.insert(0,str(ROOT/'src/software'))
def main():
    p=argparse.ArgumentParser();p.add_argument('--output',type=Path,required=True);a=p.parse_args();out=a.output.resolve();out.mkdir(parents=True,exist_ok=False)
    manifest=json.loads((ROOT/'report/file_manifest.json').read_text(encoding='utf-8'))
    for rel,h in manifest.items():assert hashlib.sha256((ROOT/rel).read_bytes()).hexdigest()==h,rel
    from scripts.run_dual_fpga_hls4ml import service
    from scripts.board_performance_hls4ml import load_board_comparison
    report=service.report();bench=load_board_comparison();assert bench['occupancy'][0]['cycles']==[35629]*2
    assert service.datasets['classification']['iq'].shape==(80,2,128) and service.datasets['occupancy']['iq'].shape==(195,2,128)
    count=0
    for f in sorted((ROOT/'data/golden/occupancy').glob('*.npz')):
        with np.load(f,allow_pickle=False) as z:actual=service.detector.logits(z['prepared_float_raw']);assert np.array_equal(actual,z['logits']),f.name
        count+=1
    assert count==30
    for task in ['classification','occupancy']:
        result=service.sample(task,0,8,backend='software');assert len(result['integer_logits'])==(4 if task=='classification' else 2)
    ET.parse(ROOT/'report/figures/hardware_architecture.svg')
    tests=[]
    for folder,expected in [('edge-int8-validation',14),('pynq-overlay-preflight',13)]:
        cmd=[sys.executable,'-X','utf8',str(ROOT/'skill'/folder/'scripts/self_test.py')];r=subprocess.run(cmd,cwd=out,capture_output=True);(out/(folder+'.stdout.log')).write_bytes(r.stdout);(out/(folder+'.stderr.log')).write_bytes(r.stderr);assert r.returncode==0,(folder,r.stderr.decode('utf-8'));tests.append(dict(skill=folder,exit_status=0,cases=expected))
    result=dict(status='PASS_OFFLINE_CLEAN_PACKAGE',manifest_files=len(manifest),occupancy_golden_inputs=count,skills=tests,model_hashes=service.model_hashes,comparison=bench,board_operated=False)
    (out/'summary.json').write_text(json.dumps(result,ensure_ascii=False,indent=2)+'\n',encoding='utf-8');print('CLEAN_PACKAGE_SMOKE_PASS',len(manifest),'files',count,'golden inputs','27 skill tests')
if __name__=='__main__':main()
