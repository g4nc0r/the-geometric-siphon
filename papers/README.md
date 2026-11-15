# Papers

Part of [The Geometric Siphon](../README.md).

| Version | Date | Files | SSRN |
|---|---|---|---|
| **The Geometric Siphon**, current | November 2026 revision | [`the-geometric-siphon.pdf`](./the-geometric-siphon.pdf), [`the-geometric-siphon.tex`](./the-geometric-siphon.tex) | [6686798](https://papers.ssrn.com/sol3/papers.cfm?abstract_id=6686798) |
| The Geometric Siphon, first consolidated version | May 2026 | [`archive/2026-05-consolidated/`](./archive/2026-05-consolidated/) | 6686798, replaced by the revision |
| Paper I: Emergent Capital Reallocation in Concentrated Liquidity Portfolios | March 2026 | [`archive/paper-i/`](./archive/paper-i/) | [6374838](https://papers.ssrn.com/sol3/papers.cfm?abstract_id=6374838) |
| Paper II: Directional Properties | March 2026 | [`archive/paper-ii/`](./archive/paper-ii/) | [6481498](https://papers.ssrn.com/sol3/papers.cfm?abstract_id=6481498) |

The current paper supersedes the three below it. Its Appendix F lists every statement of the May 2026 version that the revision corrects, with the old and new values. Papers I and II are superseded by the consolidated paper and remain on SSRN.

The May 2026 text in a journal format was removed from the tree in this revision and remains in the repository history at tag `v1.2`.

## Building the current paper

```bash
xelatex the-geometric-siphon.tex   # three passes
```

The source is a single file with its figures drawn in TikZ and its bibliography inline. It needs XeLaTeX and these fonts:

| Font | Used for | Source |
|---|---|---|
| EB Garamond | text | TeX Live, `ebgaramond` |
| Garamond-Math | mathematics | TeX Live, `garamond-math` |
| Cormorant Garamond, SemiBold and Medium Italic | title and section headings | installed as a system font |
| Inconsolata | code | TeX Live, `inconsolata` |
| GNU FreeSerif | ornaments | TeX Live, `gnu-freefont` |

## Licence

Paper PDFs and LaTeX sources © K. R. Ryan, all rights reserved. See [`../LICENSE`](../LICENSE).
