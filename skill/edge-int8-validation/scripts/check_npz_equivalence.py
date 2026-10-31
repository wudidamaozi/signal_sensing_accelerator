"""Compare explicitly selected integer boundary arrays; works outside this project."""
from pathlib import Path
import argparse, json
import numpy as np

KEYS = ('input_q', 'pool1_q', 'pool2_q', 'conv3_q', 'global_average_q', 'logits')

def compare(expected, actual, keys=KEYS):
    result = []
    with np.load(expected, allow_pickle=False) as a, np.load(actual, allow_pickle=False) as b:
        for key in keys:
            x, y = a[key], b[key]
            if x.dtype.kind not in 'iu' or y.dtype.kind not in 'iu':
                raise ValueError('Integer boundary required: ' + key)
            if x.dtype != y.dtype or x.shape != y.shape or x.tobytes() != y.tobytes():
                raise ValueError('Boundary mismatch: ' + key)
            result.append({'key': key, 'dtype': str(x.dtype), 'shape': list(x.shape), 'bytes': x.nbytes})
    return result

def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--expected', type=Path, required=True)
    p.add_argument('--actual', type=Path, required=True)
    p.add_argument('--keys', default=','.join(KEYS))
    a = p.parse_args()
    print(json.dumps({'status': 'PASS_INTEGER_BOUNDARIES', 'arrays': compare(a.expected, a.actual, a.keys.split(','))}))

if __name__ == '__main__':
    main()
