# Open Astrology Chart Format

**Spec name:** `open-astrology-chart`
**Version:** 1
**Status:** Draft
**File extension:** `.toml`
**Encoding:** UTF-8

An open, human-readable interchange format for a single astrological **Chart** —
a moment in spacetime, suitable for sharing between any astrology software.
Aion is the reference implementation; the format intentionally carries no
aion-specific or tool-specific concepts.

This document uses the keywords MUST, SHOULD, and MAY as defined in RFC 2119.

---

## 1. What a Chart is

A **Chart** is one astronomically significant instant at one place on Earth:
a birth, a transit, an event, an election. It is *not* a horoscope, a reading,
or a wheel — those are interpretations or renderings *of* a Chart.

A Chart is defined by its **natural key**:

```
(jd, lat, lon)
```

- `jd` — the Julian Day, which fixes the instant.
- `lat`, `lon` — the geographic position.

Everything else in the file (name, gender, place name, tags, notes, …) is
**metadata** that describes or identifies *whose* moment it is. Metadata never
participates in the natural key.

---

## 2. Design principles

1. **Julian Day is canonical.** Civil calendar time and timezones are
   historically unstable, politically mutable, and ambiguous (DST transitions,
   retroactive zone changes, pre-1582 calendars). The instant is therefore
   stored as a single Julian Day number, which is unambiguous and
   tool-independent. Civil date/time is *advisory* — a convenience for humans
   and a derived rendering of `jd`, never the source of truth.

2. **The natural key identifies the moment, not the person.** `(jd, lat, lon)`
   is a *deduplication hint*, not a hard uniqueness constraint. Two Charts MAY
   share a natural key while differing in metadata (e.g. an event chart and a
   person born at the same instant and place). Twins do **not** collide: they
   are born minutes apart, so their `jd` differs. Consumers MUST tolerate
   natural-key collisions rather than treating them as errors.

3. **Human-readable, human-authorable.** The format is TOML so a person can open,
   read, and hand-edit a Chart. A human authoring a Chart knows the civil birth
   time, not the Julian Day — see §6 (Authoring).

4. **The file is the source of truth.** Any database, index, or vector
   representation is a derived, rebuildable artifact. Sharing a Chart means
   sharing its `.toml` file.

---

## 3. File identity

Every conformant file MUST begin with the spec marker at the top level:

```toml
spec = "open-astrology-chart"
spec_version = 1
```

- A reader MUST verify `spec == "open-astrology-chart"` before trusting the
  rest of the document.
- A reader MUST reject a `spec_version` it does not understand (forward
  compatibility is not guaranteed across major versions).
- A writer MUST emit both keys.

---

## 4. Field reference

Tables below list every field, its TOML type, whether it is required, and its
meaning. Unknown keys MUST be preserved on round-trip where practical, and MUST
NOT cause a read to fail (forward-compatible additions).

### 4.1 `[moment]` — the instant (required)

| Key  | Type  | Req | Meaning |
|------|-------|-----|---------|
| `jd` | float | **yes** | Julian Day in **Universal Time (UT)**. The canonical, authoritative instant. Emitted with full available precision. |

`jd` is UT-based (i.e. derived from UTC civil time). Delta-T / ephemeris-time
(TT) correction is the *consumer's* responsibility at calculation time
(e.g. Swiss Ephemeris applies it internally via `swe_calc_ut`). The file stores
JD(UT) so that it round-trips losslessly with the civil time a human entered.

### 4.2 `[location]` — the place (required)

| Key         | Type   | Req | Meaning |
|-------------|--------|-----|---------|
| `lat`       | float  | **yes** | Latitude in decimal degrees. Positive = north, negative = south. |
| `lon`       | float  | **yes** | Longitude in decimal degrees. Positive = east, negative = west. |
| `alt`       | float  | no  | Altitude in metres above sea level. Default `0`. Not part of the natural key. |
| `placename` | string | no  | Free-text place label, e.g. `"Noblesville, IN"`. |
| `country`   | string | no  | Country, e.g. `"USA"`. A discrete field — readers MUST NOT parse it out of `placename`. |

### 4.3 `[civil]` — advisory human-readable time (recommended)

A derived rendering of `[moment].jd` for human eyes. **Advisory only.**
Consumers MUST treat `jd` as canonical; on any disagreement, `jd` wins.

| Key          | Type   | Req | Meaning |
|--------------|--------|-----|---------|
| `date`       | string | no  | Local civil date, `YYYY-MM-DD`. |
| `time`       | string | no  | Local civil time, `HH:MM:SS` (24-hour). |
| `utc_offset` | float  | no  | Base offset from UTC in hours, east-positive (IST = `5.5`, EST = `-5.0`). |
| `dst_offset` | float  | no  | Additional daylight-saving offset in hours. Default `0`. |
| `timezone`   | string | no  | Named time zone the civil time is expressed in, e.g. `"EST"`, `"PDT"`, `"IST"` (or an IANA name like `"America/New_York"`). A human-facing **label only** — the authoritative numeric offset is `utc_offset` (+ `dst_offset`), never parsed from this string. |

Total local offset = `utc_offset + dst_offset`. Local civil time =
`UTC + (utc_offset + dst_offset)`. A writer SHOULD emit `[civil]` (computed from
`jd` and `utc_offset`) so the file is readable; a reader SHOULD ignore it for
computation once `jd` is present.

### 4.4 Top-level metadata

