"""Independent NumPy integer reference for document-specified CNN."""
import numpy as np

def round_shift(x,s):
 x=np.asarray(x,dtype=np.int64)
 if s<0:return x*(1<<(-s))
 if s==0:return x
 y=(np.abs(x)+(1<<(s-1)))>>s
 return np.where(x<0,-y,y)

def qinput(x,exponent):
 a=np.asarray(x,dtype=np.float64)/(2.0**exponent)
 return np.clip(np.where(a<0,np.ceil(a-.5),np.floor(a+.5)),-128,127).astype(np.int8)

def conv(x,w,b):
 x=np.asarray(x,dtype=np.int64); w=np.asarray(w,dtype=np.int64); b=np.asarray(b,dtype=np.int64)
 z=np.lib.stride_tricks.sliding_window_view(x,w.shape[-1],axis=1)
 return (z.transpose(1,0,2).reshape(z.shape[1],-1) @ w.reshape(w.shape[0],-1).T).T + b[:,None]

def infer_trace(sample,p):
 inp=qinput(sample,int(p['input_exp']));a=conv(inp,p['conv1_weight'],p['conv1_bias']);a=np.clip(round_shift(a,int(p['conv1_shift'])),0,127).astype(np.int8)
 b=conv(a,p['conv2_weight'],p['conv2_bias']);b=np.clip(round_shift(b,int(p['conv2_shift'])),-128,127).astype(np.int8)
 c=p['fc1_weight'].astype(np.int64)@b.astype(np.int64).reshape(-1)+p['fc1_bias'].astype(np.int64);c=np.clip(round_shift(c,int(p['fc1_shift'])),0,127).astype(np.int8)
 z=p['fc2_weight'].astype(np.int64)@c.astype(np.int64)+p['fc2_bias'].astype(np.int64)
 return {'input_q':inp,'conv1_q':a,'conv2_q':b,'fc1_q':c,'logits':z}
