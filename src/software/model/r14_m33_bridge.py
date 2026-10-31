"""R14 partition: M33-compatible INT8 CNN, FP32 cyclic residual on host CPU.

This is not an all-PL model or a live PS/PL transport implementation.
"""
from pathlib import Path
import numpy as np

def cyclic_features(samples):
    x=np.asarray(samples,dtype=np.float32)
    if x.ndim==2:x=x[None]
    if x.ndim!=3 or x.shape[1:]!=(2,128):raise ValueError('Expected [B,2,128] raw IQ')
    z=x[:,0].astype(np.float64)+1j*x[:,1].astype(np.float64)
    power=np.maximum((abs(z)**2).mean(1,keepdims=True),1e-12)
    z=z/np.sqrt(power)
    bins=np.asarray([0,1,2,4,8,12,16,24,32,-1,-2,-4,-8,-12,-16,-24,-32])%128
    def spectrum(v):return abs(np.fft.fft(v,n=128,axis=1))[:,bins]/v.shape[1]
    values=[]
    for lag in (0,1,2,4,8):
        a,b=z[:,lag:],z[:,:128-lag]
        values.extend([spectrum(a*b.conj()),spectrum(a*b)])
    values.extend([spectrum(z**4),spectrum(z**2*abs(z)**2)])
    amplitude=abs(z)
    values.append(np.stack([amplitude.mean(1),amplitude.std(1),(amplitude**4).mean(1),(amplitude**6).mean(1)],axis=1))
    return np.log1p(np.concatenate(values,axis=1)).astype(np.float32)

class FusionHead:
    def __init__(self,parameters):
        with np.load(Path(parameters),allow_pickle=False) as z:self.state={k:v.copy() for k,v in z.items()}
        self.cnn_logit_exponent=int(self.state['cnn_logit_exponent'])

    def residual(self,samples):
        s=self.state;f=cyclic_features(samples)
        x=np.clip((f-s['mean'])/np.maximum(s['std'],np.float32(1e-5)),-10,10)
        return np.maximum(x@s['weight0'].T+s['bias0'],0)@s['weight2'].T+s['bias2']

    def fuse(self,cnn_logits,samples):
        logits=np.asarray(cnn_logits)
        if logits.dtype.kind not in 'iu' or logits.shape[-1]!=4:raise ValueError('Expected four integer CNN logits per input')
        if np.any(logits<-(2**31)) or np.any(logits>2**31-1):raise OverflowError('CNN logits must fit INT32')
        scaled=logits.astype(np.float32)*np.float32(2.**self.cnn_logit_exponent)
        if 'cnn_correction_weight' in self.state:
            scaled=scaled@self.state['cnn_correction_weight'].T+self.state['cnn_correction_bias']
        residual=self.residual(samples)
        if scaled.shape!=residual.shape:raise ValueError('CNN and software-branch batch shapes differ')
        return scaled+residual
