# MeetingMind — Design Language: "The Quiet Brief"

- **Date:** 2026-07-01
- **Status:** Approved design language (pre-implementation)
- **Applies to:** The Flutter mobile app (`docs/superpowers/plans/2026-07-01-meetingmind-mobile.md`)
- **Supersedes:** the placeholder `colorSchemeSeed: Colors.indigo` Material default in the mobile plan.

---

## 0. Chosen direction

Selected as a **merge** of two explored directions — "Editorial Quiet" (A) and "Focused
Console" (B) — over three candidates (A, B, and "Tactile Studio" C).

Take **Console's structured, highly scannable information architecture** and dress it in
**Editorial Quiet's typography, whitespace, calm, and editorial rhythm.**

- No heavy cards. No dashboard aesthetics. No shadows or fills as decoration.
- Sections separated by **whitespace and thin hairline dividers**, never boxes.
- The app should feel like **reading a beautifully prepared meeting brief**, not operating a
  generic productivity app.

**Guiding promise the whole language must carry:** the AI doesn't *generate text* — it
**transforms a conversation into clarity.**

---

## 1. Design principles

1. **It reads, it doesn't display.** The output is a brief you read, not a dashboard you operate.
   Prose and whitespace first; controls recede.
2. **Structure through air, not boxes.** Hierarchy comes from type, space, and hairlines — no
   elevated cards, no fills, no decorative shadows.
3. **Color is data, ink is everything else.** Near-monochrome warm ink on paper. The only
   saturation is *meaning* (priority, severity), and it is always paired with a word — never
   color alone.
4. **Confident calm.** Nothing blinks, bounces, or hypes. Motion decelerates and settles.
5. **The machine is invisible; the memory is the point.** Never surface "AI / generate / model."
   Name the work: listening, finding, keeping, ordering.

---

## 2. Voice & tone — "quiet noir"

The product speaks like **a seasoned assistant who was in the room** — reflective, economical,
quietly certain. Not a chatbot, not a narrator, not dramatic.

**Rules**
- No first person ("I", "Let me", "I'll"). No emoji. No exclamation hype.
- Present tense, declarative, one idea per line.
- Never says *AI / generate / process / analyze* to the user. Says *listen / catch / find /
  keep / order*.
- Confident phrasing — "Finding what matters," never "Trying to figure out…".
- Literary restraint is welcome; theatrics are not. If a line sounds like a movie trailer, cut it.

**Canonical copy library** (every string in the app comes from here or is written to its rules):

| State | Line | Secondary / action |
|---|---|---|
| Record — idle / empty | *Every meeting deserves a second memory.* | **Record** |
| Recording | *Listening to every detail.* | mono timer `04:12` |
| Paused | *Paused. Nothing is lost.* | **Resume** · **Stop** |
| Stop → uploading | *The conversation is over. The important part remains.* | — |
| Transcribing | *Catching every word.* | ledger |
| Analyzing | *Finding what matters.* | ledger |
| Finalizing | *Setting it in order.* | — |
| Ready (brief flash) | *Ready.* | → brief |
| Empty tasks | *Nothing was asked of anyone.* | — |
| Empty summary (rare) | *The conversation left no clear thread.* | — |
| Timeout | *This one is taking longer than it should.* | **Try again** |
| Pipeline failed | *Something didn't come through.* | **Start over** |
| Upload failed | *The recording didn't reach us.* | **Try again** |

---

## 3. Typography

Three families, three jobs. Loaded via `google_fonts` (all open-license).

| Role | Family | Use |
|---|---|---|
| **Serif** (read) | **Fraunces** (variable, optical) | Meeting title, summary prose, reflective headlines, questions |
| **Sans** (structure) | **Inter** | Section labels, task titles, buttons, statements |
| **Mono** (data) | **Geist Mono** (or IBM Plex Mono) | Deadlines, durations, counts, priority/severity tags, timers |

**Scale** (logical px / `sp`)

| Token | Family / weight | Size / line-height / tracking | Where |
|---|---|---|---|
| `display` | Fraunces 400 | 32 / 1.12 / -0.5 | Record & Processing headlines |
| `title` | Fraunces 450 | 28 / 1.15 / -0.3 | Brief title |
| `standfirst` | Fraunces 400 | 18 / 1.55 / 0 | Summary (the lede) |
| `body` | Fraunces 400 (italic for questions) | 17 / 1.55 | Reflective statements, questions |
| `label` | Inter 600 | 12 / 1.0 / +1.2, UPPERCASE | Section labels (SUMMARY, TASKS) |
| `item` | Inter 500 | 16 / 1.35 | Task / decision / risk titles |
| `caption` | Inter 400 | 14 / 1.4 | Status & helper copy |
| `meta` | Geist Mono 400 | 13 / 1.3 | responsible · deadline, durations |
| `tag` | Geist Mono 500 | 11 / 1.0 / +0.6, UPPERCASE | HIGH / MED / LOW |

