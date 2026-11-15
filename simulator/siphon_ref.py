"""Portfolio simulator, reference implementation in exact integers (pool arithmetic in v3math).

Model (one chain = one depositor's portfolio):
  tokens      n_tok tokens, equal decimals; token i has a log USD price x_i in ticks (fixed point, 2^-24 tick units)
              x_i += mu_i + sigma_i * Z with Z an Irwin-Hall(12) - 6 integer normal, so a run is reproducible from its seed
  pools       pool k = (tok0, tok1, spacing, fee pips, L_ext). L_ext is the other LPs' liquidity, held full range.
              Each step the arbitrageur sets every pool to its fair tick floor(x_tok0 - x_tok1): sqrtP =
              sqrt_at_tick(fair). No arbitrage swap is simulated; positions earn no fees (gauge-staked).
  positions   position j in pool k: liquidity L_j on [tl, tu), width W_j spacings (even), trigger u_j.
              Rebalance when |tick - centre| >= floor(u_j * half_j), in position order within a step, at the pool's
              current state (an earlier rebalance's swap in the same step moves it).
  rebalance   burn (round down) -> take the portfolio's whole balance of both pool tokens (recycle=1; recycle=0 is
              the isolated case of Theorems 1 and 3: leftover goes to a per-position stash that is never minted)
              -> swap -> mint at the post-swap state -> leftover credited.
  swap modes  0 none; 1 the position manager's swap, amountIn scaled by theta = th_num / 1e6 (theta = 1 is the
              contract), executed in the pool with fee and impact across the tick map (external + positions);
              2 exact: conversion to the required balance at the pre-swap price, no fee, no impact (off pool).
  order       positions are visited in index order each step, or (rot=1) from a uniformly random start, rotating
  cap         cap=1 (shared balance only): the equity cap of Proposition 12. Each mint is limited to the position's
              equity E_j = V_j + C_j less its own swap cost, valued at the marks P_i = (sqrt_at_tick(floor x_i)/2^96)^2
              (the step's fair USD prices on the integer tick); capped-out tokens stay in the shared balance. The
              entitlements C_j are revalued pro rata between events; a draw above a position's own entitlement is a
              transfer, debited pro rata from the others. With cap=0 the same entitlements run as a shadow.
  neutral     recycle=2: the neutral rule applied token by token (integer entitlements per token, exchange of the
              missing token at the pool's pre-transaction price, swap of the position's own amounts after the
              exchange, uncapped mint)
  mode 3      the contract's swap scaled by 1/(1 + rho), rho = estimated new liquidity / pool liquidity after the burn
              (the swap size of Corollary 8.1)
  new range   centre = round-half-away(tick / spacing) * spacing, [centre - half, centre + half).
Event record per rebalance (floats for analysis): see EVENT_FIELDS.
"""
import math
import v3math as V

FP = 1 << 24
QF = 4294967296.0 * 4294967296.0 * 4294967296.0
EVENT_FIELDS = ['step', 'pos', 'pool', 'tick_pre', 'c_old', 'half', 'V_pre', 'V_post', 'alpha', 'swapped', 'side',
                'du0', 'du1', 'swap_cost', 'W_tot']
M64 = (1 << 64) - 1
EXT_FIELDS = ['step', 'pos', 'pool', 'swapped', 'w0_bundle', 'w0_req', 'w0_own', 'V_own', 'V_bundle', 'm_own', 'bal0', 'bal1',
              'cover', 'L_old', 'L_new', 'Lp_incl', 'Lp_ex', 'beta', 'limit_hit', 'cap_hit', 'paid_t1', 'swapcost_mark', 'V_mark', 'mark0', 'mark1',
              'left0_val', 'left1_val', 'zfo', 'side', 'xi']

class RNG:
    def __init__(self, seed):
        self.s = seed & M64
    def next(self):
        self.s = (self.s + 0x9E3779B97F4A7C15) & M64
        z = self.s
        z = ((z ^ (z >> 30)) * 0xBF58476D1CE4E5B9) & M64
        z = ((z ^ (z >> 27)) * 0x94D049BB133111EB) & M64
        return z ^ (z >> 31)
    def z_fixed(self):
        """Irwin-Hall(12) - 6 in 2^-24 units: sum of twelve 24-bit uniforms minus 6 * 2^24."""
        return sum(self.next() >> 40 for _ in range(12)) - 6 * FP

