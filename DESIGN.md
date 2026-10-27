# SAPIENS UI system

Mode: Operate. Refinement of the existing Flutter interface for cattle farmers, preserving the account-level Potong/Perah mode, four primary destinations, two-step cattle creation, individual cattle context, existing labels, guards, histories, and backend capability states.

## Visual authority

[Profile reference](docs/design/profile-reference.png) establishes the visual direction, implemented as native Flutter widgets. The image is design documentation and is never rendered as application UI. Existing product copy and functionality take precedence over illustrative details in the reference.

Retain forest green with warm near-white and restrained sage. No decorative gradients, shadows, fake production metrics, marketing sections or additional navigation. Native Material controls remain familiar. A shared cattle outline replaces the generic paw placeholder and navigation glyph; real gallery photos retain their existing behavior.

## Tokens and roles

Source of truth: `lib/app/theme.dart`.

| Role | Token |
| --- | --- |
| Primary ink/action | `Palette.ink` #163D35 |
| Secondary text | `Palette.muted` #53665E |
| Canvas | `Palette.cream` #F6F7F3 |
| Surface | White |
| Divider | `Palette.line` #DEE5DE |
| Selected/info | `Palette.leaf` #E4EDE5 |
| Warning | #82521B on #FFF3DE |
| Error | #A43232 on #FFEFEC |

Normal text color pairs meet 4.5:1 contrast in automated tests. Disabled controls remain visibly disabled. Color is paired with labels, icons or selection indicators.

Spacing: 8 / 12 / 20 / 28 px, with 20 px phone gutters and 32 px wide-page gutters. Surfaces have one 1 px border, radius 16 px; inputs/buttons radius 12 px. Main content maximum 1040 px; forms and reading surfaces maximum 760 px. No fixed content heights for narrative or user-entered strings.

Typography: existing platform sans/Roboto; body 14/16, captions 12, labels 13/14, section headings 18, page headings 20/22, numeric metrics 26, text-valued metrics 20, onboarding heading 32. Numerals use tabular figures in shared metrics. Keep system text scaling, wrapping and focus outlines.

## Reusable components

- `PageFrame`: constrained readable page, keyboard-dismiss-on-scroll, consistent page/subtitle gutters.
- `Surface`: restrained bordered container and Material ink/focus behavior.
- `Heading`: predictable section rhythm.
- `Metric` / `MetricGrid`: aligned equal-height rows; one column on compact screens or enlarged text, two on ordinary phones, four for four-value groups on wide layouts. Do not truncate data to force equal heights.
- `SectionTab`: familiar horizontal navigation, underline selection, no checkmark, horizontally scrollable when labels do not fit. Existing disabled Dairy-male tab semantics retained.
- `Notice`: distinct informational, warning and error states; no new domain conclusions.
- `Tag`: compact, wrapping metadata; never the only source of meaning.
- `SubmitButton`: primary/secondary variants, existing busy/error/retry behavior, inline live error announcement; no duplicate submit.
- `LoadingState`: readable progress, static progress under reduced motion.
- `CowMark` / `CowAvatar`: consistent semantic cattle icon, with actual photos preferred when present.

Inputs, dropdowns, dialogs, snackbars, tooltips, chips and primary navigation use the shared theme. Minimum button target is 48–52 px. Navigation remains Beranda–Ternak–Pakan–Profil on all sizes.

## Responsive and state contracts

Use available width, not device names. Test compact phone, ordinary phone, tablet and desktop, including 160% and 200% text. Never clamp system text scaling or hide information to pass overflow checks. Profile identity and sections participate in coordinated scrolling so long names/IDs and enlarged text do not consume a fixed header and block the page.

Loading, empty, error, disabled, selected, in-progress, populated and partial-data states retain existing behavior and copy. Error color does not turn a backend capability gap into a clinical/nutrition conclusion. No model, controller, API, persistence or calculation changes belong in a visual pass.

## Intentional reference adaptations

The reference is a visual specification, not new product authority. The implementation preserves two columns on ordinary phones where readable, collapses to one for narrow/enlarged-text layouts, and keeps horizontal overflow for the same five profile tabs rather than shrinking their labels. Existing info/action copy remains in place. The home account-mode label moves below the greeting and uses normal case, without changing its meaning. Bottom navigation remains unchanged structurally.

## Nutrition result content hierarchy

Successful API processing is not nutrient sufficiency. A result starts with a plain-language conclusion based on explicit backend outcomes and highlights skipped ingredients. Daily requirement and feed contribution appear together with their units; coverage fractions are not shown as nutrient adequacy. Unknown supply (including a backend zero caused by missing profiles) is separated from true zero supply. Dairy `not_fully_evaluable` stays unevaluable; intake prediction is explicitly distinct from full nutrition adequacy. BK and TDN units are explained without adding feed formulas or recommended quantities. Feed inputs and exclusions remain readable; coverage, confidence, assumptions and original backend JSON use progressive disclosure. The persisted evaluation is never rewritten by presentation.
