"""Exact integer port of the Uniswap V3 / Aerodrome Slipstream core arithmetic and of the position manager's
internal swap rule.

Every function mirrors the Solidity function it is named for, with Python's unbounded integers standing in for
uint256 and explicit floor and ceiling where Solidity rounds.
  TickMath, FullMath            Uniswap v3-core 1.0.0 constants
  SqrtPriceMath, SwapMath,      Uniswap v3-core 1.0.0 (Slipstream's pool uses the same libraries)
  LiquidityAmounts, pool swap
  target ratio, current ratio,  the position manager's swap sizing (PMV9 in the paper), with its two parameters
  swap amount                   SKIP_SWAP_THRESHOLD_BPS = 200 and MAX_SWAP_BPS = 9000
Nothing here reads data.
"""
Q96 = 1 << 96
Q128 = 1 << 128
MIN_TICK, MAX_TICK = -887272, 887272
MIN_SQRT_RATIO = 4295128739
MAX_SQRT_RATIO = 1461446703485210103287273052203988822378723970342
U256 = (1 << 256) - 1
SKIP_SWAP_THRESHOLD_BPS = 200
MAX_SWAP_BPS = 9000

# ---------------------------------------------------------------- FullMath
def mul_div(a, b, d):
    r = a * b // d
    assert r <= U256
    return r

