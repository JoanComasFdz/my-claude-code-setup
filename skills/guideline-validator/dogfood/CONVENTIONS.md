# Coding conventions (binding)

These are **requirements, not suggestions** — the plan and the code must follow
them. They are the house style for `variance-lots-check` (a .NET 10 / C# 14
project); they are scoped to this subproject, not the whole repo (per the
repo-wide rule that "each subproject is its own world").

This file is the canonical, citable home for the conventions. The full rationale,
worked examples, and the domain model that motivates them live in the design
spec — **`docs/superpowers/specs/2026-06-25-variance-lots-check-app-design.md`,
§5 (Functional design conventions) and §6 (Domain model)** — which is the source
this is distilled from. When the two ever disagree, the spec wins; update both.

## Architecture

- **Vertical Slice Architecture is the top-level driver.** Group by *feature*,
  never by kind. A behaviour change touches one slice, not a layer. The slices
  live under `src/VarianceLotsCheck.Core/` (`BrokerDocuments`, `Gen10SheetLoading`,
  `Reconciliation`, `PreFlightValidation`, `ReportRendering`,
  `FileSystem`, `Orchestration`).
- **Feature slices depend only on the shared kernel** (`Domain` / `Functional` / `Extraction` / `Documents`,
  plus the broker-agnostic `BrokerDocuments/Pdf` engine) — never sideways on each
  other. The only cross-slice dependencies are `Orchestration` → every slice, and
  the documented exception `PreFlightValidation` → the slices whose outputs it
  validates. An **architecture test** enforces these boundaries in CI.
  The kernel has two small non-`Domain` modules for behaviour that is shared across slices but is not pure value arithmetic: **`Extraction`** (statement-format → `Commodity` mapping) and **`Documents`** (`LoadedDocument` byte→stream access, which needs `System.IO`). Both are guarded by architecture tests and may not depend on any feature slice.
- **The broker is the primary slice.** Brokers plug in through the **`BrokerSlice`
  functional registry**, so adding one is a folder + a registry line — never an
  edit to a shared classifier or a dispatch `switch`.
- **`Domain` holds data + pure value arithmetic only** — no feature behaviour, no
  outward dependency, never depends on a feature slice or on `System.IO`. The
  allowed exception is pure, dependency-free value arithmetic (e.g.
  `Commodity.ToTonnes` = lots × 25, the `Functional` primitives' generic
  `Map`/`Bind`).

## Functional design

- **Pure/impure split — strict `impure → pure → impure` sandwich.** The
  filesystem boundary (`FileSystem`) reads bytes and writes the report; everything
  between is pure. Read at the start, compute in the middle, write at the end.
- **Never mix or nest pure and impure calls on one line.** A statement is either
  pure or impure, never both — don't wrap an impure call around a pure one (or
  vice versa). Split them into separate statements, introducing a named
  intermediate even when it feels redundant:

  ```csharp
  // No — pure Render nested inside impure WriteLine
  Console.WriteLine(Reporter.Render(ok.Value));

  // Yes — one line pure, the next impure
  var report = Reporter.Render(ok.Value);   // pure
  Console.WriteLine(report);                // impure
  ```

  The extra line/variable is an accepted cost. It makes the sandwich readable
  vertically — you can scan straight down and see exactly where each pure↔impure
  boundary is — and it makes those boundary jumps easy to step through when
  debugging.
- **Effects as data.** Pure functions return an `Effect` DU describing the side
  effects to perform; the impure shell `Match`es it and executes them
  (`WriteReport`, `ShowValidationResult`, …).
- **Honest, total signatures** via our own `Optional<T>`, `Result<T, F>`, and
  `Unit` (in `Functional/`) — defined as Dunet DUs with `Map`/`Bind`/`Match` as
  extension methods. **No third-party FP library.** No partial functions, no
  null-as-absence, no exceptions-as-control-flow across the pure core.
- **Railway-oriented (ROP)** for the end-to-end flow: the pipeline composes
  `Result`-returning steps that stay on the success track and short-circuit onto
  the failure track at the first blocking error — no explicit app-state object.
- **Typestate when call order matters** (pre-flight must precede reconcile). It
  composes with ROP: `ValidatedFolder` is constructible only by a successful
  pre-flight and is the success-track payload the reconcile step consumes, so
  "reconcile before validation" does not compile.
- **Pure state machine** is reserved for genuinely stateful situations with more
  than two states — *not* the linear app flow, which is a railway, not a machine.

## Domain modelling

- **Data ⟂ behaviour.** Records hold data; behaviour lives in static / extension
  functions over the data. No methods carrying logic on the records themselves.
- **Functions are actions — name them with a verb.** Every function/method name
  must contain a verb describing what it does (`ReadBusinessDate`, `ResolveAccount`,
  `MatchTradeRow`, `FindBannerMetal`, `ToTonnes`) — never a bare noun
  (`Fingerprint`, `Sides`, `BandValue`). A name that is only a noun denotes a
  *thing*, so it belongs to data, not to a function. Two idioms satisfy the rule
  without an explicit action word: boolean predicates may lead with `Is`/`Has`/`Can`
  (`IsWorkbook`, `IsDate`), and conversion/factory members may use `Parse`/`ToX`/
  `FromX` / the union-case constructor names (`CommodityMapping.FromString`,
  `Optional.Some`, the parsers' local `Ok`/`Err`).
- **Immutability everywhere.** All domain types are immutable `record`s.
- **Domain via discriminated unions, not inheritance.** DUs are generated with
  **Dunet**. Behaviour is static/extension functions over the DU that
  pattern-match internally — never `ISomething` + two classes. The `Broker` DU is
  the routing identity only; per-broker behaviour lives in its slice and is reached
  through the `BrokerSlice` registry, not a hand-written `Broker.Match` that grows
  with every broker.
- **Make illegal states unrepresentable.** Each DU case carries exactly its own
  figures (e.g. `Verdict.NetMismatch` carries both sides' net *and* variation, so a
  combined net+price fault still surfaces the variation delta). Prefer a
  data-carrying case over a flat "tag + optionals" shape.
- **Value objects via Vogen** (`Lots`, `Tonnes`, `Price`, `Variation`,
  `BrokerAccount`, `PromptDate`, `AsOfDate`), constructed and validated **at the
  boundary** — once inside the pure core a value object is known-valid.
- **Add a named failure/`Severity` case only when the app branches on it** (to
  recover or take a different path), never merely to carry a message. IO whose only
  outcome is "show the user what went wrong" uses `Result<_, string>`; the acted-on
  distinction is `Severity = Blocking | Warning | Info` with a `string` message.

## Practical API gotchas

- **Prefer static direct calls** over interfaces/delegates.
- **Dunet unions have no static factories.** Construct cases with `new` —
  `new Result<T, F>.Ok(x)` / `new Result<T, F>.Error(e)` — and use the
  `Optional.Some<T>(x)` / `Optional.None<T>()` helpers (not `Result.Ok(...)` /
  `Optional<T>.None()`).
- **`Match` needs an explicit type argument when the branches return different
  types**, e.g. `value.Match<string>(...)`.
- **Boundary error policy.** Catch *foreseeable* exceptions at the boundary
  (missing/denied permission, locked/corrupt file, unreadable workbook) and wrap
  them in `Result<_, Failure>`. Let *unrecoverable* exceptions (e.g.
  `OutOfMemoryException`) bubble to the app.
