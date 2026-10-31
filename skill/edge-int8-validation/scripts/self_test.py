"""Exact-boundary and malformed-timing checks; temporary files only."""
from pathlib import Path
import tempfile
import unittest
import numpy as np
from check_npz_equivalence import compare
from check_routed_summary import check


class IntegerChecks(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory(); self.root = Path(self.tmp.name)
        self.a = {'input_q': np.array([[-128,0,127]],dtype=np.int8), 'layer1_q': np.array([-7,8],dtype=np.int8),
                  'logits': np.array([-2147483648,2147483647],dtype='<i4')}
        np.savez(self.root/'golden.npz',**self.a)
    def tearDown(self): self.tmp.cleanup()
    def run_pair(self, values):
        np.savez(self.root/'actual.npz',**values)
        return compare(self.root/'golden.npz',self.root/'actual.npz',tuple(self.a))
    def test_independent_equal_files(self): self.assertEqual(len(self.run_pair({k:v.copy() for k,v in self.a.items()})),3)
    def test_one_byte_changed(self):
        values={k:v.copy() for k,v in self.a.items()}; values['layer1_q'][0]+=1
        with self.assertRaises(ValueError): self.run_pair(values)
    def test_dtype(self):
        with self.assertRaises(ValueError): self.run_pair(dict(self.a,logits=self.a['logits'].astype(np.int64)))
    def test_shape(self):
        with self.assertRaises(ValueError): self.run_pair(dict(self.a,input_q=self.a['input_q'].reshape(3)))
    def test_float(self):
        with self.assertRaises(ValueError): self.run_pair(dict(self.a,layer1_q=self.a['layer1_q'].astype(float)))
    def test_missing(self):
        values=dict(self.a);del values['logits']
        with self.assertRaises(KeyError): self.run_pair(values)
    def test_endianness(self):
        with self.assertRaises(ValueError): self.run_pair(dict(self.a,logits=self.a['logits'].astype('>i4')))


class TimingChecks(unittest.TestCase):
    def setUp(self): self.good=dict(part='example_device',scope='routed single_clock_ip',clock_period_ns=10.,setup_slack_ns=.12,hold_slack_ns=.01,route_errors=0)
    def test_valid(self): self.assertFalse(check(self.good)['board_signoff'])
    def test_zero_slack(self): check(dict(self.good,setup_slack_ns=0.,hold_slack_ns=0.))
    def test_negative_slacks(self):
        for key in ('setup_slack_ns','hold_slack_ns'):
            with self.subTest(key=key),self.assertRaises(ValueError): check(dict(self.good,**{key:-.01}))
    def test_nonfinite(self):
        for key in ('clock_period_ns','setup_slack_ns','hold_slack_ns'):
            for value in (float('nan'),float('inf'),-float('inf')):
                with self.subTest(key=key,value=value),self.assertRaises(ValueError): check(dict(self.good,**{key:value}))
    def test_nonpositive_clock(self):
        for value in (0,-1):
            with self.assertRaises(ValueError): check(dict(self.good,clock_period_ns=value))
    def test_missing_identity(self):
        for key in ('part','scope'):
            values=dict(self.good);del values[key]
            with self.assertRaises(ValueError): check(values)
    def test_bad_route(self):
        for value in (1,-1,False,'0',0.0):
            with self.assertRaises(ValueError): check(dict(self.good,route_errors=value))


if __name__=='__main__': unittest.main(verbosity=2)
