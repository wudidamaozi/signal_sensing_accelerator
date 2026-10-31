"""Start the packaged real-FPGA web demo. A missing board never becomes software success."""
from pathlib import Path
import argparse,sys
ROOT=Path(__file__).resolve().parents[1];sys.path.insert(0,str(ROOT/'src/software'))
def main():
    p=argparse.ArgumentParser();p.add_argument('--port',type=int,default=8771);a=p.parse_args()
    from scripts.run_dual_fpga_hls4ml import Handler,ThreadingHTTPServer
    print(f'WEB http://127.0.0.1:{a.port}/',flush=True)
    ThreadingHTTPServer(('127.0.0.1',a.port),Handler).serve_forever()
if __name__=='__main__':main()
