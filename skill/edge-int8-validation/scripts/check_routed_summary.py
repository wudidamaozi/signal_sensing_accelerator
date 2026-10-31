"""Validate explicit routed timing fields; no hardware or vendor tools used."""
import argparse
import json
import math
from pathlib import Path


def check(summary):
    for key in ('part', 'scope'):
        if not isinstance(summary.get(key), str) or not summary[key].strip():
            raise ValueError('Explicit nonempty ' + key + ' required')
    for key in ('clock_period_ns', 'setup_slack_ns', 'hold_slack_ns'):
        value = summary.get(key)
        if type(value) not in (int, float) or not math.isfinite(value):
            raise ValueError('Finite numeric ' + key + ' required')
    errors = summary.get('route_errors')
    if type(errors) is not int or errors != 0:
        raise ValueError('Zero integer route_errors required')
    if summary['clock_period_ns'] <= 0 or summary['setup_slack_ns'] < 0 or summary['hold_slack_ns'] < 0:
        raise ValueError('Internal routing/timing gate failed')
    return {'status': 'PASS_INTERNAL_TIMING_ONLY', 'part': summary['part'], 'scope': summary['scope'],
            'drc_entries': summary.get('drc_violations'), 'board_signoff': False}


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('summary', type=Path)
    a = p.parse_args()
    print(json.dumps(check(json.loads(a.summary.read_text(encoding='utf-8-sig'))), allow_nan=False))


if __name__ == '__main__': main()
