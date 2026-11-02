"""Re-evaluate the frozen66000-frame holdout, never train or tune a model."""
from pathlib import Path
from hashlib import sha256
import argparse
import json
import sys
import numpy as np

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'src/software'))


def main():
    p = argparse.ArgumentParser()
    p.add_argument('--output', type=Path, required=True)
    a = p.parse_args()
    a.output.mkdir(parents=True, exist_ok=False)
    from scripts.run_dual_fpga_hls4ml import service
    folder = ROOT / 'data/fixtures/occupancy_test'
    manifest = json.loads((folder / 'manifest.json').read_text('utf8'))
    tp = tn = fp = fn = 0
    by_snr = {}
    n = 0
    for part in manifest['parts']:
        file = folder / part['file']
        assert sha256(file.read_bytes()).hexdigest() == part['sha256'], file
        with np.load(file, allow_pickle=False) as z:
            iq, label, snr = z['iq'], z['label'], z['snr']
            for i in range(len(label)):
                logits = service.detector.logits(iq[i])
                truth, pred = int(label[i]), int(logits[1] > logits[0])
                tp += truth == 1 and pred == 1
                tn += truth == 0 and pred == 0
                fp += truth == 0 and pred == 1
                fn += truth == 1 and pred == 0
                if truth:
                    row = by_snr.setdefault(str(int(snr[i])), dict(n=0, detected=0))
                    row['n'] += 1
                    row['detected'] += pred
            n += len(label)
        print('OCCUPANCY_PROGRESS', n, '/', manifest['n'], flush=True)
    metrics = dict(n=n, tp=tp, tn=tn, fp=fp, fn=fn, accuracy=(tp+tn)/n, Pd=tp/(tp+fn), Pfa=fp/(fp+tn), by_snr=by_snr)
    for key in ['n','tp','tn','fp','fn']:
        assert metrics[key] == manifest['expected_int8_metrics'][key], (key, metrics[key])
    result = dict(status='PASS_FROZEN_OCCUPANCY_FULL_TEST', metrics=metrics, model_sha256=service.model_hashes['occupancy'], board_operated=False, training_or_tuning=False)
    (a.output / 'result.json').write_text(json.dumps(result, ensure_ascii=False, indent=2)+'\n', encoding='utf8')
    print(json.dumps(result, ensure_ascii=False), flush=True)


if __name__ == '__main__':
    main()
