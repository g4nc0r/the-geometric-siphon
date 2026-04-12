# The Geometric Siphon

[![DOI](https://zenodo.org/badge/DOI/10.5281/zenodo.19526374.svg)](https://doi.org/10.5281/zenodo.19526374)

Code and supplementary material for the **Geometric Siphon** research line by K.R. Ryan.

This repository collects the verification code for two SSRN papers analysing the geometric residual that arises when concentrated-liquidity positions are restruck across tick ranges.

## Papers

| # | Title | SSRN | Status |
|---|-------|------|--------|
| I  | The Geometric Siphon: Emergent Capital Reallocation in Concentrated Liquidity Portfolios | [6374838](https://papers.ssrn.com/sol3/papers.cfm?abstract_id=6374838) | Published |
| II | The Geometric Siphon II: Directional Properties                                          | [6481498](https://papers.ssrn.com/sol3/papers.cfm?abstract_id=6481498) | Published |

PDFs live in [`papers/`](./papers/). The canonical, citable versions are the SSRN abstracts above.

## Layout

```
.
├── papers/                  published PDFs and LaTeX sources (mirror of SSRN)
├── foundry/                 unified Foundry verification suite for both papers
│   ├── src/                   MockCLPool.sol, MockCLPoolV2.sol
│   ├── test/                  4 test contracts, 15 tests total
│   ├── lib/forge-std/
│   ├── foundry.toml
│   ├── PROOF_OUTPUT.md        captured `forge test -vv` output, mapped to paper sections
│   └── README.md
├── CITATION.cff
├── LICENSE
└── README.md
```

The Foundry suite covers both papers in a single project. Theorem 1 (Paper I §3.2) and Theorem 3 (Paper I §3.6) are verified under `MockCLPool`, with the same Theorem 1 claims also verified against live Aerodrome Slipstream contracts on Base via a fork test. Theorems 4–6 (Paper II §2) are verified under `MockCLPoolV2` with exact V3 `TickMath` constants. The fork test also verifies the architectural precondition described in Paper I §7.1.

## Reproducing the results

```bash
cd foundry
git submodule update --init --recursive   # first time only

# Mock-pool tests only, no network access required (10 tests)
forge test -vv --no-match-contract 'GeometricResidualProof$'

# Full suite, including the 5 live fork tests against Aerodrome Slipstream (15 tests)
RPC_BASE_ALCHEMY=https://mainnet.base.org forge test -vv
```

Any working Base RPC endpoint is acceptable in `RPC_BASE_ALCHEMY`. The official public endpoint above is sufficient for all five fork tests; alternatives include `https://base.publicnode.com` or any Alchemy/Infura/QuickNode Base URL. Forge caches RPC responses, so repeat runs are fast. See [`foundry/PROOF_OUTPUT.md`](./foundry/PROOF_OUTPUT.md) for the full captured output mapped to each paper section.

The empirical analyses in Paper I §5 and Paper II §2 are backed by an operational diffusion-event log from one author's positions on Aerodrome Base. That dataset is not shipped with this repository and is available on request. The theorem verifications above are fully reproducible without it.

## Citing

```bibtex
@techreport{ryan2026siphon1,
  author      = {Ryan, K. R.},
  title       = {The Geometric Siphon: Emergent Capital Reallocation in Concentrated Liquidity Portfolios},
  institution = {SSRN},
  number      = {6374838},
  year        = {2026},
  url         = {https://papers.ssrn.com/sol3/papers.cfm?abstract_id=6374838}
}

@techreport{ryan2026siphon2,
  author      = {Ryan, K. R.},
  title       = {The Geometric Siphon II: Directional Properties},
  institution = {SSRN},
  number      = {6481498},
  year        = {2026},
  url         = {https://papers.ssrn.com/sol3/papers.cfm?abstract_id=6481498}
}
```

## Licence

Code: MIT. Papers: © the author, all rights reserved (links above are the canonical versions).
