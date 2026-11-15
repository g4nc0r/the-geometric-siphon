#!/usr/bin/env python3
"""Excursions of excursion_check.py against the closed form of Proposition 10, by protocol, alignment,
spacing over width, fee and side of the range. Reads out/excursion_rows.csv and prints."""
import os
import numpy as np, pandas as pd
OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), 'out')
d = pd.read_csv(f'{OUT}/excursion_rows.csv', float_precision='round_trip')
d['inside'] = d.t.abs() < d.n; d['abs_err'] = (d.ratio - d.pred).abs(); d['sp_over_n'] = d.sp / d.n
pd.set_option('display.width', 220)
print(f'excursions {len(d):,}')
c = d[d.protocol == 'control']
print(f'\nControl (out and back, no re-minting): L_end = L_start exactly in {int((c.ratio == 1.0).sum()):,} of {len(c):,}; '
      f'max |ratio - 1| {np.abs(c.ratio - 1).max():.2e}')
k = d[d.protocol == 'excursion']
f0 = k[k.fee == 0]
a = f0[f0.inside & f0.aligned & f0.recentre_exact]
print(f'\nFee-free, aligned (both recentrings exactly centred), inside: {len(a):,} excursions; |L_end/L_start - pred| '
      f'max {a.abs_err.max():.2e}, median {a.abs_err.median():.2e}; relative max {(a.abs_err / a.pred).max():.2e}; '
      f'within 1e-15 relative: {np.mean(a.abs_err / a.pred <= 1e-15):.2%}')
print('  by spacing: ' + '; '.join(f'sp {s}: max rel {(g.abs_err / g.pred).max():.1e} (n {len(g)})' for s, g in a.groupby('sp')))
u = f0[f0.inside & ~f0.recentre_exact]
print(f'\nFee-free, inside, far recentring rounded to the grid: {len(u):,} excursions')
u = u.assign(err_signed=u.ratio - u.pred)
print('  |error| by sp/n (spacing over half-width): ')
print(u.groupby('sp_over_n').agg(n=('abs_err', 'size'), median=('abs_err', 'median'), mean=('abs_err', 'mean'), max=('abs_err', 'max'),
                                 frac_above=('err_signed', lambda v: float((v > 0).mean()))).to_string())
print(f'  max |error| / (sp/n): {(u.abs_err / u.sp_over_n).max():.3f}; median {(u.abs_err / u.sp_over_n).median():.3f}')
b = k[~k.inside]
print(f'\nBeyond the range (|t| >= n), all fees: L_end = 0 in {int((b.ratio == 0).sum()):,} of {len(b):,}; '
      f'fee-free {int((b[b.fee == 0].ratio == 0).sum()):,} of {len(b[b.fee == 0]):,}; max L_end/L_start {b.ratio.max():.3e}')
print('  nonzero cases by z, fee, sole LP: ', b[b.ratio > 0].groupby(['z', 'fee', 'lext']).size().to_dict())
fz = k[k.fee > 0 & k.inside]
base = f0.set_index(['sp', 'h', 'c', 't', 'aligned'])[['ratio']].rename(columns={'ratio': 'r0'})
m = k[(k.fee > 0) & k.inside].join(base, on=['sp', 'h', 'c', 't', 'aligned'], how='inner')
m['excess'] = m.ratio - m.r0
print(f'\nWith fees, inside: {len(m):,} excursions matched to the fee-free run; L_end >= fee-free in {int((m.excess >= 0).sum()):,} of {len(m):,} '
      f'(min excess {m.excess.min():.2e})')
print('  excess over fee-free (median, max) by fee and fee share (sole LP = lext 0):')
print(m.groupby(['fee', 'lext']).excess.agg(['median', 'mean', 'max']).to_string())
print('  excess / (fee rate) median by z:', m.assign(x=m.excess / (m.fee / 1e6)).groupby('z').x.median().round(4).to_dict())
print('\nControl by fee (fees collected at the final re-mint add tokens):')
print(c.assign(dev=(c.ratio - 1)).groupby('fee').dev.agg(['size', lambda v: int((v == 0).sum()), 'min', 'max']).rename(columns={'<lambda_0>': 'exact'}).to_string())
from decimal import Decimal, getcontext
getcontext().prec = 50
def pred_hp(t, n):
    l = Decimal('1.0001').ln(); eta, nu = Decimal(t) * l / 2, Decimal(n) * l / 2
    sh = lambda x: ((x).exp() - (-x).exp()) / 2
    return 1 - sh(eta / 2) ** 2 / sh(nu / 2) ** 2
rel_hp = np.array([float(abs(Decimal(r.ratio) - pred_hp(int(r.t), int(r.n))) / pred_hp(int(r.t), int(r.n))) for r in a.itertuples()])
a = a.assign(rel_hp=rel_hp)
print(f'Fee-free, aligned, with the closed form at 50 digits: relative error max {rel_hp.max():.2e}, median {np.median(rel_hp):.2e}; within 1e-15: {np.mean(rel_hp <= 1e-15):.2%}')
print('  by centre tick (integer token amounts shrink as the price leaves 1): ' + '; '.join(f'c {cc}: max {g.rel_hp.max():.1e}' for cc, g in a.groupby('c')))
