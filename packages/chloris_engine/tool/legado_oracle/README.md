# Legado-E Judging Process (legado-oracle)

A standalone Gradle/Kotlin JVM project that runs the **real** Legado-E rule-engine
backends out-of-process, so Chloris can be diffed against a genuine Legado-E
implementation (a true bilateral golden), instead of a self-comparison.

## What it covers

The judge symlinks the **original** upstream `.kt` files (no copies, no drift) and
ports only the minimal pieces needed to compile them:

| Backend | Upstream source | Status |
|---|---|---|
| regex | `AnalyzeByRegex.kt` | ✅ connected |
| css   | `AnalyzeByJSoup.kt` | ✅ connected |
| xpath | `AnalyzeByXPath.kt` | ✅ connected |
| json  | `AnalyzeByJSonPath.kt` | ✅ connected |
| lexer | `RuleAnalyzer.kt` | ✅ linked (used by the above) |
| single-rule (`@put`/`@get`/`{{}}`/`splitSourceRule`) | `AnalyzeRule.kt` | ⛔ not connected — needs Rhino/`Debug`/`CacheManager`/entity classes; cannot be shimmed without changing semantics |
| `AnalyzeUrl` | `AnalyzeUrl.kt` | ⛔ given up — depends on OkHttp/Glide/media3/hutool/Android Base64; out of scope |

Dependency versions mirror `reference/legado-E-main/gradle/libs.versions.toml`
(jsoup 1.16.2, JsoupXpath 2.5.3, json-path 2.10.0) so the judge runs the same
semantics as upstream.

## Build

```bash
export JAVA_HOME=/Users/bedrock/Library/Java/JavaVirtualMachines/ms-21.0.7/Contents/Home
gradle installDist          # produces build/install/legado-oracle/bin/legado-oracle
# or, equivalently: ./gradlew installDist  (wrapper not shipped; uses system gradle)
```

`gradle run` also works but is much slower (daemon per call); use the launcher
for the Dart bridge.

## Run a single fixture

```bash
echo '{"kind":"regex","content":"Chapter 1: The Beginning","rule":"Chapter (\\d+): (.*)"}' \
  | build/install/legado-oracle/bin/legado-oracle
# -> {"mode":"regex","expression":"Chapter (\\d+): (.*)","value":["Chapter 1: The Beginning","1","The Beginning"]}
```

### Protocol

* **stdin**: one JSON object per invocation:
  `{"kind":"<regex|css|xpath|json>","content":"...","rule":"..."}`
* **stdout**: one JSON object:
  `{"mode":...,"expression":...,"value":...}`
  The field names intentionally mirror the comparable subset of
  `EquivalenceFixture.run()` so `EquivalenceAudit` can diff them field-by-field.
  `steps` is intentionally **omitted** (it is a Chloris IR metric with no Legado
  equivalent) rather than fabricated.
* A kind that is not wired up returns `{"error":"not-connected:<kind>"}` — the
  Dart side skips it instead of trusting a guessed value.

## Dart side (the bridge)

* `lib/src/equivalence/legado_oracle.dart` — `LegadoProcessOracle implements
  EquivalenceOracle`. It serialises `fixture.input` (`kind`/`content`/`rule`) to
  the judge over stdin and parses the JSON it prints.
* `tool/legado_oracle_audit.dart` — a driver that builds fixtures over the real
  Chloris backends, runs `EquivalenceAudit(oracle: ...)` and writes the report.

```bash
# from packages/chloris_engine, with Dart/Flutter env set:
dart run tool/legado_oracle_audit.dart \
  --out artifacts/verification/20260912-rule-engine-parity/equivalence-bilateral.json
```

> ⚠️ `--out` 的相对路径是相对**当前工作目录**解析的。从 `packages/chloris_engine`
> 跑上面这条会把报告写进 `packages/chloris_engine/artifacts/...`，而不是工作区的
> `artifacts/...`，于是产出两份分叉的报告。要么传绝对路径，要么先 `cd` 到工作区根。

## CI / graceful degradation

`LegadoProcessOracle.tryCreate()` returns `null` when the judge cannot run
(no JDK on `PATH`, or the launcher was never built). In that case the driver
substitutes `SelfBaselineOracle` and prints a clear **"not bilateral"** banner,
so a JDK-less CI still runs the audit without pretending to be a differential.

Force the fallback explicitly with:

```bash
LEGADO_ORACLE_SKIP=1 dart run tool/legado_oracle_audit.dart
```

## Note on a required audit fix

`EquivalenceAudit._deepEquals` (in `equivalence_audit.dart`) originally only
handled `num`/`List`/`Map` and fell through to `false` for `String`/`bool`. That
made every bilateral oracle report a mismatch on scalar fields (self-baseline
passed only because it compared identical objects). A minimal
`if (a is String && b is String) return a == b; if (a is bool && b is bool) ...`
was added so the bilateral comparison is correct. This touches the comparison
helper only — not the `EquivalenceOracle` interface, not `lib/src/analyze/**`.