One serif does title + reading (Fraunces optical sizes) for cohesion. If production summaries grow
long, swap `standfirst`/`body` to **Newsreader** — token names don't change.

---

## 4. Color

Light-first, warm paper. **"Noir" is tonal — it lives in the voice and the restraint, not a black
UI.** A dark variant is a straight token remap (§10).

**Ink & paper (the whole interface)**

| Token | Hex | Use |
|---|---|---|
| `paper` | `#F7F4EC` | Background, everywhere |
| `ink` | `#1A1714` | Primary text (~13:1 on paper) |
| `ink-secondary` | `#5A544C` | Summary prose, section content |
| `ink-tertiary` | `#6E665C` | Metadata, labels (≥4.5:1 — do not go lighter) |
| `hairline` | `#E4DDD0` | 1px dividers |
| `accent` | `#2E3B36` | Primary action, active/focus — a near-ink green, deliberately quiet |

**Functional color (data only — always paired with a word)**

| Meaning | Hex | Token |
|---|---|---|
| high | `#A6402F` (muted brick) | `sig-high` |
| medium | `#9A6B24` (muted amber) | `sig-med` |
| low | `#6F7A66` (muted sage) | `sig-low` |
| live / recording | `#A6402F` | `sig-live` |

Desaturated so it reads as signal, not neon. Priority/severity is **never** color-only — the `tag`
word carries it too.

---

## 5. Spacing & layout

- **Grid:** 4pt base. Steps: 4 · 8 · 12 · 16 · 24 · 32 · 40 · 48 · 64.
- **Screen margin:** 24 horizontal, fixed.
- **Section rhythm:** 44 whitespace between sections; a 1px `hairline` centered in the gap.
  Sections are never boxed.
- **Reading measure:** summary runs the column width at 24 margins (~60–68 chars on a phone).
- **Item rows:** 16 vertical padding; hairline between rows within a section (or pure whitespace
  for short lists).

**The one reusable primitive — `Section`:**
```
LABEL ····································· count(mono)
                     (16)
[ rows / prose ]
                     (44 + hairline)
```
Every knowledge type (Tasks, Decisions, Risks, Questions, Participants, Keywords…) renders through
this primitive. Adding a section later is trivial and automatically consistent.

---

## 6. Component language

- **Section label** — Inter `label`, `ink-tertiary`, optional right-aligned mono count.
- **Standfirst (summary)** — no label; sits directly under the title as the lede. Fraunces
  `standfirst`, `ink-secondary`. This is the editorial heart of the brief.
- **Item row (task/risk)** — 2px colored **priority tick** on the left edge (functional color),
  `item` title (`ink`), a `meta` line beneath (`responsible · deadline`), right-aligned `tag`
  (`● HIGH`). No pill, no fill.
- **Statement row (decision/reminder/pending)** — em-dash lead-in `—`, then `item` text.
- **Question row** — Fraunces `body` *italic*, `ink-secondary`; reads like a margin note.
- **Keywords** — a single mono run separated by ` · `. Not chips.
- **Tag** — mono uppercase word + small leading dot in functional color. The entire "chip"
  vocabulary.
- **Buttons** — flat, no elevation. Primary = `accent` text on a thin `accent` outline (or filled
  flat ink for Stop); secondary = plain Inter text button. Nothing resembles Material
  `ElevatedButton`.
- **Record control** — a large thin ring (2px `ink`, ~120dp) with a centered dot. Idle = hollow.
  Recording = `sig-live` dot, slow breathe; mono timer beneath. Optional single-line amplitude
  thread (thin, `ink-tertiary`) is the only motion-rich element, and even it stays quiet.
- **Processing ledger** — vertical stage list, mono labels, state markers: done `✓` (`ink`),
  active breathing dot (`accent`), pending hairline dot (`ink-tertiary`). Replaces the spinner.
- **Icons** — thin 1.5px stroke, used sparingly (back chevron, maybe a mic). **No**
  sparkle/star/magic-wand iconography — that is the AI cliché we refuse. Type does the talking.

---

## 7. Motion

- Durations 200–320ms; easing **decelerate** `cubic-bezier(0.2, 0, 0, 1)`. No overshoot, no bounce.
- Entrances: fade + rise 8px.
- Stage headline changes: 240ms crossfade.
- Recording dot: opacity 0.4↔1, 1.6s ease-in-out (breathing).
- Priority ticks and tags never animate.
- **Respect Reduce Motion:** disable breathing and crossfades; instant fades instead.

---

## 8. Screen specifications

### 8.1 Record
```
          Every meeting deserves
             a second memory.          ← display, centered, ink-secondary

                  ◯                    ← record ring (idle, hollow)
                Record                  ← accent text button
```
- **Idle:** empty-state line + hollow ring + "Record".
- **Recording:** *Listening to every detail.* · ring shows `sig-live` breathing dot · mono timer ·
  actions **Pause** · **Stop** (Stop = primary flat ink).
- **Paused:** *Paused. Nothing is lost.* · **Resume** · **Stop**.
- **Stop:** *The conversation is over. The important part remains.* → auto-advance to Processing on
  upload.