def floor_div(a, b):
    return a // b

def centre_of(tick, sp):
    # round half away from zero of tick / sp, in integers
    q, r = divmod(abs(tick), sp)
    q += 1 if 2 * r >= sp else 0
    return (q if tick >= 0 else -q) * sp

def amounts_f(L, tl, tu, s):
    """Float token amounts of liquidity L on [tl, tu) at sqrt price s (X96 int) -- measurement only."""
    sa, sb = V.sqrt_at_tick(tl), V.sqrt_at_tick(tu)
    sc = min(max(s, sa), sb)
    Q = float(V.Q96)
    return L * (1.0 / (sc / Q) - 1.0 / (sb / Q)), L * ((sc - sa) / Q)

class Chain:
    def __init__(self, cfg, seed):
        self.c = cfg
        self.rng = RNG(seed)
        self.x = [int(v * FP) for v in cfg['x0']]                      # token log prices, fixed point ticks
        self.pools = []
        for p in cfg['pools']:
            ft = self.fair_tick(p)
            pool = V.Pool(V.sqrt_at_tick(ft), 0, p['sp'], p['fee'])
            pool.tick = ft
            lo = (V.MIN_TICK // p['sp'] + 1) * p['sp']; hi = (V.MAX_TICK // p['sp']) * p['sp']
            pool.modify(lo, hi, p['L_ext'])
            self.pools.append(pool)
        self.pos = []
        for q in cfg['positions']:
            pool = self.pools[q['pool']]; sp = cfg['pools'][q['pool']]['sp']
            half = q['W'] * sp // 2
            c = centre_of(pool.tick, sp)
            d = dict(pool=q['pool'], half=half, thr=int(q['u'] * half), tl=c - half, tu=c + half, c=c, L=q['L'],
                     stash=[0, 0])
            pool.modify(d['tl'], d['tu'], d['L'])
            self.pos.append(d)
        self.dust = [0] * len(cfg['x0'])
        self.events = []
        # entitlements of Proposition 12. Always kept,
        # as a shadow when the cap is off (cfg['cap'] = 0) and as the rule when it is on (cfg['cap'] = 1).
        npos = len(cfg['positions'])
        self.claims = [0.0] * npos; self.Plast = 0.0
        self.acc = dict(tau=0.0, short=0.0, unattrib=0.0, notional=0.0, swapcost=0.0, capped=0,
                        tau_in=[0.0] * npos, tau_out=[0.0] * npos)
        self.ext = [] if cfg.get('ext') else None
        # neutral rule applied token by token: integer entitlements per token, recycle = 2
        self.tclaims = [[0] * len(cfg['x0']) for _ in range(npos)]
        self.acc.update(xchg_val=0.0, xchg_n=0, xcheck=0.0, xcheck_maxrel=0.0, draw_cap_long=0)
        # token provenance by pool, measurement only, prov = 1
        npool = len(cfg['pools'])
        self.prov = [dict() for _ in cfg['x0']] if cfg.get('prov') else None
        self.ptau_in = [[0.0, 0.0] for _ in range(npool)]; self.ptau_out = [[0.0, 0.0] for _ in range(npool)]
        self.pgross_own = [[0.0, 0.0] for _ in range(npool)]; self.pgross_all = [[0.0, 0.0] for _ in range(npool)]
        self.prov_err = 0
        self._xi = float('nan')
        self.step_no = 0

    def fair_tick(self, p):
        return floor_div(self.x[p['t0']] - self.x[p['t1']], FP)

    def mark(self, i):
        """USD mark of token i for the neutral rule: (sqrt_at_tick(floor x_i) / 2^96)^2."""
        q = V.sqrt_at_tick(self.x[i] >> 24) / QF
        return q * q

    def bal_value(self):
        v = 0.0
        for i in range(len(self.dust)):
            v += float(self.dust[i]) * self.mark(i)
        return v

    def usd(self, a0, a1, p):
        P0 = 1.0001 ** (self.x[p['t0']] / FP); P1 = 1.0001 ** (self.x[p['t1']] / FP)
        return a0 * P0 + a1 * P1

    def step(self):
        c = self.c
        for i in range(len(self.x)):
            self.x[i] += c['mu'][i] + (c['sig'][i] * self.rng.z_fixed()) // FP
        for k, p in enumerate(c['pools']):
            pool = self.pools[k]; ft = self.fair_tick(p)
            ft = max(V.MIN_TICK + 1, min(V.MAX_TICK - 1, ft))
            if ft != pool.tick or pool.s != V.sqrt_at_tick(ft):
                pool.s = V.sqrt_at_tick(ft); pool.tick = ft
                pool.L = sum(n for t, n in pool.net.items() if t <= ft)
        n = len(self.pos); off = self.rng.next() % n if c.get('rot') else 0
        for jj in range(n):
            j = (jj + off) % n; d = self.pos[j]
            pool = self.pools[d['pool']]
            if abs(pool.tick - d['c']) >= d['thr']:
                self.rebalance(j)
        self.step_no += 1

    def rebalance(self, j):
        c = self.c; d = self.pos[j]; k = d['pool']; p = c['pools'][k]; pool = self.pools[k]; sp = p['sp']
        t0, t1 = p['t0'], p['t1']
        s0, tk0 = pool.s, pool.tick
        b0, b1 = V.burn_amounts(tk0, s0, d['tl'], d['tu'], d['L'])
        self._Lp_before = pool.L
        pool.modify(d['tl'], d['tu'], -d['L'])
        side = 0 if d['tl'] <= tk0 < d['tu'] else (1 if tk0 >= d['tu'] else -1)
        V_pre = self.usd(b0, b1, p)
        ex0, ex1 = amounts_f(d['L'], d['tl'], d['tu'], s0)
        cl = self.claims; acc = self.acc
        if c['recycle'] == 1:
            Pb = self.bal_value(); S = 0.0
            for v in cl: S += v
            if self.Plast > 0 and S > 0:
                f = Pb / self.Plast
                for i in range(len(cl)): cl[i] *= f
            elif Pb > 0:
                acc['unattrib'] += Pb - S
            self.Plast = Pb
        m0, m1 = self.mark(t0), self.mark(t1)
        Vj = float(b0) * m0 + float(b1) * m1; Cj = cl[j]
        if c['recycle'] == 1:
            a0, a1 = b0 + self.dust[t0], b1 + self.dust[t1]
            db0, db1 = self.dust[t0], self.dust[t1]
            if self.prov is not None:
                self._prov_draw(k, p, m0, m1)
            self.dust[t0] = 0; self.dust[t1] = 0
        elif c['recycle'] == 2:
            tc = self.tclaims; db0, db1 = tc[j][t0], tc[j][t1]
            a0, a1 = b0 + db0, b1 + db1
            tc[j][t0] = 0; tc[j][t1] = 0; self.dust[t0] -= db0; self.dust[t1] -= db1
        else:
            a0, a1, db0, db1 = b0, b1, 0, 0
        cnew = centre_of(tk0, sp); tl, tu = cnew - d['half'], cnew + d['half']
        # zero-swap residual fraction of the withdrawn principal alone, at s0 (Lemma 7.1 alpha)
        Lz = V.liq_for_amounts(s0, V.sqrt_at_tick(tl), V.sqrt_at_tick(tu), b0, b1)
        z0, z1 = V.mint_amounts(tk0, s0, tl, tu, Lz) if Lz > 0 else (0, 0)
        alpha = 1.0 - (self.usd(z0, z1, p) / V_pre) if V_pre > 0 else 0.0
        if c['recycle'] == 2:
            a0, a1 = self._exchange(j, t0, t1, a0, a1, s0, tk0, tl, tu, m0, m1)
        swapped, cost, cost_m = 0, 0.0, 0.0
        self._swapinfo = None; self._xi = float('nan')
        bund0, bund1 = a0, a1
        mode = c['mode']
        if mode in (1, 3):
            amt, zfo, lim, why = V.auto_swap_decision(a0, a1, s0, tk0, tl, tu)
            amt = amt * c['th_num'] // 1_000_000
            if mode == 3 and amt > 0:
                # xi0 = 1/(1 + rho), rho = L_new estimate / pool liquidity after the burn (Corollary 8.1)
                P = (s0 / QF) ** 2; f0, f1 = amounts_f(1, tl, tu, s0); phi = f0 * P + f1
                Lhat = (a0 * P + a1) / phi if phi > 0 else 0.0
                rho = Lhat / pool.L if pool.L > 0 else float('inf')
                xi = 1.0 / (1.0 + rho); self._xi = xi
                amt = amt * int(xi * 1_000_000) // 1_000_000
            if amt > 0:
                q0, q1 = pool.swap(zfo, amt, lim)
                cost = self.usd(q0, q1, p)                    # value paid into the pool minus received, at fair USD
                a0 -= q0; a1 -= q1; swapped = 1
                if zfo:
                    acc['notional'] += float(q0) * m0; cm = float(q0) * m0 - float(-q1) * m1
                else:
                    acc['notional'] += float(q1) * m1; cm = float(q1) * m1 - float(-q0) * m0
                acc['swapcost'] += cm; cost_m = cm
                if self.ext is not None:
                    self._swapinfo = (zfo, amt, lim, q0, q1)
        elif mode == 2:
            x0, x1 = perfect_swap(a0, a1, s0, tk0, tl, tu)
            if x0 != 0 or x1 != 0:
                a0 += x0; a1 += x1; swapped = 1
        Lm = V.liq_for_amounts(pool.s, V.sqrt_at_tick(tl), V.sqrt_at_tick(tu), a0, a1)
        if c.get('cap') and c['recycle'] == 1:
            Ecap = Vj + Cj - cost_m
            f0, f1 = amounts_f(1, tl, tu, pool.s); phi = f0 * m0 + f1 * m1
            Lcap = int(Ecap / phi) if (Ecap > 0 and phi > 0) else 0
            if Lcap < Lm:
                Lm = Lcap; acc['capped'] += 1
        u0, u1 = V.mint_amounts(pool.tick, pool.s, tl, tu, Lm) if Lm > 0 else (0, 0)
        pool.modify(tl, tu, Lm)
        l0, l1 = a0 - u0, a1 - u1
        if c['recycle'] == 2:
            self.tclaims[j][t0] = l0; self.tclaims[j][t1] = l1; self.dust[t0] += l0; self.dust[t1] += l1
        elif c['recycle'] == 1:
            self.dust[t0] += l0; self.dust[t1] += l1
            if self.prov is not None:
                for tkn, lk in ((t0, l0), (t1, l1)):
                    self.prov[tkn] = {k: lk} if lk > 0 else {}
            I = float(db0 - l0) * m0 + float(db1 - l1) * m1
            if I <= Cj:
                cl[j] = Cj - I
            else:
                tau = I - Cj; cl[j] = 0.0; O = 0.0
                for i in range(len(cl)):
                    if i != j: O += cl[i]
                if O > 0:
                    f = tau / O
                    if f > 1.0: f = 1.0
                    for i in range(len(cl)):
                        if i != j:
                            dd = cl[i] * f; cl[i] -= dd; acc['tau_out'][i] += dd
                    if tau > O: acc['short'] += tau - O
                else:
                    acc['short'] += tau
                acc['tau_in'][j] += tau; acc['tau'] += tau
            self.Plast = self.bal_value()
        else:
            d['stash'][0] += l0; d['stash'][1] += l1
        # value of the new position at the pre-rebalance price s0, same USD prices
        n0, n1 = amounts_f(Lm, tl, tu, s0)
        V_post = self.usd(n0, n1, p)
        W_tot = self.wealth()
        self.events.append((self.step_no, j, k, tk0, d['c'], d['half'], V_pre, V_post, alpha, swapped, side,
                            self.usd(l0 - db0, 0, p), self.usd(0, l1 - db1, p), cost, W_tot))
        if self.ext is not None:
            self._ext(j, k, p, s0, tk0, b0, b1, db0, db1, bund0, bund1, a0, a1, l0, l1, tl, tu, d, Lm, m0, m1, Vj, cost_m)
        d.update(L=Lm, tl=tl, tu=tu, c=cnew)

    def _prov_draw(self, k, p, m0, m1):
        """Contract recycling takes every unit of both pool tokens: book the other pools' shares as drawn by pool k."""
        pools = self.c['pools']
        for idx, tkn, mk in ((0, p['t0'], m0), (1, p['t1'], m1)):
            own = self.prov[tkn]
            if sum(own.values()) != self.dust[tkn]: self.prov_err += 1
            oth = 0
            for q, v in own.items():
                if q == k: continue
                oth += v; iq = 0 if pools[q]['t0'] == tkn else 1
                self.ptau_out[q][iq] += v * mk
            self.ptau_in[k][idx] += oth * mk
            self.pgross_own[k][idx] += own.get(k, 0) * mk; self.pgross_all[k][idx] += (oth + own.get(k, 0)) * mk

    def _exchange(self, j, t0, t1, a0, a1, s0, tk0, tl, tu, m0, m1):
        """Neutral rule, exchange step: draw c = min(m, A) of the short token from the others' claims at the pool's
        pre-transaction sqrt price s0, giving the long token of equal value; drawn rounded down, given rounded up; pro rata
        rounded down with the remainder from the largest claim."""
        tc = self.tclaims; acc = self.acc; n = len(tc)
        P = (s0 / QF) ** 2; sf = s0 / QF; sa, sb = V.sqrt_at_tick(tl) / QF, V.sqrt_at_tick(tu) / QF
        if tk0 < tl: w0p = 1.0
        elif tk0 >= tu: w0p = 0.0
        else:
            ax, ay = 1 / sf - 1 / sb, sf - sa; w0p = ax * P / (ax * P + ay)
        Vh = a0 * P + a1
        if Vh <= 0: return a0, a1
        m = (w0p - a0 * P / Vh) * Vh                    # token1 units at s0; > 0: short of token0
        if m > 0:
            short, longt, need, have_long = t0, t1, int(m / P), a1
            to_long = lambda d: V.mul_div_up(V.mul_div_up(d, s0, V.Q96), s0, V.Q96)
            max_short_for = lambda g: V.mul_div(V.mul_div(g, V.Q96, s0), V.Q96, s0)
        elif m < 0:
            short, longt, need, have_long = t1, t0, int(-m), a0
            to_long = lambda d: V.mul_div_up(V.mul_div_up(d, V.Q96, s0), V.Q96, s0)
            max_short_for = lambda g: V.mul_div(V.mul_div(g, s0, V.Q96), s0, V.Q96)
        else:
            return a0, a1
        others = [i for i in range(n) if i != j and tc[i][short] > 0]
        A = sum(tc[i][short] for i in others)
        draw = min(need, A)
        if draw <= 0: return a0, a1
        give = to_long(draw)
        if give > have_long:
            draw = min(draw, max_short_for(have_long)); give = to_long(draw); acc['draw_cap_long'] += 1
            if draw <= 0 or give > have_long: return a0, a1
        red = {i: draw * tc[i][short] // A for i in others}
        big = max(others, key=lambda i: (tc[i][short], -i)); red[big] += draw - sum(red.values())
        gv = {i: give * red[i] // draw for i in others}
        bigr = max(others, key=lambda i: (red[i], -i)); gv[bigr] += give - sum(gv.values())
        for i in others:
            tc[i][short] -= red[i]; tc[i][longt] += gv[i]
        self.dust[short] -= draw; self.dust[longt] += give
        # the others' net exchange value at s0 (token1 units), >= 0 by the rounding rule
        if short == t0:
            gain = give - draw * P; a0 += draw; a1 -= give
        else:
            gain = give * P - draw; a1 += draw; a0 -= give
        acc['xcheck'] += gain; acc['xchg_n'] += 1
        acc['xchg_val'] += (draw * (m0 if short == t0 else m1))
        rel = abs(gain) / Vh
        if rel > acc['xcheck_maxrel']: acc['xcheck_maxrel'] = rel
        return a0, a1

    def _ext(self, j, k, p, s0, tk0, b0, b1, db0, db1, bund0, bund1, a0, a1, l0, l1, tl, tu, d, Lm, m0, m1, Vj, cost_m):
        """Extended per-event record for Sims 7 and 9 (floats; measurement only); fields in EXT_FIELDS."""
        pool = self.pools[k]; P = (s0 / QF) ** 2; Pm = (pool.s / QF) ** 2
        sa, sb = V.sqrt_at_tick(tl) / QF, V.sqrt_at_tick(tu) / QF; sf = s0 / QF
        if tk0 < tl: w0p = 1.0
        elif tk0 >= tu: w0p = 0.0
        else:
            ax, ay = 1 / sf - 1 / sb, sf - sa; w0p = ax * P / (ax * P + ay)
        Vb = bund0 * P + bund1; w0b = bund0 * P / Vb if Vb > 0 else 0.5
        Vo = b0 * P + b1; w0o = b0 * P / Vo if Vo > 0 else 0.5
        # own residual vector (token1 units at s0): shortfall of token0 if w0p > w0o
        m_own = (w0p - w0o) * Vo
        bal0, bal1 = db0 * P, float(db1)
        cover = min(abs(m_own), bal0 if m_own > 0 else bal1)
        Lp_incl = self._Lp_before; Lp_ex = Lp_incl - (d['L'] if d['tl'] <= tk0 < d['tu'] else 0)
        si = self._swapinfo
        lim_hit = cap_hit = 0
        if si is not None:
            zfo, amt, lim, q0, q1 = si
            lim_hit = int(pool.s == lim)
            mx = V.mul_div(bund0 if zfo else bund1, V.MAX_SWAP_BPS, 10000); cap_hit = int(amt == mx)
        Va = a0 * Pm + a1; beta = (l0 * Pm + l1) / Va if Va > 0 else float('nan')
        self.ext.append((self.step_no, j, k, int(si is not None), w0b, w0p, w0o, Vo, Vb, m_own, bal0, bal1, cover,
                         float(d['L']), float(Lm), float(Lp_incl), float(Lp_ex), beta, lim_hit, cap_hit,
                         ((si[3] * P) if si[0] else float(si[4])) if si else 0.0, cost_m, Vj, m0, m1,
                         l0 * Pm, float(l1), (int(si[0]) if si else -1), (0 if d['tl'] <= tk0 < d['tu'] else (1 if tk0 >= d['tu'] else -1)), self._xi))

    def pos_value(self, j):
        d = self.pos[j]; p = self.c['pools'][d['pool']]; pool = self.pools[d['pool']]
        a0, a1 = amounts_f(d['L'], d['tl'], d['tu'], pool.s)
        return self.usd(a0, a1, p) + self.usd(d['stash'][0], d['stash'][1], p)

    def wealth(self):
        tot = sum(self.pos_value(j) for j in range(len(self.pos)))
        for i, a in enumerate(self.dust):
            tot += a * 1.0001 ** (self.x[i] / FP)
        return tot

    def int_state(self):
        return (tuple(self.x), tuple((d['L'], d['tl'], d['tu'], d['stash'][0], d['stash'][1]) for d in self.pos),
                tuple(self.dust), tuple((pl.s, pl.tick, pl.L) for pl in self.pools))

def perfect_swap(a0, a1, s, tick, tl, tu):
    """Exact-balance conversion at price s with no fee: token deltas (x0, x1) making the bundle match the range's
    requirement at s. Sized in IEEE double (basic operations only), executed in integers."""
    if tick < tl or tick >= tu:
        # single-sided target: convert everything to the required token
        if tick < tl:
            return V.mul_div(V.mul_div(a1, V.Q96, s), V.Q96, s), -a1  # all token1 -> token0
        return -a0, V.mul_div(V.mul_div(a0, s, V.Q96), s, V.Q96)      # all token0 -> token1
    Q = 4294967296.0 * 4294967296.0 * 4294967296.0                     # 2^96
    sf = s / Q; sa = V.sqrt_at_tick(tl) / Q; sb = V.sqrt_at_tick(tu) / Q
    r0 = 1.0 / sf - 1.0 / sb; r1 = sf - sa; P = sf * sf
    # sell x of token0 (x may be negative): (a0 - x) / r0 = (a1 + x P) / r1  ->  x = (a0 r1 - a1 r0) / (r1 + P r0)
    xf = (float(a0) * r1 - float(a1) * r0) / (r1 + P * r0)
    if xf >= 0:
        x0 = min(int(xf), a0)
        return -x0, V.mul_div(V.mul_div(x0, s, V.Q96), s, V.Q96)
    y = min(int(-xf * P), a1)                                          # token1 sold
    return V.mul_div(V.mul_div(y, V.Q96, s), V.Q96, s), -y
