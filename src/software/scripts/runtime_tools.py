from pathlib import Path
import os,hashlib
def sha(path):return hashlib.sha256(Path(path).read_bytes()).hexdigest()
def vivado_bin():
    value=os.environ.get('EDGEAI_VIVADO_BIN')
    if not value:raise RuntimeError('Set EDGEAI_VIVADO_BIN to the Vivado 2020.2 bin directory before FPGA inference.')
    return Path(value)