| Key      | Type            | Req | Meaning |
|----------|-----------------|-----|---------|
| `name`   | string          | no  | Subject or event name. Default `""`. |
| `gender` | string          | no  | `"male"`, `"female"`, `"unknown"`, or any other free string. Omit if unknown. |
| `rodden` | string          | no  | Rodden rating of data reliability (`"AA"`, `"A"`, `"B"`, `"C"`, `"DD"`, `"X"`, `"XX"`). |
| `tags`   | array of string | no  | Freeform user labels, e.g. `["vedic", "celebrity"]`. Order not significant; duplicates SHOULD be removed. |
| `notes`  | string          | no  | Free-text notes. May be multi-line (TOML `"""…"""`). |

> **Not in this format:** Collections (named groups of Charts) are *not* stored
> in the Chart file — a Chart can belong to many Collections, which live in a
> sidecar. Computed positions (planets, houses) are derived Expressions, not
> Chart data, and are not persisted here.

---

## 5. Natural key

The natural key is `(moment.jd, location.lat, location.lon)`.

- It identifies the **astronomical moment**, not the identity of the subject.
- It is a **soft** key: a deduplication hint. Implementations MAY warn on a
  collision but MUST NOT lose data because of one. Storing two Charts with the
  same natural key and different metadata is legal.
- Comparison is on the stored floating-point values. Because `jd` carries
  sub-second resolution, real-world distinct moments practically never collide.

---

## 6. Authoring and canonicalization

A human creating a Chart by hand knows the civil birth time, not the Julian Day.
The format supports this without making `jd` non-canonical:

1. A human MAY write a file containing only `[civil]` (date, time, utc_offset)
   and `[location]`, omitting `[moment].jd`.
2. On first read, a conformant tool MUST derive `jd` from the civil time and
   offset, then SHOULD rewrite the file with `[moment].jd` populated.
3. After `jd` exists, it is authoritative. The tool regenerates `[civil]` from
   `jd` and `utc_offset` for display; the civil fields are no longer an input.

This gives civil-time authoring convenience while keeping JD the stored truth.
A file with neither `[moment].jd` nor a usable `[civil]` time is malformed.

---

## 7. Round-trip fidelity

Write → read → write MUST produce a byte-identical file. Requirements:

- `jd` MUST be serialized with enough precision to reconstruct the exact stored
  `double` (no truncation of fractional days).
- `lat`, `lon`, `alt` MUST preserve their full stored precision.
- Field and table ordering produced by a writer MUST be stable.
- Optional fields that are absent MUST NOT be emitted (no `null`s, no empty
  strings written for omitted values).
- `tags` ordering MUST be stable (e.g. as-stored or sorted — pick one and keep it).

---

## 8. Examples

### 8.1 Minimal (machine-canonical)

```toml
spec = "open-astrology-chart"
spec_version = 1

[moment]
jd = 2447679.3388888887

[location]
lat = 40.045833
lon = -86.023611
```

### 8.2 Full

```toml
spec = "open-astrology-chart"
spec_version = 1

name = "Jane Doe"
gender = "female"
rodden = "AA"
tags = ["celebrity", "vedic", "rectification"]
notes = """
Birth time from official records.
Rectified against two life events.
"""

[moment]
jd = 2447679.3388888887

[location]
lat = 40.045833
lon = -86.023611
alt = 235.0
placename = "Noblesville, IN"
country = "USA"

[civil]
date = "1989-12-14"
time = "20:08:00"
utc_offset = -5.0
dst_offset = 0.0
timezone = "EST"
```

### 8.3 Human-authored (pre-canonicalization)

A file a person can type by hand; a tool fills in `[moment].jd` on first read.

```toml
spec = "open-astrology-chart"
spec_version = 1

name = "Jane Doe"

[location]
lat = 40.045833
lon = -86.023611
placename = "Noblesville, IN"
country = "USA"

[civil]
date = "1989-12-14"
time = "20:08:00"
utc_offset = -5.0
```

---

## 9. Conformance

A **reader** is conformant if it:
- verifies the `spec` marker and rejects unknown `spec_version`;
- treats `[moment].jd` as canonical when present;
- derives `jd` from `[civil]` when `jd` is absent (§6);
- tolerates natural-key collisions and unknown keys without failing.

A **writer** is conformant if it:
- emits the `spec` marker and `spec_version`;
- emits `[moment].jd` at full precision;
- omits absent optional fields;
- produces stable, round-trippable output (§7).

---

## Appendix A. Mapping to the Aion chart-db schema

Reference only — informative, not part of the open format.

| TOML field            | `charts` column |
|-----------------------|-----------------|
| `moment.jd`           | `jd`            |
| `location.lat`        | `lat`           |
| `location.lon`        | `lon`           |
| `location.alt`        | `alt`           |
| `name`                | `name`          |
| `gender`              | `gender`        |
| `location.placename`  | `placename`     |
| `location.country`    | `country`       |
| `civil.utc_offset`    | `utc_offset`    |
| `civil.dst_offset`    | `dst_offset`    |
| `notes`               | `notes`         |
| `rodden`              | `rodden`        |
| `tags`                | `chart_tags` (join table) |

`civil.date` / `civil.time` / `civil.timezone` are advisory (derived from `jd`
or display-only labels) and are not stored as columns.
`source_path`, `created_at`, `updated_at` are local DB bookkeeping and are not
part of the portable file.