def mul_div_up(a, b, d):
    r = -((-a * b) // d)
    assert r <= U256
    return r

def div_up(a, b):
    return -((-a) // b)

# ---------------------------------------------------------------- TickMath
_C = [0xfff97272373d413259a46990580e213a, 0xfff2e50f5f656932ef12357cf3c7fdcc, 0xffe5caca7e10e4e61c3624eaa0941cd0,
      0xffcb9843d60f6159c9db58835c926644, 0xff973b41fa98c081472e6896dfb254c0, 0xff2ea16466c96a3843ec78b326b52861,
      0xfe5dee046a99a2a811c461f1969c3053, 0xfcbe86c7900a88aedcffc83b479aa3a4, 0xf987a7253ac413176f2b074cf7815e54,
      0xf3392b0822b70005940c7a398e4b70f3, 0xe7159475a2c29b7443b29c7fa6e889d9, 0xd097f3bdfd2022b8845ad8f792aa5825,
      0xa9f746462d870fdf8a65dc1f90e061e5, 0x70d869a156d2a1b890bb3df62baf32f7, 0x31be135f97d08fd981231505542fcfa6,
      0x9aa508b5b7a84e1c677de54f3e99bc9, 0x5d6af8dedb81196699c329225ee604, 0x2216e584f5fa1ea926041bedfe98,
      0x48a170391f7dc42444e8fa2]
_SQ_CACHE = {}

def sqrt_at_tick(tick):
    v = _SQ_CACHE.get(tick)
    if v is not None:
        return v
    a = abs(tick)
    assert a <= MAX_TICK
    ratio = 0xfffcb933bd6fad37aa2d162d1a594001 if a & 1 else 0x100000000000000000000000000000000
    for i, c in enumerate(_C):
        if a & (2 << i):
            ratio = (ratio * c) >> 128
    if tick > 0:
        ratio = U256 // ratio
    v = (ratio >> 32) + (0 if ratio % (1 << 32) == 0 else 1)
    if len(_SQ_CACHE) < 2_000_000:
        _SQ_CACHE[tick] = v
    return v

def tick_at_sqrt(s):
    """Greatest tick with sqrt_at_tick(tick) <= s. This is the specification of V3 getTickAtSqrtRatio
    (its msb/log2 routine is proven to return exactly this); implemented by bisection."""
    assert MIN_SQRT_RATIO <= s < MAX_SQRT_RATIO
    lo, hi = MIN_TICK, MAX_TICK
    while lo < hi:
        mid = (lo + hi + 1) >> 1
        if sqrt_at_tick(mid) <= s:
            lo = mid
        else:
            hi = mid - 1
    return lo

# ---------------------------------------------------------------- SqrtPriceMath
def amount0_delta(sa, sb, L, up):
    if sa > sb:
        sa, sb = sb, sa
    n1, n2 = L << 96, sb - sa
    assert sa > 0
    if up:
        return div_up(mul_div_up(n1, n2, sb), sa)
    return mul_div(n1, n2, sb) // sa

def amount1_delta(sa, sb, L, up):
    if sa > sb:
        sa, sb = sb, sa
    return mul_div_up(L, sb - sa, Q96) if up else mul_div(L, sb - sa, Q96)

def next_sqrt_from_amount0_up(s, L, amount, add):
    if amount == 0:
        return s
    n1 = L << 96
    if add:
        product = amount * s
        if product // amount == s and product <= U256:
            den = n1 + product
            if den >= n1 and den <= U256:
                return mul_div_up(n1, s, den)
        return div_up(n1, n1 // s + amount)
    product = amount * s
    assert product // amount == s and n1 > product
    return mul_div_up(n1, s, n1 - product)

def next_sqrt_from_amount1_down(s, L, amount, add):
    if add:
        q = (amount << 96) // L if amount <= (1 << 160) - 1 else mul_div(amount, Q96, L)
        return s + q
    q = div_up(amount << 96, L) if amount <= (1 << 160) - 1 else mul_div_up(amount, Q96, L)
    assert s > q
    return s - q

def next_sqrt_from_input(s, L, amount_in, zero_for_one):
    assert s > 0 and L > 0
    return next_sqrt_from_amount0_up(s, L, amount_in, True) if zero_for_one else next_sqrt_from_amount1_down(s, L, amount_in, True)

# ---------------------------------------------------------------- SwapMath (exact input only; the position manager never swaps exact output)
def compute_swap_step(s, s_target, L, amount_remaining, fee_pips):
    zfo = s >= s_target
    less_fee = mul_div(amount_remaining, 1_000_000 - fee_pips, 1_000_000)
    amount_in = amount0_delta(s_target, s, L, True) if zfo else amount1_delta(s, s_target, L, True)
    s_next = s_target if less_fee >= amount_in else next_sqrt_from_input(s, L, less_fee, zfo)
    mx = s_target == s_next
    if zfo:
        if not mx:
            amount_in = amount0_delta(s_next, s, L, True)
        amount_out = amount1_delta(s_next, s, L, False)
    else:
        if not mx:
            amount_in = amount1_delta(s, s_next, L, True)
        amount_out = amount0_delta(s, s_next, L, False)
    fee = amount_remaining - amount_in if s_next != s_target else mul_div_up(amount_in, fee_pips, 1_000_000 - fee_pips)
    return s_next, amount_in, amount_out, fee

# ---------------------------------------------------------------- LiquidityAmounts (periphery)
def liq_for_amount0(sa, sb, a0):
    if sa > sb:
        sa, sb = sb, sa
    return mul_div(a0, mul_div(sa, sb, Q96), sb - sa)

def liq_for_amount1(sa, sb, a1):
    if sa > sb:
        sa, sb = sb, sa
    return mul_div(a1, Q96, sb - sa)

def liq_for_amounts(s, sa, sb, a0, a1):
    if s <= sa:
        L = liq_for_amount0(sa, sb, a0)
    elif s < sb:
        L = min(liq_for_amount0(s, sb, a0), liq_for_amount1(sa, s, a1))
    else:
        L = liq_for_amount1(sa, sb, a1)
    assert L < Q128
    return L

def mint_amounts(tick, s, tl, tu, L):
    """CLPool._modifyPosition for a positive liquidity delta (rounds up). Uses slot0.tick for the branch."""
    sa, sb = sqrt_at_tick(tl), sqrt_at_tick(tu)
    if tick < tl:
        return amount0_delta(sa, sb, L, True), 0
    if tick < tu:
        return amount0_delta(s, sb, L, True), amount1_delta(sa, s, L, True)
    return 0, amount1_delta(sa, sb, L, True)

def burn_amounts(tick, s, tl, tu, L):
    """Negative liquidity delta: amounts round down."""
    sa, sb = sqrt_at_tick(tl), sqrt_at_tick(tu)
    if tick < tl:
        return amount0_delta(sa, sb, L, False), 0
    if tick < tu:
        return amount0_delta(s, sb, L, False), amount1_delta(sa, s, L, False)
    return 0, amount1_delta(sa, sb, L, False)

def nfpm_mint(tick, s, tl, tu, a0, a1):
    """NonfungiblePositionManager.mint -> LiquidityManagement.addLiquidity -> pool.mint. Returns (L, used0, used1)."""
    L = liq_for_amounts(s, sqrt_at_tick(tl), sqrt_at_tick(tu), a0, a1)
    if L == 0:
        return 0, 0, 0
    u0, u1 = mint_amounts(tick, s, tl, tu, L)
    assert u0 <= a0 and u1 <= a1, "mint would revert (amount desired exceeded)"
    return L, u0, u1

# ---------------------------------------------------------------- The position manager's swap decision (pure functions)
def target_ratio(tick, tl, tu):
    if tick < tl:
        return 10000, False
    if tick >= tu:
        return 0, False
    sp, sl, su = sqrt_at_tick(tick), sqrt_at_tick(tl), sqrt_at_tick(tu)
    v0 = mul_div(su - sp, sp, su)
    tot = v0 + (sp - sl)
    if tot == 0:
        return 5000, True
    return mul_div(v0, 10000, tot), True

def current_ratio(a0, a1, s):
    v0 = mul_div(mul_div(a0, s, Q96), s, Q96)
    tot = v0 + a1
    return 5000 if tot == 0 else mul_div(v0, 10000, tot)

def swap_amount(a0, a1, s, cur, tgt, zfo):
    v0 = mul_div(mul_div(a0, s, Q96), s, Q96)
    tot = v0 + a1
    dv = mul_div(tot, abs(cur - tgt), 10000)
    if zfo:
        return 0 if s == 0 else mul_div(mul_div(dv, Q96, s), Q96, s)
    return dv

def auto_swap_decision(a0, a1, s, tick, tl, tu):
    """Returns (amount_in, zero_for_one, sqrt_limit, reason). amount_in == 0 means no swap."""
    tgt, needs = target_ratio(tick, tl, tu)
    if not needs:
        return 0, None, None, 'out-of-range-target'
    if a0 == 0 and a1 == 0:
        return 0, None, None, 'empty'
    cur = current_ratio(a0, a1, s)
    if abs(cur - tgt) < SKIP_SWAP_THRESHOLD_BPS:
        return 0, None, None, 'skip<200bps'
    zfo = cur > tgt
    amt = swap_amount(a0, a1, s, cur, tgt, zfo)
    mx = mul_div(a0 if zfo else a1, MAX_SWAP_BPS, 10000)
    amt = min(amt, mx)
    if amt == 0:
        return 0, None, None, 'zero'
    if zfo:
        lim = max(mul_div(s, 9900, 10000), 4295128740)
    else:
        lim = min(mul_div(s, 10100, 10000), 1461446703485210103287273052203988822378723970341)
    return amt, zfo, lim, 'swap'

# ---------------------------------------------------------------- pool swap over a tick map (exact input)
class Pool:
    """Minimal Slipstream/V3 pool: sqrt price, tick, active liquidity, tick map of liquidityNet.
    Fees are charged in the swap maths; fee growth is not tracked (the positions modelled are gauge-staked and earn none)."""
    def __init__(self, s, liquidity, spacing, fee_pips, net=None):
        self.s, self.tick, self.L, self.sp, self.fee = s, tick_at_sqrt(s), liquidity, spacing, fee_pips
        self.net = dict(net or {})

    def modify(self, tl, tu, dL):
        """Add (dL > 0) or remove liquidity on [tl, tu); updates the tick map and active liquidity."""
        for t, d in ((tl, dL), (tu, -dL)):
            v = self.net.get(t, 0) + d
            if v == 0:
                self.net.pop(t, None)
            else:
                self.net[t] = v
        if tl <= self.tick < tu:
            self.L += dL
        assert self.L >= 0

    def _next_init(self, lte):
        """TickBitmap.nextInitializedTickWithinOneWord, on the sorted keys of the tick map."""
        sp = self.sp
        comp = self.tick // sp
        if lte:
            word = comp >> 8
            lo_t = (word << 8) * sp
            cands = [t for t in self.net if lo_t <= t <= comp * sp]
            return (max(cands), True) if cands else (lo_t, False)
        comp += 1
        word = comp >> 8
        hi_t = ((word << 8) + 255) * sp
        cands = [t for t in self.net if comp * sp <= t <= hi_t]
        return (min(cands), True) if cands else (hi_t, False)

    def swap(self, zfo, amount_in, limit):
        """Exact-input swap. Returns (amount0, amount1) pool-side (positive = paid into the pool)."""
        assert (limit < self.s and limit > MIN_SQRT_RATIO) if zfo else (limit > self.s and limit < MAX_SQRT_RATIO)
        rem, calc = amount_in, 0
        while rem != 0 and self.s != limit:
            s_start = self.s
            t_next, init = self._next_init(zfo)
            t_next = max(MIN_TICK, min(MAX_TICK, t_next))
            s_next_tick = sqrt_at_tick(t_next)
            tgt = (limit if s_next_tick < limit else s_next_tick) if zfo else (limit if s_next_tick > limit else s_next_tick)
            s_new, a_in, a_out, f = compute_swap_step(self.s, tgt, self.L, rem, self.fee)
            self.s = s_new
            rem -= a_in + f
            calc += a_out
            if self.s == s_next_tick:
                if init:
                    n = self.net[t_next]
                    self.L += -n if zfo else n
                    assert self.L >= 0
                self.tick = t_next - 1 if zfo else t_next
            elif self.s != s_start:
                self.tick = tick_at_sqrt(self.s)
        paid = amount_in - rem
        return (paid, -calc) if zfo else (-calc, paid)
