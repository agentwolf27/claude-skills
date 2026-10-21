---
name: frontend
description: Web frontend craft for interfaces that display measured quantities — text layout without reflow, honest number formatting, empty/refusal states, and the JavaScript coercion traps that silently turn a missing measurement into a confident zero. Use when building or reviewing UI that shows numbers, nullable or uncertain values, or text whose size must be known before paint. Trigger:/frontend
---

# Frontend craft for interfaces that show measured things

Two halves, both evidence-backed rather than taste: **how to lay text out without paying for reflow**, and **how to display a number you are not certain about without either lying or being useless.**

Every claim below carries its source. Where the evidence cuts against a common instinct, that is said explicitly.

---

## 1. Measure text without touching the DOM

**The problem:** knowing how tall a paragraph will be requires laying it out. `getBoundingClientRect()` and `offsetHeight` force synchronous layout reflow. Every virtualized list, masonry grid and scroll-anchoring implementation has either paid that cost or guessed.

**[Pretext](https://github.com/chenglou/pretext)** (chenglou, MIT) computes it in arithmetic instead. **4.3M npm downloads/month and roughly doubled since May** — the weekday/weekend sawtooth is real CI traffic, not a star spike. It is genuinely adopted and unusually well tested.

```ts
import { prepare, layout } from '@chenglou/pretext'

await document.fonts.ready                 // ← REQUIRED. See the footgun below.
const prepared = prepare('AGI 春天到了. بدأت الرحلة 🚀', '16px Inter')
const { height, lineCount } = layout(prepared, 320, 20)
```

`prepare()` does the one-time pass — normalize, segment with `Intl.Segmenter`, apply glue rules, measure each segment with canvas. `layout()` is pure arithmetic over cached widths. **Never re-run `prepare()` for the same text and font;** on resize, re-run only `layout()`.

**The speedup applies to the re-layout hot path, not to first measurement.** `prepare()` runs a segmenter and a canvas measure per segment and is not free.

### Four caveats. Do not ship this without them.

**1 — Await fonts, or you poison a cache for the life of the page.**

There is **no `document.fonts.ready` or `.check()` guard anywhere in the library**, and results land in a **module-level cache keyed only by the font shorthand string**. A `prepare()` that runs before the webfont arrives measures the *fallback* face and that measurement is then reused for that font string forever. `clearCache()` exists; the README never tells you you'll need it.

**Its activation condition is a cold load — the one state nobody develops in.** On a warm cache the font is there first, so every local run, screenshot and demo is correct. **Verify with a hard reload, cache disabled.** Looking at it will not find this.

**2 — Never `system-ui` or `-apple-system`. Always a named font.**

On macOS these resolve to **different physical fonts in canvas versus DOM** in both Chrome and Firefox. The library declares them unsupported and has filed upstream bugs. **This silently breaks the default font stack of most design systems.** Related: if the page sets `lang`, generic families like `serif` can also resolve differently.

**3 — Widths are for line breaking, not for coordinates. And not for bidi at all.**

| Use it for | Do not use it for |
|---|---|
| Height, line count | Caret positions |
| Shrink-wrap width | Selection rectangles |
| Virtualization, overflow checks | Any x-coordinate in mixed LTR/RTL |

Mixed LTR+Arabic diverges from the DOM by **up to ~79px** (issue #77 — reproduced by the maintainer, then closed by narrowing the docs rather than fixing the measurement). The Arabic support in the README covers *line-break decisions*, not glyph positions.

Also unmodelled, all silent: **`text-transform`** (apply it yourself *before* `prepare()`), `font-feature-settings`, `font-optical-sizing`, `font-variation-settings`, `font-kerning: none`, vertical writing modes, `hanging-punctuation`. No automatic hyphenation. `Intl.Segmenter` and Unicode property escapes are hard runtime requirements.

And one architectural limit worth knowing: it measures per segment and sums, which **discards cross-boundary kerning** — the maintainer's own note says the current model "alone is insufficient."

**4 — Pin the version. It is v0.0.9 with a bus factor of one.**

431 of 435 commits by one person; 44 open PRs against 12 ever merged; and his previous 22k-star library has been dormant since January 2024. **Pin exactly, and verify wrapping against the real DOM in your own CI for your own font stack** — the checked-in 7680/7680 oracle runs on a curated corpus that excludes the known-bad cases.

### What it unlocks, when the caveats hold

Virtualization without guessed row heights · masonry and JS-driven layout · **multiline shrink-wrap** (`walkLineRanges()` → `maxLineWidth` gives the tightest width that still fits — genuinely missing from the web) · scroll anchoring for text that hasn't loaded · build-time overflow checks, browser-free.

`prepareWithSegments()` + `layoutNextLineRange()` takes a *different width per line*, which is how you flow text around a floated image. `walkLineRanges()` allocates no strings, so it's cheap enough to binary-search a pleasing width before committing.

### Three claims about it that are false

Circulating widely, including on AI-generated content farms:

- **"Knuth-Plass / TeX-quality line breaking."** It is a **greedy first-fit** breaker — zero occurrences of `knuth`, `plass`, `badness` or `penalty` in the source. Greedy is the *correct* design for matching CSS, but the claim is false.
- **"Battle-tested in Midjourney production."** Unverified. The article usually cited names Midjourney only as the author's employer.
- **"Solved a problem impossible for 30 years."** Sebastian Markbåge published this architecture years earlier as `text-layout` — canvas measurement, bidi from pdf.js, streaming line breaking — and got 34 stars. **The README credits him.** Pretext's real contribution is a three-browser differential accuracy oracle, per-engine quirk profiles, and a maintainer who files upstream browser bugs. That is a testing-rigour contribution, not an algorithmic one.

## 2. Displaying a number you are not certain about

This section is almost entirely counter-intuitive. Each rule earned its place against the instinct it replaces.

### Significant figures, not decimal places

**Fixed decimals misrepresent precision at both ends.** `0.0031752` rendered as `0.0` claims you measured zero; `40.375` as `40.3750` claims six figures nobody has.

**The digit count is a function of the uncertainty, not of the source's printed digits.** GUM (JCGM 100:2008) §7.2.6: estimates *"should be rounded to be consistent with their uncertainties."* ONS tiers the same value by audience — 260,000 for the general reader, 264,337 for the analyst — with the instruction to *"always use the lowest level possible for the intended user."*

**Clamp both ends when rounding a proportion.** `1/200` rounds to 0% — which says the figure came from nothing. `199/200` rounds to 100% — which is false while one item is missing. Both are wrong in the same way.

**And know the perverse incentive you are resisting:** precise numbers are read as *more* credible by lay audiences, and **the effect survives telling people about it** (Zhang & Schwarz 2012; Schindler & Yalch 2006; Thorsteinson 2021). Extra digits buy real trust. They buy it on a claim you cannot support — and Pena-Marin & Wu (2019) found a precise estimate later shown wrong costs *more* source trust than an imprecise one that was further off.

### Do not show an error bar. Show the scope instead.

**Even when you have a defensible band.** The band you can cite usually measures the smallest source of error, and displaying it implies the larger ones do not exist.

Three of these institutions moved *away* from showing ranges to lay audiences:

- **EPA** shipped an "Expected range for most drivers" on fuel-economy labels for five years — produced by multiplying the estimate by **0.83 and 1.17**, a flat ±17% on every vehicle, from no in-use distribution — and **deleted it in the 2013 redesign.** What fraction of drivers it covered is not stated in any of four rulemakings.
- **Bank of England**: the Bernanke Review says fan charts *"have weak conceptual foundations… They should be eliminated"* and *"convey a false sense of precision."*
- **EU nutrition labelling** quantifies its tolerances precisely — a declared vitamin value may legally be **35% low or 50% high** — and shows the consumer one number, by design.

> **What separates responsible from irresponsible practice is not whether a band is displayed. It is whether the number's *scope* is stated.**

The UK Government Analysis Function names the anti-pattern directly: phrases like *"care must be taken"* *"are not sufficient by themselves, because they do not help the reader to understand what they can and cannot do with the numbers."*

### If you do show uncertainty, four format rules

1. **Never a bare verbal hedge.** van der Bles et al. (PNAS 2020, N=10,519): an unquantified verbal hedge is the *only* format that costs trust in the **source** as well as the number.
2. **Never a graphic.** Joslyn & Savelli: a bracketed interval with an explanatory key was misread as deterministic by **36%**; the same information as plain numeric text was read correctly by **94%**, with equal trust. Error bars were misread by **65% of published researchers** (Belia et al. 2005).
3. **Never behind a link.** Budescu et al. (n=556): a lookup table scored **18.8% — worse than showing nothing (20.8%)**. Only inlining the numbers with the words worked (30.1%).
4. **State the complement.** The one experimentally validated micro-fix: Joslyn et al. (2009) cut reference-class errors from **64% to 36%** by adding *"Chance of no rain: 75%"* beside *"Chance of rain: 25%."*

And the reassurance: disengagement is not the risk. Gustafson & Rice (2020), reviewing k=48 experiments, found **no instance of technical uncertainty producing negative effects.** Gaertig & Simmons (N=4,806): **82.4% preferred an advisor giving a probability over the same advisor giving a certainty.**

---

## 3. Empty states, and refusing without becoming a blank page

### A blank is read as a zero

Clinicians using a system that **abstained** missed **18% more diagnoses and 35% more treatments than with no system at all.** Abstention was worse than absence.

So a footnote saying *"3 items excluded"* beneath a total does not work — the reader supplies a zero. **Put the qualifier inside the number**: `13 kg · 62% priced` rather than `13 kg` plus a caption.

### …and in JavaScript the code turns the blank into a zero for you

`Number(null)` is `0`. So is `Number('')`, `Number('  ')`, `Number([])` and `Number(false)`. Only
`undefined` and `NaN` come back `NaN`.

**That asymmetry is what lets this survive a test suite.** A case written with `undefined` fails
the way you expect, so the guard looks tested — and the same guard passes `null` straight through
as a legitimate measurement of zero. If a suite fails on `null` and passes on `undefined`, the bug
is coercion; nothing else produces that split.

Four spellings, three of which are the bug (verified, node 22 — ✅ = rejects the non-number, which
is what you want):

| guard | `null` | `''` | `[]` | `false` | `NaN` |
|---|---|---|---|---|---|
| `Number.isFinite(x)` | ✅ | ✅ | ✅ | ✅ | ✅ |
| `Number.isFinite(Number(x))` | ❌ **passes** | ❌ | ❌ | ❌ | ✅ |
| `isFinite(x)` (global) | ❌ **passes** | ❌ | ❌ | ❌ | ✅ |
| `typeof x === 'number'` | ✅ | ✅ | ✅ | ✅ | ❌ **passes** |

`Number.isFinite(x)`, uncoerced, is the only one correct on its own. The global `isFinite` coerces.
`Number.isFinite(Number(x))` coerces the value *before* the check that exists to catch it — it is
the guard written to prevent this bug, containing this bug. `typeof` admits `NaN`.

Test the absence before any arithmetic touches the value, and return the refusal rather than a
number the caller has to re-interrogate:

```ts
if (kg === null || kg === undefined || !Number.isFinite(kg)) return null;
```

**The render site is where this actually bites**, because `.toFixed()` is a coercion you did not
write: `Number(null).toFixed(2)` is `'0.00'`. An API that correctly returns `carbonKg: null` still
displays a confident, decimal-aligned zero the moment one template calls `Number(...)` on it — and
`0.00` looks *more* measured than a real figure, because of the trailing zeros. The type checker
does not see through the coercion, so grep instead: `toFixed`, `toLocaleString`, `Math.round`,
`+x`, and `${x}` applied to any field typed `T | null`.

Everything above §3 is about refusing well. This is the failure where the refusal exists, is
correct, is typed, survives the API boundary — and is destroyed by one function call in a span.

### The four-part refusal

Open Food Facts is the largest refusal-based consumer product in existence, and it is **not what you would assume**: of 908,813 scored products, **901,539 — 99.2% — carry an explicit missing-data warning.** It refuses only at a hard floor and otherwise computes with a *named, itemised deficit*.

Its refusal object is the pattern to copy:

| Part | Example |
|---|---|
| **A named state** | "Green-Score not computed" — not "no data" |
| **A named cause** | "Missing a precise category" |
| **A first-person ask** | "could you help complete it?" |
| **A typed, machine-readable action** | `actions: ['add_categories']` |

That last one is the difference between a dead end and a work queue. **The client should render the specific control, not a generic apology.** Their coverage went 414k → 909k in five years against a factor database that barely grew — that growth is what filling those gaps looks like from outside.

**Blame the data, not yourself.** *"No published source covers this"* is a fact about the world. *"We can't calculate this"* is a confession. Qin et al. (2025, 442 effects, N=82,078): appreciation when a system is perceived as capable (d=+0.27), aversion when not (d=−0.50).

**But never a bare refusal.** Chatbot Arena, ~50,000 comparisons: a technical refusal costs **−21pp** win rate; a disclaimer that still engages costs only **−6pp**. O'Keefe's meta-analysis: naming a limitation *and addressing it* gains credibility; naming it and stopping **loses** persuasiveness.

---

## 4. Jargon is not rigour

Bullock et al. (*Public Understanding of Science*, 2019), replicated twice since:

> "the presence of jargon impairs people's ability to process scientific information, and that this impairment leads to **greater motivated resistance to persuasion, increased risk perceptions, and lower support**… the use of jargon **undermines efforts to inform and persuade**."

A credential shown to an audience that cannot evaluate it produces **resistance, not trust**. Keep provenance in the export, the API response and the methodology page — it must exist and be findable. It does not have to be the fourth line of a card.

**Spend the disclosure budget where the number actually moves.** Audit this before shipping any methodological label: if choice A moves the figure by 0.03% and choice B moves it by 69%, and you are labelling A, you have it backwards.

---

## Checklist

- [ ] Text heights come from arithmetic, not `offsetHeight` — and `prepare()` is not in the resize path
- [ ] `prepare()` is gated on `document.fonts.ready`, and verified on a **cold** load, not a warm one
- [ ] The measured font is named — never `system-ui` or `-apple-system`
- [ ] Measured widths drive breaks and sizes, never caret or selection coordinates
- [ ] Version pinned exactly, with a DOM-comparison test on your own font stack in CI
- [ ] `font`, `lineHeight` and `letterSpacing` match the CSS exactly
- [ ] Figures render at significant figures set by the uncertainty, with both rounding ends clamped
- [ ] No manufactured error bar; the number's scope is stated instead
- [ ] Any uncertainty shown is inline numeric text, never a graphic and never behind a link
- [ ] Totals carry their coverage *inside* the number, not in a footnote
- [ ] Absence is tested with uncoerced `Number.isFinite(x)` — never `Number.isFinite(Number(x))`, never global `isFinite`, never `typeof` alone
- [ ] No `toFixed` / `toLocaleString` / `Math.round` / `+x` / `${x}` reaches a field typed `T | null` — grep for it; the type checker cannot see through the coercion
- [ ] A suite that fails on `null` but passes on `undefined` is diagnosed as coercion, not patched case by case
- [ ] Every empty state has a named cause and a typed action
- [ ] Refusals blame the data, and still engage
- [ ] Technical labels are worth their space — check what actually moves the number
