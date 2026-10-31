from pathlib import Path
import json
ROOT=Path(__file__).resolve().parents[3]
def read(path):return json.loads((ROOT/path).read_text(encoding='utf-8'))
def pair(name,board,physical,expected_status,bram_key):
 b=read(board);p=read(physical)
 if b['status']!=expected_status or not b['board_tested']:raise ValueError('Unverified board result: '+board)
 if b['bit_sha256']!=p['bit_sha256'] or b['model_sha256']!=p['model_sha256']:raise ValueError('Board and routed image identity mismatch: '+board)
 return {'name':name,'cycles':b['cycles'],'lut':p['lut'],'ff':p['ff'],'bram36':p[bram_key],'dsp':p['dsp'],'model_sha256':b['model_sha256'],'board_source':board,'physical_source':physical}
def load_board_comparison():
 c=[pair('自研 M37','report/evidence/classification_native/board.json','report/evidence/classification_native/physical.json','R14_M37_USB_BOARD_PASS','bram36'),pair('hls4ml','report/evidence/classification_hls4ml/board.json','report/evidence/classification_hls4ml/physical.json','R14_HLS_USB_BOARD_PASS','bram36'),pair('Caffe im2col移植 + 4×8 GEMM','report/evidence/classification_im2col/board.json','report/evidence/classification_im2col/physical.json','R14_IM2COL_USB_BOARD_PASS','bram36')]
 o=[pair('信号感知加速系统（占用）','report/evidence/occupancy_native/board.json','report/evidence/occupancy_native/physical.json','PASS_OCCUPANCY_LATENCY_USB_BOARD','bram36'),pair('hls4ml','report/evidence/occupancy_hls4ml/board.json','report/evidence/occupancy_hls4ml/physical.json','PASS_OCCUPANCY_HLS4ML_USB_BOARD','bram36'),pair('Caffe im2col移植 + 4×8 GEMM','report/evidence/occupancy_im2col/board.json','report/evidence/occupancy_im2col/physical.json','IM2COL_USB_BOARD_PASS','bram36')]
 for group in (c,o):
  if len({v['model_sha256'] for v in group})!=1:raise ValueError('Different model identities within comparison')
 return {'clock_mhz':50,'classification':c,'occupancy':o,'classification_unique_inputs':1,'occupancy_unique_inputs':2}
if __name__=='__main__':print(json.dumps(load_board_comparison(),ensure_ascii=False,indent=2))
