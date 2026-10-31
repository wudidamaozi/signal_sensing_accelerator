"""Separate localhost FPGA demo. No fallback to software on board failure."""
from pathlib import Path
from http.server import BaseHTTPRequestHandler,ThreadingHTTPServer
from urllib.parse import urlparse,parse_qs
import hashlib,json,re,subprocess,sys,tempfile,threading,time
import numpy as np
ROOT=Path(__file__).resolve().parents[3];sys.path.insert(0,str(ROOT))
from demo.dual_4x8_report import DualService,finite
from scripts.board_performance_hls4ml import load_board_comparison
from host.occupancy_cascade import checked_iq
from model.occupancy_v1.integer_reference import qinput
from reference.int8_modulation_cnn import quantize_input
from scripts.runtime_tools import vivado_bin,sha
B={'classification':(ROOT/'board/live/classification',ROOT/'board/program_classification.tcl','LIVE_CLASS_BOARD_PASS',4),'occupancy':(ROOT/'board/live/occupancy',ROOT/'board/program_occupancy.tcl','LIVE_O55_BOARD_PASS',2)}
lock=threading.Lock();service=DualService(prefer_small_pools=True)

def infer_board(task,result):
 if task not in B:raise ValueError('Unknown task')
 iq=checked_iq(result['iq']);b,tcl,marker,count=B[task];meta=json.loads((b/'summary.json').read_text());
 if meta['status']!='PASS_LIVE_ROUTE_NO_BOARD':raise RuntimeError('FPGA image has not passed routing verification')
 if meta['model_sha256']!=service.model_hashes[task] or sha(b/'board.bit')!=meta['bit_sha256'] or sha(b/'debug.ltx')!=meta['ltx_sha256']:raise RuntimeError('FPGA model or bitstream identity mismatch')
 if task=='classification':q=quantize_input(iq,service.classifier.parameters.input_exponent)
 else:
  det=service.detector;q=qinput(np.clip(iq,-det.bound,det.bound)/det.bound,int(det.parameters['input_exp']))
 raw=q.reshape(-1).view(np.uint8).tobytes();words=[f'{int.from_bytes(raw[i:i+4],"little"):08x}' for i in range(0,len(raw),4)]
 with tempfile.TemporaryDirectory(prefix='edgeai_live_') as tmp:
  f=Path(tmp)/'input.hex';f.write_text('\n'.join(words)+'\n',encoding='ascii');cmd=[str(vivado_bin()/'vivado.bat'),'-mode','batch','-source',str(tcl),'-tclargs',str(b),str(f),'program'];actual=['cmd.exe','/d','/s','/c',subprocess.list2cmdline(cmd)]
  start=time.perf_counter();proc=subprocess.run(actual,cwd=tmp,capture_output=True,timeout=180);elapsed=(time.perf_counter()-start)*1000
  out=proc.stdout.decode('utf8',errors='replace');err=proc.stderr.decode('utf8',errors='replace')
  if proc.returncode:raise RuntimeError(f'FPGA execution failed (exit {proc.returncode}): '+(out+'\n'+err)[-1200:])
  lines=[x for x in out.splitlines() if x.startswith(marker+' ')];pattern=marker+r' id=(\d+)'+''.join(fr' logits{i}=(\d+)' for i in range(count))+r' cycles=(\d+)'
  if len(lines)!=1:raise RuntimeError('Missing unique FPGA result')
  m=re.fullmatch(pattern,lines[0]);
  if not m:raise RuntimeError('Malformed FPGA result')
  vals=list(map(int,m.groups()));logits=[v-2**32 if v>=2**31 else v for v in vals[1:1+count]];cycles=vals[-1]
  if logits!=result['integer_logits']:raise RuntimeError(f'FPGA/reference mismatch: board={logits}, reference={result["integer_logits"]}')
  result.update(integer_logits=logits,board_measured=True,board_cycles=cycles,end_to_end_ms=elapsed,execution_scope=('FPGA INT8 CNN；USB/配置及FP32融合在主机' if task=='classification' else 'FPGA INT8 CNN；输入量化及USB/配置在主机'),backend='fpga',bit_sha256=meta['bit_sha256'],quantized_input_sha256=hashlib.sha256(raw).hexdigest())
  if task=='classification':result['scores']=service.classifier.head.fuse(np.asarray([logits],dtype=np.int32),iq)[0].tolist()
  else:result['scores']=[v*2**-8 for v in logits]
  result['predicted_index']=int(np.argmax(result['scores'])) if task=='classification' else int(logits[1]>logits[0]);result['prediction']=result['classes'][result['predicted_index']]
  if result['metadata'] is not None:result['matches_label']=result['predicted_index']==result['metadata']['truth_index']
  return finite(result)

