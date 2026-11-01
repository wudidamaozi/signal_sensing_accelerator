"""Offline release and HTTP checks. Never invokes FPGA programming."""
from pathlib import Path
from zipfile import ZipFile
from hashlib import sha256
from http.client import HTTPConnection
import argparse,csv,json,subprocess,sys,threading,time,xml.etree.ElementTree as ET
import numpy as np
ROOT=Path(__file__).resolve().parents[1];sys.path.insert(0,str(ROOT/'src/software'))

def main():
    p=argparse.ArgumentParser();p.add_argument('--output',type=Path,required=True);p.add_argument('--full-test',action='store_true');a=p.parse_args();out=a.output.resolve();out.mkdir(parents=True,exist_ok=False)
    cmd=[sys.executable,'-X','utf8',str(ROOT/'sim/smoke.py'),'--output',str(out/'offline')]
    r=subprocess.run(cmd,capture_output=True);(out/'smoke.stdout.log').write_bytes(r.stdout);(out/'smoke.stderr.log').write_bytes(r.stderr);assert r.returncode==0
    variants=json.loads((ROOT/'build/variants.json').read_text(encoding='utf8'));assert len(variants)==10
    for name in ['classification_cpu','occupancy_cpu']:
        v=variants[name]
        for rel in [*v['sources'],*v['memory']]:assert (ROOT/rel).is_file(),rel
        for rel in v['sources']:
            for memory in __import__('re').findall(r'"(data/memory/[^"\n]+)"',(ROOT/rel).read_text(encoding='utf8')):assert (ROOT/memory).is_file(),memory
        assert v['model_sha256']==json.loads((ROOT/f'report/evidence/{name}/board.json').read_text(encoding='utf8'))['model_sha256']
    with np.load(ROOT/'data/fixtures/classification_test.npz',allow_pickle=False) as z:
        assert z['iq'].shape==(11982,2,128) and len(np.unique(z['sample_index']))==11982 and np.isfinite(z['iq']).all()
    identity=json.loads((ROOT/'report/release_identity.json').read_text(encoding='utf8'))
    for n,key in [('基于FPGA的信号感知加速系统技术文档.docx','report_docx_sha256'),('基于FPGA的信号感知加速系统技术文档.pdf','report_pdf_sha256')]:assert sha256((ROOT/'report'/n).read_bytes()).hexdigest()==identity[key]
    with ZipFile(ROOT/'report/基于FPGA的信号感知加速系统技术文档.docx') as z:
        t=''.join(ET.fromstring(z.read('word/document.xml')).itertext());assert '3.4 大模型辅助设计与工程验证' in t and '你从4乘8' not in t
    from scripts import run_dual_fpga_hls4ml as app
    server=app.ThreadingHTTPServer(('127.0.0.1',0),app.Handler);thread=threading.Thread(target=server.serve_forever,daemon=True);thread.start();port=server.server_port
    def request(path,method='GET',body=None):
        c=HTTPConnection('127.0.0.1',port,timeout=30);c.request(method,path,body=body,headers={'Origin':f'http://127.0.0.1:{port}','Content-Type':'application/json'});r=c.getresponse();raw=r.read();status=r.status;c.close();assert status==200,(path,status,raw[:100]);return raw
    try:
        for path in ['/','/dual_live.js','/dual.css','/hardware-architecture.svg']:assert len(request(path))>50
        overview=json.loads(request('/api/dual/overview'));comp=overview['board_comparison']
        assert len(comp['classification'])==len(comp['occupancy'])==4
        rows=list(csv.DictReader((ROOT/'report/four_method_board_results.csv').open(encoding='utf-8-sig')))
        expected={('classification',0):rows[3],('classification',1):rows[2],('classification',2):rows[1],('classification',3):rows[0],('occupancy',0):rows[7],('occupancy',1):rows[6],('occupancy',2):rows[5],('occupancy',3):rows[4]}
        for (task,i),row in expected.items():
            x=comp[task][i]
            assert min(x['cycles'])==int(row['cycles_min']) and max(x['cycles'])==int(row['cycles_max'])
            assert all(float(x[k])==float(row[k]) for k in ['lut','ff','bram36','dsp'])
        request('/api/dual/reevaluate/status')
        if a.full_test:
            request('/api/dual/reevaluate/start','POST','{}');deadline=time.monotonic()+900
            while True:
                state=json.loads(request('/api/dual/reevaluate/status'))
                if state['phase']!='running':break
                assert time.monotonic()<deadline,'Full test timeout';time.sleep(.5)
            (out/'full_test_result.json').write_text(json.dumps(state,ensure_ascii=False,indent=2),encoding='utf8')
            assert state['phase']=='complete',state
            result=state['result'];assert result['count']==11982 and result['metrics']['correct']==8160 and result['recorded_prediction_disagreements']==0
    finally:server.shutdown();server.server_close()
    summary=dict(status='PASS_FINAL_RELEASE_OFFLINE_HTTP',variants=10,comparison_rows=8,report_revision='V8',full_test_recomputed=a.full_test,full_test_count=11982 if a.full_test else None,full_test_correct=8160 if a.full_test else None,board_operated=False)
    (out/'summary.json').write_text(json.dumps(summary,indent=2));print(json.dumps(summary))
if __name__=='__main__':main()
