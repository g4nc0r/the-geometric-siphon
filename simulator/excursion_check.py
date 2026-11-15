#!/usr/bin/env python3
"""Proposition 10 (Retained excursion) in V3 integer arithmetic.

A position fully deployed on [c - n, c + n) (tick-centred, c on the spacing grid). The price is moved to c + t by an
exact-input swap through the pool (the position plus full-range external liquidity L_ext), the position is burned
(principal plus fees, V3 fee-growth rounding), re-minted swap-free from its own tokens and its own idle balance on
[centre(c + t) - n, centre(c + t) + n), the price is swapped back to c, and the position is burned and re-minted on
[c - n, c + n). Deployed liquidity L_end / L_start is compared with 1 - sinh^2(eta/2)/sinh^2(nu/2), eta = t ln(1.0001)/2,
nu = n ln(1.0001)/2 (zero for |t| >= n). Control protocol: out and back with no re-minting (path independence at fixed
range). Writes out/excursion_rows.csv."""
import os, sys, math, itertools
import pandas as pd
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import v3math as V
from siphon_ref import centre_of
OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), 'out'); os.makedirs(OUT, exist_ok=True)
Q128 = V.Q128; LN = math.log(1.0001)

def move(pool, target_tick, pos):
    """Exact-input swap to sqrt_at_tick(target_tick); returns fees owed to pos (token0, token1) by V3 fee growth."""
    lim = V.sqrt_at_tick(target_tick); zfo = lim < pool.s
    if lim == pool.s:
        return 0, 0
    sa, sb = V.sqrt_at_tick(pos['tl']), V.sqrt_at_tick(pos['tu'])
    rem = 1 << 200; g = 0
    while rem != 0 and pool.s != lim:
        s_start = pool.s
        t_next, init = pool._next_init(zfo); t_next = max(V.MIN_TICK, min(V.MAX_TICK, t_next))
        snt = V.sqrt_at_tick(t_next)
        tgt = (lim if snt < lim else snt) if zfo else (lim if snt > lim else snt)
        sn, ai, ao, fa = V.compute_swap_step(pool.s, tgt, pool.L, rem, pool.fee)
        inside = (sa <= min(s_start, sn)) and (max(s_start, sn) <= sb) and pos['L'] > 0 and pool.L > 0
        if inside and fa > 0:
            g += V.mul_div(fa, Q128, pool.L)
        pool.s = sn; rem -= ai + fa
        if pool.s == snt:
            if init:
                nn = pool.net[t_next]; pool.L += -nn if zfo else nn
            pool.tick = t_next - 1 if zfo else t_next
        elif pool.s != s_start:
            pool.tick = V.tick_at_sqrt(pool.s)
    f = V.mul_div(g, pos['L'], Q128)
    return (f, 0) if zfo else (0, f)

def recentre(pool, pos, idle, c, n):
    b0, b1 = V.burn_amounts(pool.tick, pool.s, pos['tl'], pos['tu'], pos['L'])
    pool.modify(pos['tl'], pos['tu'], -pos['L'])
    a0, a1 = b0 + idle[0] + pos['f0'], b1 + idle[1] + pos['f1']; pos['f0'] = pos['f1'] = 0
    tl, tu = c - n, c + n
    L = V.liq_for_amounts(pool.s, V.sqrt_at_tick(tl), V.sqrt_at_tick(tu), a0, a1)
    u0, u1 = V.mint_amounts(pool.tick, pool.s, tl, tu, L) if L > 0 else (0, 0)
    if L > 0: pool.modify(tl, tu, L)
    pos.update(L=L, tl=tl, tu=tu)
    return [a0 - u0, a1 - u1]

def run(sp, h, c0, z, sign, fee, lext_mult, aligned, protocol, L0=10 ** 24):
    n = h * sp; c = (c0 // sp) * sp
    t = round(z * n) if not aligned else round(z * h) * sp
    t *= sign
    if t == 0: return None
    pool = V.Pool(V.sqrt_at_tick(c), 0, sp, fee); pool.tick = c
    lo = (V.MIN_TICK // sp + 1) * sp; hi = (V.MAX_TICK // sp) * sp
    if lext_mult: pool.modify(lo, hi, lext_mult * L0)
    pos = dict(L=L0, tl=c - n, tu=c + n, f0=0, f1=0); pool.modify(c - n, c + n, L0)
    idle = [0, 0]
    f = move(pool, c + t, pos); pos['f0'] += f[0]; pos['f1'] += f[1]
    if protocol == 'excursion':
        idle = recentre(pool, pos, idle, centre_of(c + t, sp), n)
    f = move(pool, c, pos); pos['f0'] += f[0]; pos['f1'] += f[1]
    idle = recentre(pool, pos, idle, c, n)
    eta, nu = t * LN / 2, n * LN / 2
    pred = max(0.0, 1 - math.sinh(eta / 2) ** 2 / math.sinh(nu / 2) ** 2) if protocol == 'excursion' else 1.0
    return dict(sp=sp, h=h, n=n, c=c, z=z, t=t, fee=fee, lext=lext_mult, aligned=aligned, protocol=protocol,
                ratio=pos['L'] / L0, pred=pred, recentre_exact=((c + t) % sp == 0), idle0=idle[0], idle1=idle[1])

if __name__ == '__main__':
    rows = []
    SP = [1, 10, 50, 100, 200]; H = [2, 5, 20, 100]; C0 = [-200000, 0, 80000, 250000]
    Z = [0.05, 0.1, 0.25, 0.5, 0.75, 0.9, 0.99, 1.0, 1.25, 2.0]
    for sp, h, c0, z, sign, fee, lx, al, pr in itertools.product(SP, H, C0, Z, (1, -1), (0, 500, 3000, 10000), (0, 9), (True, False), ('excursion', 'control')):
        if fee == 0 and lx == 9: continue
        r = run(sp, h, c0, z, sign, fee, lx, al, pr)
        if r: rows.append(r)
    d = pd.DataFrame(rows).drop_duplicates(subset=['sp', 'h', 'c', 't', 'fee', 'lext', 'protocol'])
    d['err'] = d.ratio - d.pred; d['rel'] = d.err / d.pred.where(d.pred > 0)
    d.to_csv(f'{OUT}/excursion_rows.csv', index=False)
    print(f'{len(d):,} excursions')
