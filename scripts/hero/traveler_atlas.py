"""Paint the traveler's sixteen UV panels as a 2K atlas. Requires NumPy."""
import math
import struct
import zlib

import numpy as np

# Panel order is also the order of the four-by-four UV grid, top to bottom.
PANELS = {
    'hood': ('286371', 'wool'), 'mantle': ('337881', 'wool'),
    'coat': ('2f737a', 'wool'), 'fold': ('25555f', 'wool'),
    'lining': ('ce8b35', 'silk'), 'trousers': ('44424a', 'wool'),
    'sleeve': ('383944', 'wool'), 'clasp': ('d6ae65', 'metal'),
    'harness': ('835437', 'leather'), 'trim': ('503523', 'leather'),
    'glove': ('624837', 'leather'), 'cuff': ('79563f', 'leather'),
    'sole': ('322d2b', 'leather'), 'brass': ('c7914f', 'metal'),
    'blade': ('cca46a', 'metal'), 'grip': ('4d352c', 'leather'),
}


def paint(path):
    tile = 512
    y, x = np.mgrid[:tile, :tile] / tile
    atlas = np.zeros((tile * 4, tile * 4, 3), dtype=np.uint8)
    for number, (name, (hex_color, kind)) in enumerate(PANELS.items()):
        base = np.array(list(bytes.fromhex(hex_color)))
        rng = np.random.default_rng(1723 + number)
        p = x * math.tau
        q = y * math.tau
        # Long, broken pigment strokes follow the drape rather than screen axes.
        stroke = x * 8 + .23 * np.sin(q + .6) + .11 * np.sin(q * 3 - p)
        broad = np.sin(stroke * math.tau) * .045 + np.sin(q * 2 - p + np.sin(p * 3)) * .035
        fleck = rng.normal(0.0, .014, x.shape)
        if kind in ('wool', 'silk'):
            pleats = np.maximum(0, np.sin(stroke * math.tau)) ** 6
            weave = np.sin(p * 107) * np.sin(q * 91 + p * 3) * .016
            shade = .97 + broad - pleats * .095 + weave + fleck
        elif kind == 'leather':
            crease = np.sin(7 * p + .6 * q + 1.8 * np.sin(q * 2))
            shade = .95 + broad - np.maximum(0, crease) ** 18 * .10 + fleck
        else:
            hammer = np.sin(19 * p + np.sin(q * 11)) * np.sin(16 * q + np.cos(p * 9))
            shade = 1 + broad + hammer * .035 + fleck
        pigment = base * shade[..., None]
        if name in ('mantle', 'coat', 'lining'):
            border = .873 + .015 * np.sin(p * 3)
            # Sewn parallel welts and a repeated broken lozenge; the stronger
            # ochre thread is reserved for the lining.
            dist = np.abs(y - border)
            welts = np.maximum(0, 1 - np.abs(dist - .022) / .004)
            diamond = np.abs(np.abs(((x * 22) % 1) - .5) * .068 + dist - .023)
            thread = np.maximum(welts * .40, np.maximum(0, 1 - diamond / .003) * .64)
            thread *= .73 + .27 * np.cos(p * 137) ** 2
            stitch = np.array([221, 165, 70] if name == 'lining' else [146, 152, 112])
            pigment += (stitch - pigment) * thread[..., None]
        if name == 'hood':
            seam = np.abs(x - .51 - .028 * np.sin(q))
            raised = np.maximum(0, 1 - np.abs(seam - .011) / .0035)
            pigment += (np.array([94, 141, 143]) - pigment) * raised[..., None] * .7
        # Sparse slubs on cloth, healed scratches on leather, tooling on metal.
        for _ in range(135 if kind == 'wool' else 70):
            ix, iy = rng.integers(3, tile - 18, size=2)
            length = int(rng.integers(3, 13))
            for step in range(length):
                jx = ix + (step if kind != 'wool' else step // 4)
                jy = iy + (step if kind == 'wool' else step // 3)
                pigment[jy, jx] *= 1.08 + .06 * math.sin(math.pi * step / length)
        row, col = divmod(number, 4)
        atlas[row*tile:(row+1)*tile, col*tile:(col+1)*tile] = np.clip(pigment, 0, 255).astype(np.uint8)
    def chunk(kind, data):
        return struct.pack('>I', len(data)) + kind + data + struct.pack('>I', zlib.crc32(kind + data))
    size = tile * 4
    # Sub filtering preserves the small local pigment changes and compresses well.
    rows = np.empty((size, 1 + size * 3), dtype=np.uint8)
    rows[:, 0] = 1
    rows[:, 1:4] = atlas[:, 0]
    rows[:, 4:] = (atlas[:, 1:] - atlas[:, :-1]).reshape(size, -1)
    path.write_bytes(b'\x89PNG\r\n\x1a\n' + chunk(b'IHDR', struct.pack('>2I5B', size, size, 8, 2, 0, 0, 0))
                     + chunk(b'IDAT', zlib.compress(rows.tobytes(), 7)) + chunk(b'IEND', b''))
