#!/usr/bin/env python3
"""Small example: four positions of sizes 1 : 2 : 3 : 4 in one pool, under three settings.

  contract swap, shared balance     the position manager's internal swap, leftovers pooled with no owner
  exact swap, shared balance        a swap that matches the new range exactly at no cost, so nothing is left over
  no swap, isolated balances        the zero-swap case of Theorem 3, each position keeping its own leftover

Prints each position's share of the portfolio's deployed value at the start and at the end, and the number of
rebalances. Standard library only; runs in a few seconds.
"""
import siphon_ref as S

STEPS = 60_000
WIDTH = 10            # range width in tick spacings
SIGMA = 0.05          # price step, as a fraction of the half-width
SHARE = 0.01          # positions' liquidity over the rest of the pool's
SIZES = [1, 2, 3, 4]
UNIT = 10 ** 20

ARMS = [
    ('contract swap, shared balance', dict(mode=1, th_num=1_000_000, recycle=1)),
    ('exact swap, shared balance', dict(mode=2, th_num=0, recycle=1)),
    ('no swap, isolated balances', dict(mode=0, th_num=0, recycle=0)),
]


def config(arm):
    half = WIDTH * 10 / 2
    liquidity = [UNIT * w for w in SIZES]
    cfg = dict(x0=[80000.0, 0.0], mu=[0, 0], sig=[int(SIGMA * half * S.FP), 0],
               pools=[dict(t0=0, t1=1, sp=10, fee=500, L_ext=int(sum(liquidity) / SHARE))],
               positions=[dict(pool=0, W=WIDTH, u=0.9, L=L) for L in liquidity], rot=1)
    cfg.update(arm)
    return cfg


def deployed(chain):
    out = []
    for j, d in enumerate(chain.pos):
        pool = chain.pools[d['pool']]
        a0, a1 = S.amounts_f(d['L'], d['tl'], d['tu'], pool.s)
        out.append(chain.usd(a0, a1, chain.c['pools'][d['pool']]))
    return out


def shares(values):
    total = sum(values)
    return ['   n/a' if total == 0 else f'{v / total:6.3f}' for v in values]


if __name__ == '__main__':
    for name, arm in ARMS:
        chain = S.Chain(config(arm), seed=1)
        start = deployed(chain)
        for _ in range(STEPS):
            chain.step()
        end = deployed(chain)
        print(name)
        print('  share of deployed value, start:', ' '.join(shares(start)))
        print('  share of deployed value, end:  ', ' '.join(shares(end)))
        print(f'  deployed value, end over start: {sum(end) / sum(start):.4f}; rebalances: {len(chain.events):,}')
