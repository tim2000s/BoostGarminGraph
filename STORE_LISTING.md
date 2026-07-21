# Connect IQ Store listing — Boost Graph

Draft copy for the store submission. Edit to taste before uploading.

## Package
- **File to upload:** `boost.iq` (built with `monkeyc -f monkey.jungle -o boost.iq -y developer_key -e -r -w`)
- **App id:** `bedda0f6800d4663a3c59a53cf5a2baf` (stable — never regenerate; register this as a NEW app, separate from Boost BG Ring)
- **Signing key:** `developer_key` — the SAME key as Boost BG Ring; every update must reuse it.
- **Devices:** 162 products build-verified (`162 OUT OF 162 DEVICES BUILT`).

## Name
Boost Graph

## Category
Watch Faces

## Short description (one line)
Glucose, trend, a 12-point BG graph and loop data for AndroidAPS / Boost users.

## Full description
Boost Graph is a data-dense companion watch face for **AndroidAPS** (and the Boost fork).
It surrounds a full data layout with the colour-banded Boost BG ring, and adds a rolling
12-point glucose trend graph so you can see where BG has been, not just where it is.

- Colour-banded Boost BG ring (low / in-range / high) around the outside
- Current glucose (band-coloured) with trend arrow and 5-minute delta
- IOB and temp basal (TBR) from the loop
- 12-point BG trend graph with in-range guide lines
- Large hero clock, with date, on-device steps and heart rate
- Battery, and data-age (greys out when the reading is stale rather than lying)
- mmol/L or mg/dL automatically, matching your AndroidAPS setting
- Battery-friendly always-on (AOD) mode

**Requires AndroidAPS with the Garmin data source enabled** — the face pulls glucose and
loop data from the AndroidAPS phone app over the Garmin Connect bridge. Without an
AndroidAPS phone running that data source it shows no data. This is a tool for people
already running AndroidAPS/Boost; it is not a standalone CGM display.

Not affiliated with Garmin or Dexcom. Boost/AndroidAPS is DIY open-source software; use
at your own risk.

## Screenshots
In `store_assets/` — one per resolution family, populated with sample data:
`venu3_454.png` (native capture), `venu2_416.png`, `vivoactive5_390.png`, `fenix7_260.png`.
NB the venu3 shot is a native simulator capture; the other three are scaled from it to each
family's native resolution (the layout scales proportionally). Regenerate per-device native
captures if you want exact MIP (fenix) rendering — the sim's File → Save Screen Capture per device.

## Hero image
`store_assets/hero_1440x720.png` — 1440×720 mobile promo banner.

## Pricing
Free.

## Languages
English.
