"""Independent two-task presentation. Never routes occupancy into classification."""
from collections import OrderedDict
from pathlib import Path
import csv
import hashlib
import io
import json
import threading
import time
import numpy as np
from host.occupancy_cascade import ClassificationReference, OccupancyReference, checked_iq

ROOT = Path(__file__).resolve().parents[3]
CLASSES = ['BPSK', 'QPSK', '8PSK', '16QAM']
OCCUPANCY = ROOT/'data/optional_full_occupancy'
ASSETS = ROOT / 'data/models/classification'


def read(path):
    return json.loads(Path(path).read_text(encoding='utf-8-sig'))


def sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def finite(value):
    if isinstance(value, np.generic):
        return finite(value.item())
    if isinstance(value, float) and not np.isfinite(value):
        return None
    if isinstance(value, dict):
        return {k: finite(v) for k, v in value.items()}
    if isinstance(value, (list, tuple)):
        return [finite(v) for v in value]
    return value


class DualService:
    def __init__(self, prefer_small_pools=False):
        self.lock = threading.RLock()
        self.rng = np.random.default_rng(2026102867)
        self.cache = OrderedDict()
        self.classifier = ClassificationReference(ASSETS/'parameters.npz', ASSETS/'software_branch.npz')
        self.detector = OccupancyReference(ROOT/'data/models/occupancy/int8_parameters.npz', ROOT/'data/models/occupancy/network_config.json')
        self.model_hashes = {'classification': sha(ASSETS/'parameters.npz'),
                             'occupancy': sha(ROOT/'data/models/occupancy/int8_parameters.npz')}
        selection = read(ROOT/'data/model_manifest.json')['assets']
        assert self.model_hashes['classification'] == selection['classifier_parameters']['sha256']
        assert self.model_hashes['occupancy'] == selection['occupancy_parameters']['sha256']
        assert sha(ASSETS/'software_branch.npz') == selection['classifier_head']['sha256']
        self.datasets = {}
        for task, folder, fields in [
            ('classification', ROOT/'data/processed/radioml2016.10a-4class',
             {'iq':'samples.npy','label':'labels.npy','snr':'snr.npy','split':'split.npy'}),
            ('occupancy', OCCUPANCY/'数据集/可追溯仿真_最终留出_v1',
             {'iq':'iq.npy','label':'label.npy','snr':'nominal_snr_db.npy','noise_power':'noise_complex_power.npy'})]:
            if not prefer_small_pools and (folder / fields['iq']).is_file():
                self.datasets[task] = {name:np.load(folder/file, mmap_mode='r', allow_pickle=False) for name,file in fields.items()}
                self.datasets[task]['sample_index'] = np.arange(len(self.datasets[task]['label']))
            else:
                with np.load(ROOT/f'data/fixtures/{task}.npz',allow_pickle=False) as z:
                    self.datasets[task] = {k:z[k].copy() for k in z.files}
            self.datasets[task]['lookup'] = {int(v):i for i,v in enumerate(self.datasets[task]['sample_index'])}
        s = read(ROOT/'report/evidence/classification_history/service_reference.json')
        self.rtl_records = {int(v['sample_index']):v for v in s['actual_axi_results']}

    def report(self):
        cls = read(ASSETS/'summary.json')['test']
        occ = read(ROOT/'data/fixtures/occupancy_acceptance.json')['final_holdout_metrics']
        m37 = read(ROOT/'report/evidence/classification_history/m37_schedule_20261025/summary.json')
        points = []
        for name, file, cycle_key in [
            ('M34 · 4×4', 'm34_early_q_read_20261025', 'candidate_cycles'),
            ('M35 · 4×8', 'm35_array_4x8_20261025', 'candidate_cycles'),
            ('M36 · 共享权重', 'm36_shared_weight_ports_20261025', 'candidate_cycles'),
            ('M37 · 调度优化', 'm37_schedule_20261025', 'candidate_cycles')]:
            s = read(ROOT/'report/evidence/classification_history'/file/'summary.json')
            physical = s.get('physical20', s.get('physical_candidate20',s.get('physical', {})))
            points.append({'name':name,'cycles':s[cycle_key],
                           'source':f'report/evidence/classification_history/{file}/summary.json','source_sha256':sha(ROOT/'report/evidence/classification_history'/file/'summary.json'),
                           'lut':physical.get('lut'),'ff':physical.get('ff'),
                           'bram36':physical.get('bram36_tiles'),'dsp':physical.get('dsp')})
        p = m37['physical20']
        result = {'schema':1,'title':'基于FPGA的信号感知加速系统','service':'edgeai-dual-4x8',
                  'mode':'independent_tasks','board_connected':False,'model_hashes':self.model_hashes,
                  'classification':{'classes':CLASSES,'metrics':cls,'scope':'原RadioML四类留出测试；INT8 CNN＋主机FP32循环统计分支；整体不是全PL',
                                    'source':'data/models/classification/summary.json'},
                  'occupancy':{'classes':['空闲','占用'],'metrics':occ['int8'],'fp32':{k:occ['fp32'][k] for k in ['n','accuracy','Pd','Pfa']},
                               'quantization_loss':occ['quantization_loss'],'scope':'独立可控仿真66000帧，-10…18dB；不是实测射频数据',
                               'source':'独立项目/阶段一_软件验收结论.json'},
                  'accelerator':{'name':'M37','array':[4,8],'cycles':m37['candidate_cycles'],
                                 'clock_mhz':50,'calculated_cnn_ms':m37['candidate_cycles']/50000,
                                 'lut':p['lut'],'ff':p['ff'],'bram36':p['bram36_tiles'],'dsp':p['dsp'],
                                 'setup_ns':p['setup_slack_ns'],'hold_ns':p['hold_slack_ns'],
                                 'scope':'XSim CNN计数：驻留输入Q复制→分类logit写回；不含全部传输与主机统计分支',
                                 'board_measured':False,'grid_frames':m37['grid_unique_frames'],'stage_hashes':m37['grid_stage_hashes']},
                  'matched_r14_points':points,
                  'baseline_groups':[{'name':'当前R14整数模型的受控版本对照','rows':'matched_r14_points','scope':'M34→M37，同模型/固件/输入/CNN计时边界；阵列和资源变化需同时看'},
                                     {'name':'历史CPU / HLS / 自研对照','scope':'旧冻结模型的独立历史组，不能与当前R14直接计算倍数','source':'baselines/README.md'}],
                  'readiness':{'classification_rtl':'已有M37冻结记录；20帧服务回归及80唯一样例/320摘要',
                               'occupancy_rtl':'尚未验收；不得套用分类周期','hardware_backend':'未连接；本页不会伪装实板推理',
                               'software_models':'两个应用独立运行；不串联、不重训、不改原数据'},
                  'limits':['软件计时、RTL仿真周期和实板计时分别标注，不混算加速比。',
                            '分类正确率与占用二分类准确率属于不同任务，不能直接横比。',
                            '吞吐率、功耗和当前版本板级端到端时延没有测量值。']}
        evidence = ROOT/'experiments/dual_app_4x8_preboard/current_evidence.json'
        if evidence.exists():
            result['new_evidence'] = read(evidence)
            verified = result['new_evidence']
            assert verified['model_sha256'] == self.model_hashes['occupancy']
            hardware = verified['occupancy_rtl']
            result['readiness']['occupancy_rtl'] = (
                f"{hardware['frames']}帧实际RV32IM＋4×8 XSim；每帧3个层摘要及2个logit核对通过；"
                '128KiB CPU RAM；尚无双任务板级接口、资源与时序闭合')
        return finite(result)

    def sample(self, task, label=None, snr=8, index=None, backend='software'):
        if task not in self.datasets or backend not in ('software','rtl'):
            raise ValueError('Unknown task/backend')
        data = self.datasets[task]
        if backend == 'rtl':
            if task != 'classification':
                raise ValueError('Occupancy RTL replay is not accepted yet')
            candidates = [i for i,v in self.rtl_records.items() if (label is None or v['true_class']==label) and v['snr_db']==snr]
        else:
            mask = np.ones(len(data['label']), dtype=bool)
            if task == 'classification':
                mask &= data['split']==2
            if label is not None:
                if label not in range(4 if task=='classification' else 2):
                    raise ValueError('Invalid class index')
                mask &= data['label']==label
            # H0 has no signal SNR. Its noise-power metadata is separate.
            if not (task=='occupancy' and label==0):
                mask &= data['snr']==snr
            candidates = np.flatnonzero(mask)
        if not len(candidates):
            raise ValueError('No sample matches these filters')
        if backend=='rtl':
            if index is None:index=int(self.rng.choice(candidates))
            elif index not in candidates:raise ValueError('Index has no matching RTL replay')
            row_index=data['lookup'][index]
        else:
            if index is None:row_index=int(self.rng.choice(candidates))
            else:
                row_index=data['lookup'].get(index,-1)
                if row_index not in candidates:raise ValueError('Index does not match the selected held-out pool')
            index=int(data['sample_index'][row_index])
        iq = np.array(data['iq'][row_index], dtype=np.float32, copy=True)
        truth = int(data['label'][row_index])
        meta = {'sample_index':index,'truth_index':truth,
                'truth':CLASSES[truth] if task=='classification' else ['空闲','占用'][truth],
                'snr_db':int(data['snr'][row_index]) if task=='classification' or truth else None,
                'source':'RadioML test' if task=='classification' else '独立仿真最终留出集',
                'noise_power':float(data['noise_power'][row_index]) if task=='occupancy' else None}
        return self.infer(task, iq, meta, backend)

    def infer(self, task, value, meta=None, backend='software'):
        if task not in self.datasets:
            raise ValueError('Unknown task')
        iq = checked_iq(value)
        start = time.perf_counter()
        if backend == 'rtl':
            if task != 'classification' or not meta:
                raise ValueError('RTL replay requires a frozen classification fixture')
            row = self.rtl_records[meta['sample_index']]
            logits = row['cnn_logits']
            scores = self.classifier.head.fuse(np.array([logits],dtype=np.int32),iq)[0].tolist()
            scope = '冻结M37 XSim实际logit回放＋本机实时统计分支；不是实时FPGA'
            cycles = int(row['cnn_cycles'])
        elif backend == 'software':
            if task == 'classification':
                row = self.classifier.classify(iq,0)
                logits, scores = row['cnn_logits'], row['scores']
            else:
                logits = self.detector.logits(iq).tolist()
                scores = [float(v)*2**-8 for v in logits]
            scope = '本机INT8数值参考推理；不代表FPGA或ARM时间'
            cycles = None
        else:
            raise ValueError('Unknown backend')
        elapsed = (time.perf_counter()-start)*1000
        predicted = int(np.argmax(scores)) if task=='classification' else int(logits[1]>logits[0])
        classes = CLASSES if task=='classification' else ['空闲','占用']
        z = iq[0].astype(np.float64)+1j*iq[1].astype(np.float64)
        spectrum = 10*np.log10(np.maximum(np.abs(np.fft.fftshift(np.fft.fft(z)))**2/128,1e-20))
        result = {'task':task,'classes':classes,'prediction':classes[predicted],'predicted_index':predicted,
                  'scores':scores,'integer_logits':[int(v) for v in logits],'iq':iq.tolist(),
                  'spectrum_db':spectrum.tolist(),'frequency_unit':'cycles/sample, not absolute RF frequency',
                  'backend':backend,'execution_scope':scope,'pc_elapsed_ms':elapsed,'cnn_rtl_cycles':cycles,
                  'model_sha256':self.model_hashes[task],'board_measured':False,'input_sha256':hashlib.sha256(iq.tobytes()).hexdigest(),
                  'metadata':meta,'matches_label':None if meta is None else predicted==meta['truth_index']}
        # Equal scores -> idle, even though general argmax on classifier scores is unrelated.
        identifier = hashlib.sha256((task+backend+result['input_sha256']+self.model_hashes[task]).encode()).hexdigest()[:20]
        result['id'] = identifier
        self.cache[identifier] = result
        self.cache.move_to_end(identifier)
        while len(self.cache)>128:
            self.cache.popitem(last=False)
        return finite(result)

    def metric_csv(self):
        r = self.report()
        f = io.StringIO(newline='')
        w = csv.writer(f,lineterminator='\n')
        w.writerow(['task','SNR_dB','class','correct_or_detected','count','rate','scope'])
        for snr, v in r['classification']['metrics']['by_snr'].items():
            for cls, row in v['by_class'].items():
                w.writerow(['classification',snr,CLASSES[int(cls)],row['correct'],row['count'],row['accuracy'],'RadioML held-out software'])
        for snr,v in r['occupancy']['metrics']['by_nominal_snr'].items():
            w.writerow(['occupancy',snr,'H1',round(v['Pd']*v['n']),v['n'],v['Pd'],'controlled simulation software'])
        return f.getvalue().encode('utf-8-sig')