class Handler(BaseHTTPRequestHandler):
 def reply(self,data,status=200):
  raw=json.dumps(data,ensure_ascii=False,allow_nan=False).encode('utf8');self.send_response(status);self.send_header('Content-Type','application/json; charset=utf-8');self.send_header('Cache-Control','no-store');self.end_headers();self.wfile.write(raw)
 def do_GET(self):
  u=urlparse(self.path)
  if u.path in ('/','/dual_live.js','/dual.css'):
   file={'/':'index.html','/dual_live.js':'dual_live.js','/dual.css':'dual.css'}[u.path];raw=(ROOT/'src/web'/file).read_bytes();self.send_response(200);self.send_header('Content-Type',('text/html' if u.path=='/' else 'text/css' if u.path.endswith('.css') else 'application/javascript')+'; charset=utf-8');self.send_header('Cache-Control','no-store');self.end_headers();self.wfile.write(raw);return
  if u.path=='/hardware-architecture.svg':
   raw=(ROOT/'report/figures/hardware_architecture.svg').read_bytes();self.send_response(200);self.send_header('Content-Type','image/svg+xml; charset=utf-8');self.send_header('Cache-Control','no-store');self.end_headers();self.wfile.write(raw);return
  if u.path=='/api/dual/overview':
   try:r=service.report();r['board_comparison']=load_board_comparison()
   except (ValueError,KeyError,OSError) as e:self.reply({'error':'对照证据不可用：'+str(e)},503);return
   r['readiness']['occupancy_rtl']='固定4×8：30输入加重放，31调用、93层摘要、62logits一致；实板两输入各两次，35629周期';r['readiness']['hardware_backend']='USB FPGA动态样本；占用4×8双缓冲优化版，分类保持原版';r['live_occupancy']={'implementation':'fixed4x8-20261031','expected_cycles':35629,'array':[4,8],'assets':'board/live/occupancy'};r['occupancy']['accelerator']=r['board_comparison']['occupancy'][0];r['baseline_groups']=[{'name':'同任务：信号感知加速系统 / hls4ml / Caffe im2col移植 + 4×8 GEMM','scope':'7020实板周期；资源采用统一基准测试工程，交互接口另建镜像'}];self.reply(r);return
  if u.path=='/api/dual/metrics.csv':
   raw=service.metric_csv();self.send_response(200);self.send_header('Content-Type','text/csv; charset=utf-8');self.send_header('Content-Disposition','attachment; filename="dual-task-metrics.csv"');self.end_headers();self.wfile.write(raw);return
  self.reply({'error':'Not found'},404)
 def do_POST(self):
  if self.path not in ('/api/dual/infer','/api/dual/sample'):self.reply({'error':'Not found'},404);return
  if self.headers.get('Origin')!='http://127.0.0.1:'+str(self.server.server_port) or self.headers.get_content_type()!='application/json':self.reply({'error':'Only the local demo page may control the FPGA'},403);return
  try:
   n=int(self.headers['Content-Length']);
   if not 0<n<=65536:raise ValueError('Invalid request length')
   x=json.loads(self.rfile.read(n));task=x['task'];
   with lock:
    if self.path=='/api/dual/sample':reference=service.sample(task,int(x['class_id']),int(x['snr']),backend='software')
    else:reference=service.infer(task,x['iq'])
    result=infer_board(task,reference)
   self.reply(result)
  except (ValueError,KeyError) as e:self.reply({'error':str(e)},400)
  except (RuntimeError,subprocess.TimeoutExpired) as e:self.reply({'error':str(e)},500)
if __name__=='__main__':
 print('FPGA_LIVE_WEB http://127.0.0.1:8771/ original=http://127.0.0.1:8768/',flush=True);ThreadingHTTPServer(('127.0.0.1',8771),Handler).serve_forever()
