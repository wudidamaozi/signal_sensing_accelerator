"""Exercise software HTTP inference and explicit FPGA failure, without a board."""
from pathlib import Path
from http.client import HTTPConnection
from unittest.mock import patch
import argparse
import json
import sys
import threading

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'src/software'))


def probe(root):
    sys.path.insert(0, str(root / 'src/software'))
    from scripts import run_dual_fpga_hls4ml as app
    app.Handler.default_backend = 'software'
    server = app.ThreadingHTTPServer(('127.0.0.1', 0), app.Handler)
    worker = threading.Thread(target=server.serve_forever, daemon=True)
    worker.start()
    port = server.server_port

    def request(path, body=None):
        conn = HTTPConnection('127.0.0.1', port, timeout=30)
        conn.request('POST' if body is not None else 'GET', path,
                     body=json.dumps(body) if body is not None else None,
                     headers={'Origin': f'http://127.0.0.1:{port}', 'Content-Type': 'application/json'})
        res = conn.getresponse()
        raw = res.read()
        conn.close()
        return res.status, raw

    results = {}
    try:
        with patch.object(app, 'infer_board', side_effect=RuntimeError('FPGA_TEST_SENTINEL')):
            for task, label in [('classification', 0), ('occupancy', 1)]:
                body = dict(task=task, class_id=label, snr=8, backend='software')
                status, raw = request('/api/dual/sample', body)
                value = json.loads(raw)
                result = dict(status=status, backend=value.get('backend'), board_measured=value.get('board_measured'), error=value.get('error'))
                if status == 200:
                    status2, raw2 = request('/api/dual/infer', dict(task=task, iq=value['iq'], backend='software'))
                    inferred = json.loads(raw2)
                    result['custom_status'] = status2
                    result['custom_logits_equal'] = inferred.get('integer_logits') == value['integer_logits']
                results[task] = result
            status, raw = request('/api/dual/sample', dict(task='classification', class_id=0, snr=8, backend='fpga'))
            results['fpga_failure'] = dict(status=status, error=json.loads(raw).get('error'))
            status, raw = request('/api/dual/sample', dict(task='classification', class_id=0, snr=8))
            results['legacy_fpga_failure'] = dict(status=status, error=json.loads(raw).get('error'))
            status, raw = request('/api/dual/sample', dict(task='classification', class_id=0, snr=8, backend='invalid'))
            results['invalid_backend'] = dict(status=status, error=json.loads(raw).get('error'))
            status, raw = request('/api/dual/overview')
            value = json.loads(raw)
            results['overview'] = dict(status=status, runtime=value.get('runtime'), methods=[len(value['board_comparison'][t]) for t in ['classification','occupancy']])
            for name in ['/', '/dual_live.js', '/dual.css', '/hardware-architecture.svg', '/project-readme', '/api/dual/metrics.csv']:
                status, raw = request(name)
                results[name] = dict(status=status, bytes=len(raw))
    finally:
        server.shutdown()
        server.server_close()
        worker.join()
    return results


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    args.output.mkdir(parents=True, exist_ok=False)
    results = probe(ROOT)
    (args.output / 'result.json').write_text(json.dumps(results, ensure_ascii=False, indent=2) + '\n', encoding='utf8')
    for task in ['classification','occupancy']:
        r = results[task]
        assert r['status'] == r['custom_status'] == 200 and r['backend'] == 'software' and r['board_measured'] is False and r['custom_logits_equal'], r
    assert results['fpga_failure'] == dict(status=500, error='FPGA_TEST_SENTINEL')
    assert results['legacy_fpga_failure'] == results['fpga_failure']
    assert results['invalid_backend']['status'] == 400
    assert results['overview']['runtime']['default_backend'] == 'software'
    assert all(results[p]['status'] == 200 for p in ['/', '/dual_live.js', '/dual.css', '/hardware-architecture.svg', '/project-readme', '/api/dual/metrics.csv'])
    variants = json.loads((ROOT / 'build/variants.json').read_text('utf8'))
    assert all(v['testbench'] == Path(v['tb_sources'][0]).stem for v in variants.values())
    print('PORTABILITY_PASS software_sample=2 software_custom=2 fpga_error_preserved=1 invalid_backend_rejected=1')


if __name__ == '__main__':
    main()
