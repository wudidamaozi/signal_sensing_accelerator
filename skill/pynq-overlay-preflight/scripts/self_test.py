"""Synthetic host tests, not FPGA measurements. No PYNQ install required."""
from pathlib import Path
import tempfile
import unittest
from preflight import sha256,check_files,checked_overlay,BoundedMMIO


class FakeOverlay:
    downloads=0
    expected_name,expected_base,expected_size='filter_0',0x43c00000,4096
    def __init__(self,path,download):
        assert download is False
        self.ip_dict={self.expected_name:{'phys_addr':self.expected_base,'addr_range':self.expected_size}}
    def download(self): type(self).downloads+=1


class FakeMMIO:
    def __init__(self,base,size): self.words={}
    def read(self,offset): return self.words.get(offset,0)
    def write(self,offset,value): self.words[offset]=value


class Checks(unittest.TestCase):
    def setUp(self):
        self.tmp=tempfile.TemporaryDirectory();self.root=Path(self.tmp.name).resolve()
        for suffix in ('bit','hwh'): (self.root/('filter.'+suffix)).write_bytes(('synthetic-'+suffix).encode())
        self.rec=dict(bit='filter.bit',hwh='filter.hwh',bit_sha256=sha256(self.root/'filter.bit'),hwh_sha256=sha256(self.root/'filter.hwh'),ip_name='filter_0',base_address=0x43c00000,address_range=4096)
        FakeOverlay.downloads=0
    def tearDown(self): self.tmp.cleanup()
    def test_file_preflight(self): self.assertEqual(check_files(self.root,self.rec),self.root/'filter.bit')
    def test_inspection_no_download(self):
        checked_overlay(self.root,self.rec,FakeOverlay);self.assertEqual(FakeOverlay.downloads,0)
    def test_explicit_program_once(self):
        checked_overlay(self.root,self.rec,FakeOverlay,program=True);self.assertEqual(FakeOverlay.downloads,1)
    def test_other_project_map(self):
        class Other(FakeOverlay): expected_name,expected_base,expected_size='counter_0',0x80000000,256
        Other.downloads=0;rec=dict(self.rec,ip_name='counter_0',base_address=0x80000000,address_range=256)
        checked_overlay(self.root,rec,Other)
        io=BoundedMMIO(rec['base_address'],rec['address_range'],FakeMMIO);io.write32(252,0x12345678);self.assertEqual(io.read32(252),0x12345678)
    def test_bad_hash_before_download(self):
        for key in ('bit_sha256','hwh_sha256'):
            with self.assertRaises(ValueError): checked_overlay(self.root,dict(self.rec,**{key:'0'*64}),FakeOverlay,True)
        self.assertEqual(FakeOverlay.downloads,0)
    def test_malformed_hash(self):
        with self.assertRaises(ValueError): check_files(self.root,dict(self.rec,bit_sha256='example'))
    def test_wrong_ip_map(self):
        for changes in ({'ip_name':'wrong'},{'base_address':0},{'address_range':8192}):
            with self.assertRaises(ValueError): checked_overlay(self.root,dict(self.rec,**changes),FakeOverlay,True)
        self.assertEqual(FakeOverlay.downloads,0)
    def test_path_escape(self):
        with self.assertRaises(ValueError): check_files(self.root,dict(self.rec,bit='../filter.bit'))
    def test_unmatched_stems(self):
        (self.root/'other.hwh').write_bytes((self.root/'filter.hwh').read_bytes())
        with self.assertRaises(ValueError): check_files(self.root,dict(self.rec,hwh='other.hwh'))
    def test_missing_hwh(self):
        (self.root/'filter.hwh').unlink()
        with self.assertRaises(FileNotFoundError): check_files(self.root,self.rec)
    def test_bad_manifest_alignment(self):
        for changes in ({'base_address':1},{'address_range':0},{'address_range':5}):
            with self.assertRaises(ValueError): check_files(self.root,dict(self.rec,**changes))
    def test_mmio_first_last_words(self):
        io=BoundedMMIO(0,256,FakeMMIO)
        for offset,value in ((0,0xffffffff),(252,7)): io.write32(offset,value);self.assertEqual(io.read32(offset),value)
    def test_mmio_bounds(self):
        io=BoundedMMIO(0,256,FakeMMIO)
        for offset in (-4,1,256,False):
            with self.assertRaises(ValueError): io.read32(offset)
        for value in (-1,1<<32,True):
            with self.assertRaises(ValueError): io.write32(0,value)


if __name__=='__main__': unittest.main(verbosity=2)