- No app-bar chrome; a faint wordmark top-left at most.

### 8.2 Processing
```
   Finding what matters.               ← display, changes per stage (crossfade)
   ───────────────────────
   Transcribed          ✓              ← mono ledger
   Understanding        ●  (active)
   Ordering             ·  (pending)
```
- Headline maps to status via §2 (`Catching every word.` → `Finding what matters.` →
  `Setting it in order.`).
- Ledger markers reflect the real lifecycle (`uploaded/transcribing/analyzing/completed`). Active
  stage's dot breathes. **No `CircularProgressIndicator`, no percentage.**
- **Timeout:** *This one is taking longer than it should.* + **Try again**.
- **Failed:** *Something didn't come through.* + **Start over**.

### 8.3 The Brief (Dashboard)
```
standup                                 ← meta (mono, muted)
Sprint Planning                         ← title (Fraunces 28)

We planned the sprint and scoped        ← summary as STANDFIRST
three tracks for the week ahead.          (Fraunces 18, ink-secondary, no label)

──────────────────────────────
TASKS                              2    ← label + mono count
│ Send the design document              ← 2px brick tick + item
│ John · tomorrow            ● HIGH
│
│ Draft the budget
│ Mara · Friday              ● MED
──────────────────────────────
                Every meeting deserves
                   a second memory.     ← quiet signature footer + New recording
```
- **Header:** meeting type (mono, muted) → title (Fraunces). MVP has no duration/speaker data, so
  no fabricated metadata line.
- **Summary:** the standfirst, unlabeled — the editorial heart of the screen.
- **Tasks (MVP):** item rows with priority tick + `responsible · deadline` meta + `tag`. Empty →
  *Nothing was asked of anyone.*
- **Section order** as the model grows into full `MeetingKnowledge`: Summary → Tasks → Decisions →
  Risks → Questions → Follow-up → Reminders → Pending → Participants → Keywords. Every one is the
  same `Section` primitive; Risks reuse the task row + severity tag, statements use the em-dash
  row, questions use italic serif, keywords the mono run.
- **Footer:** signature line + a quiet **New recording** action back to Record.

---

## 9. Accessibility

- Body/title contrast ≥ 12:1; `ink-tertiary` fixed at ≥4.5:1 (never lighter than `#6E665C`).
- Priority/severity always carry a text label — no color-only meaning.
- Tap targets ≥ 48dp (record ring far larger).
- Serif reading text honors OS dynamic type; layout reflows, no summary truncation.
- Reduce-Motion path defined (§7). Semantic labels on the record-control state and stage ledger.

---

## 10. Flutter token hand-off

Maps onto `ThemeData` / `ColorScheme` / `TextTheme` at build time. **Replaces** the mobile plan's
`colorSchemeSeed: Colors.indigo`.

- `ColorScheme.light`: `surface=#F7F4EC`, `onSurface=#1A1714`, `primary=#2E3B36`,
  `outlineVariant=#E4DDD0`; functional colors as a `ThemeExtension` (`sigHigh/Med/Low/Live`).
- `TextTheme`: Fraunces → `displaySmall/headlineMedium/titleLarge/bodyLarge`; Inter →
  `labelSmall/titleMedium/bodyMedium`; Geist Mono → a `meta`/`tag` extension.
- Fonts: `google_fonts` (`Fraunces`, `Inter`, `GeistMono`/`IbmPlexMono`).
- New reusable widgets (add to the mobile plan's structure): `BriefSection`, `TaskRow`,
  `StatementRow`, `QuestionRow`, `SignalTag`, `RecordRing`, `StageLedger`, plus a `QuietCopy`
  strings file holding the §2 library.

**Future dark ("true noir") remap** — same tokens: `paper=#14110D`, `ink=#ECE6DA`,
`ink-secondary=#B3AC9E`, `ink-tertiary=#8A8276`, `hairline=#2A251E`, functional colors +10%
lightness. No layout change.

---

## 11. Implementation notes

- This design language governs the **look**; the mobile plan
  (`2026-07-01-meetingmind-mobile.md`) governs the **structure, state, and TDD tasks**. The plan's
  screens (Record → Processing → Dashboard), Riverpod controllers, models, and tests stand; this
  document changes the theme and the widget presentation only.
- The plan's Task 1 sets a stock indigo `ThemeData`; replace it with the §10 theme (fonts +
  `ColorScheme` + `TextTheme` + functional-color `ThemeExtension`) as the first UI step.
- The plan's Tasks 6–7 build `SummaryCard`/`TaskCard`/screens with Material `Card`/`Chip`/
  `CircularProgressIndicator`. Rebuild those against §6 components (`BriefSection`, `TaskRow`,
  `SignalTag`, `StageLedger`, `RecordRing`) and §2 copy. **Widget-test assertions on text stay
  valid** where they check content; assertions coupled to `Card`/`Chip`/`No tasks identified.`
  must be updated to the new components and the §2 strings (e.g. `Nothing was asked of anyone.`).
