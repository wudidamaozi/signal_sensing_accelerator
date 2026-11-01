"""Recompute every frozen classification test frame in software, not on FPGA."""
from pathlib import Path
import argparse,json,sys
ROOT=Path(__file__).resolve().parents[1];sys.path.insert(0,str(ROOT/'src/software'))

def main():
    p=argparse.ArgumentParser();p.add_argument('--output',type=Path,required=True);a=p.parse_args();out=a.output.resolve();out.mkdir(parents=True,exist_ok=False)
    from scripts import run_dual_fpga_hls4ml as app
    app.evaluate_full_test();state=app.eval_state
    (out/'result.json').write_text(json.dumps(state,ensure_ascii=False,indent=2),encoding='utf8')
    assert state['phase']=='complete',state
    r=state['result'];assert r['count']==11982 and r['metrics']['correct']==8160 and r['recorded_prediction_disagreements']==0
    print('FULL_TEST_REEVALUATION_PASS',r['count'],r['metrics']['correct'],r['metrics']['accuracy'],'recorded_disagreements=0 software_only')
if __name__=='__main__':main()
