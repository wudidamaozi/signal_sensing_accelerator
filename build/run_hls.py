"""Rebuild a frozen hls4ml project and gate actual synthesis output, not only process exit."""
from pathlib import Path
import argparse,re,subprocess,xml.etree.ElementTree as ET
ROOT=Path(__file__).resolve().parents[1]
def main():
    p=argparse.ArgumentParser();p.add_argument('--task',choices=['classification','occupancy'],required=True);p.add_argument('--hls-bin',type=Path,required=True);a=p.parse_args();out=ROOT/'build/output'/('hls_'+a.task)
    assert not out.exists(),'Preserve old HLS results; use a fresh checkout/output'
    logs=ROOT/'build/output'/('hls_logs_'+a.task);logs.mkdir(parents=True,exist_ok=False)
    command=[str(a.hls_bin/'vitis_hls.bat'),'-f',str(ROOT/f'build/scripts/hls_{a.task}.tcl')]
    r=subprocess.run(['cmd.exe','/d','/s','/c',subprocess.list2cmdline(command)],cwd=ROOT,capture_output=True);(logs/'stdout.log').write_bytes(r.stdout);(logs/'stderr.log').write_bytes(r.stderr)
    assert r.returncode==0,'HLS process failed'
    text=r.stdout.decode('utf-8',errors='replace');errors=re.findall(r'^ERROR:.*',text,re.M)
    if errors:
        known="ERROR: [HLS 200-642] The 'config_array_partition -maximum_size' command is not supported."
        assert a.task=='occupancy' and [x.rstrip() for x in errors]==[known] and 'Allowed max sub elements number after partition is 2048.' in text,'Unexpected HLS error'
    top='public_cnn' if a.task=='classification' else 'occupancy_hls4ml'
    report=out/'solution1/syn/report'/(top+'_csynth.xml');ET.parse(report)
    print('HLS_SYNTH_REPORT_PASS',a.task,report)
if __name__=='__main__':main()
