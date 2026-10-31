"""One explicit real-board inference; never falls back to a host prediction."""
from pathlib import Path
import argparse,json,sys
import numpy as np
ROOT=Path(__file__).resolve().parents[1];sys.path.insert(0,str(ROOT/'src/software'))
def main():
    p=argparse.ArgumentParser();p.add_argument('--task',choices=['classification','occupancy'],required=True);p.add_argument('--output',type=Path,required=True);p.add_argument('--program',action='store_true');a=p.parse_args()
    if not a.program:p.error('--program is required for volatile FPGA configuration and inference')
    from scripts.run_dual_fpga_hls4ml import service,infer_board
    result=infer_board(a.task,service.sample(a.task,0,8,backend='software'));a.output.parent.mkdir(parents=True,exist_ok=True);a.output.write_text(json.dumps(result,ensure_ascii=False,indent=2)+'\n',encoding='utf-8');print('REAL_FPGA_PASS',a.task,result['board_cycles'])
if __name__=='__main__':main()
