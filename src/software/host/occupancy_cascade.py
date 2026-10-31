"""Host-only two-stage reference. No FPGA execution is implied by this module."""
from pathlib import Path
import hashlib
import json
import numpy as np
from model.occupancy_v1.integer_reference import infer_trace as occupancy_trace
from reference.int8_modulation_cnn import QuantizedParameters, infer_one
from model.r14_m33_bridge import FusionHead

ROOT = Path(__file__).resolve().parents[3]
CLASSES = ('BPSK', 'QPSK', '8PSK', '16QAM')
OUTPUT_CLASSES = ('idle', *CLASSES)


def checked_iq(value):
    raw = np.asarray(value)
    if raw.shape != (2, 128) or raw.dtype.kind not in 'iuf':
        raise ValueError('Expected real numeric IQ [2,128]')
    if not np.isfinite(raw).all():
        raise ValueError('Nonfinite IQ')
    with np.errstate(over='ignore', invalid='ignore'):
        raw = raw.astype(np.float32)
    if not np.isfinite(raw).all():
        raise ValueError('IQ cannot be represented as float32')
    return raw


def classifier_input(iq):
    """L1 complex-amplitude adapter AFTER detection; experimental source matching."""
    raw = checked_iq(iq)
    total = np.hypot(raw[0].astype(np.float64), raw[1].astype(np.float64)).sum()
    if not np.isfinite(total) or total <= 0:
        raise ValueError('Cannot adapt zero-energy frame for classification')
    return (raw.astype(np.float64) / total).astype(np.float32)


def checked_asset(name, expected):
    path = (ROOT / name).resolve()
    if ROOT not in path.parents or not path.is_file():
        raise ValueError('Asset outside repository or missing: ' + name)
    if hashlib.sha256(path.read_bytes()).hexdigest() != expected:
        raise ValueError('Model asset hash mismatch: ' + name)
    return path


class OccupancyReference:
    def __init__(self, parameter_file, network_config):
        config = json.loads(Path(network_config).read_text(encoding='utf-8-sig'))
        if hashlib.sha256(Path(parameter_file).read_bytes()).hexdigest() != config['frozen_npz_sha256']:
            raise ValueError('Occupancy parameter hash mismatch')
        self.bound = np.float32(config['bound'])
        if not np.isfinite(self.bound) or self.bound <= 0:
            raise ValueError('Invalid occupancy bound')
        with np.load(parameter_file, allow_pickle=False) as z:
            self.parameters = {k: z[k].copy() for k in z.files}

    def logits(self, iq):
        raw = checked_iq(iq)
        scaled = np.clip(raw, -self.bound, self.bound) / self.bound
        return occupancy_trace(scaled, self.parameters)['logits']


class ClassificationReference:
    """Frozen R14 integer CNN plus original host FP32 cyclic head; not hardware."""
    def __init__(self, cnn_file, head_file):
        self.parameters = QuantizedParameters.load(Path(cnn_file))
        self.head = FusionHead(head_file)

    def classify(self, iq, frame_id):
        raw = checked_iq(iq)
        logits = infer_one(raw, self.parameters)
        scores = self.head.fuse(np.asarray([logits], dtype=np.int32), raw)[0]
        return {'frame_id': frame_id, 'cnn_logits': logits.tolist(),
                'scores': scores.tolist(), 'predicted_class': int(scores.argmax()),
                'execution_scope': 'host NumPy CNN + host FP32 head; no device'}


class OccupancyCascade:
    def __init__(self, detector, classifier, mode='detect_then_classify'):
        if mode not in ('classify_only', 'detect_then_classify'):
            raise ValueError('Unknown cascade mode')
        self.detector, self.classifier, self.mode = detector, classifier, mode

    def classify(self, iq, frame_id):
        raw = checked_iq(iq)
        if isinstance(frame_id, bool) or not isinstance(frame_id, (int, np.integer)) or not 0 <= int(frame_id) < 2**32:
            raise ValueError('frame_id must be an unsigned 32-bit integer')
        frame_id = int(frame_id)
        logits = None
        if self.mode == 'detect_then_classify':
            values = np.asarray(self.detector.logits(raw))
            if values.shape != (2,) or values.dtype.kind not in 'iu':
                raise ValueError('Detector must return two integer logits')
            logits = [int(v) for v in values]
            if logits[1] <= logits[0]:
                return {'frame_id': frame_id, 'state': 'idle', 'output_class': 0,
                        'occupancy_logits': logits, 'classification_called': False,
                        'classification': None}
        # Keep detector input untouched. Only classification receives L1-adapted IQ.
        result = self.classifier.classify(classifier_input(raw), frame_id)
        if result.get('frame_id') != frame_id:
            raise ValueError('Classifier frame ID mismatch')
        cls = result.get('predicted_class')
        if isinstance(cls, bool) or not isinstance(cls, (int, np.integer)) or not 0 <= int(cls) < 4:
            raise ValueError('Classifier returned invalid four-class index')
        return {'frame_id': frame_id, 'state': CLASSES[int(cls)],
                'output_class': int(cls) + 1, 'occupancy_logits': logits,
                'classification_called': True, 'classification': result}


def from_selection(path, classifier=None):
    config = json.loads(Path(path).read_text(encoding='utf-8-sig'))
    assets = {k: checked_asset(v['path'], v['sha256']) for k, v in config['assets'].items()}
    detector = OccupancyReference(assets['occupancy_parameters'], assets['occupancy_config'])
    if classifier is None:
        classifier = ClassificationReference(assets['classifier_parameters'], assets['classifier_head'])
    return OccupancyCascade(detector, classifier, config['mode'])
