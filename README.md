# Docquet

Docquet is a freelance daybook. Tap a day on the month grid, file cash or miles against a project, and keep billed versus personal on the device. There is no bank link and no invoice builder.

## Who it is for

Freelancers who need a calendar blotter for expenses and mileage by project, not a full accounting suite.

## Architecture

**Odometer-chain encoding.** Each `Job` stores `lastEndMiles`. A `Trip` writes `startMiles` and `endMiles`; distance is end minus start; filing the trip advances `lastEndMiles`. A cash `Outlay` writes amount only and never moves the chain. The job `Rate` is snapshotted onto the trip at file time, so later rate edits do not rewrite old miles. `billableAmount` is the amount when cash is billable, or distance times that snapshotted rate when the trip is billable, else 0. Month totals fold only `billableAmount`, bucketed by daykey Int YYYYMMDD from `Calendar.current.startOfDay`.

This pattern fits the product because the home verb is file-the-line, not send-an-invoice. The next mileage line must start where the last one ended, and cash must stay off that chain. One observable `Daybook` owns mutation. Views call `fileLine(_:)` through `DaybookSession` and never write `lastEndMiles` or `UserDefaults`.

## Unique feature

**Odometer-chain trip.** Home is the month grid. Tapping a day expands an inline blotter instead of pushing a form. A mileage line prefills start miles from that project's last end reading; the user types end miles; filing advances the chain. A cash outlay skips the chain. File stays enabled on seeded home, with one haptic on success. Balance is billed versus personal by project — only billable amounts fill the month buckets.

That chain is why someone would pick Docquet over a generic expense list: miles stay continuous per project without a spreadsheet.

## Art

Style: 3D glass render, glassmorphism. Base prompt reused for every asset:

```
3D glass render, glassmorphism, frosted translucent planes, refractive edges, soft studio diffusion, clinical still-life, overlapping glass sheets with depth, precision instrument mood, no text in the frame
```

Exact prompts:

**dcq_AppIcon** — 3D glass month-grid emblem, one cell standing proud, filling the canvas edge to edge, no text, no rounded mask, no transparency

**dcq_Splash** — vertical 3D glass month grid fading to a quiet uncluttered centre band, glassmorphism, clinical studio, no wordmark in the art

**dcq_Onboarding1** — freelancer with a glass daybook open to a month grid, isolated subject, frosted refractive glass, clinical studio

**dcq_Onboarding2** — a finger tapping a glass day cell while a cash-or-miles blotter unfolds from it, mid-gesture, isolated subject

**dcq_Onboarding3** — two glass columns of billed versus personal totals beside job labels, accumulated daybook, isolated subject

**dcq_EmptyHome** — empty glass month grid with blank day cells waiting for ink, calm, isolated subject

**dcq_EmptyList** — empty glass daybook with no job columns and no filed lines, isolated subject

**dcq_CardBackdrop** — abstract frosted glass panes overlapping at low contrast, fill the canvas, no text

**dcq_ControlFace** — face of a single glass day-cell used as the file control, isolated subject

**dcq_TwistHero** — linked glass odometer drums showing a start-to-end mileage chain, isolated subject

**dcq_SuccessMark** — small glass filed-line stamp, isolated subject

**dcq_HeaderDecor** — wide frosted glass month-band ornament, isolated subject

Cut-outs (everything except AppIcon, Splash, CardBackdrop) use a real PNG alpha channel and transparent corners.

## How this differs

This is not a food tracker, not Kentledge's cut-and-seat subscription beam, and not Notchmark's cost-per-use rail. The home verb is file-the-line on a calendar blotter: cash writes amount, miles write an odometer pair that chains from the project's last end reading, and only billableAmount folds into Balance by day. Waywiser's Trip register is a tally clicker, not mileage. There is no bank sync, no invoice builder, and no game tab named Balance.

## Build

```bash
cd Docquet
xcodegen generate
xcodebuild -scheme Docquet -destination 'generic/platform=iOS' CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO build
xcrun simctl list devices available
xcodebuild -scheme Docquet -destination 'platform=iOS Simulator,id=<UDID>' test
```

iOS 17, Swift 6.2, no Swift packages. Simulator seed `dcq.demo.v1` fills several projects, cash and mileage lines, advances the chain, marks onboarding complete, and leaves File enabled. `-ReviewScreen today|log|goals` opens Expenses, Balance, and Settings after onboarding.
