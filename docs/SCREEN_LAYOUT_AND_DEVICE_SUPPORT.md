# Screen layout and device support

## Purpose

Agile Price Wheel uses adaptive SwiftUI layout rules so the dashboard remains usable across supported iPhone and iPad screen sizes without relying on device-specific pixel offsets.

The layout should prefer content reflow, scaling and reserved layout space over floating overlays or hard-coded positions.

## Main dashboard layout

`SwipeDashboardView` owns the top-level adaptive layout for the metric pages, settings page and bottom navigation.

Key rules:

- metric content is centred and constrained to a sensible maximum width on wider displays;
- compact-width devices use smaller horizontal margins;
- regular-width devices use wider margins and a larger maximum content width;
- wheels continue to size from available width and keep a square aspect ratio;
- the Now button occupies normal layout space rather than floating over page content;
- page headers use `ViewThatFits` to select a normal horizontal layout or a compact stacked layout when width is restricted;
- Settings uses the same horizontal/stacked fallback approach;
- the Octopus Agile Prices title overlay reserves space for the gear and information controls and scales down if necessary.

## Bottom navigation

The bottom navigation uses `ViewThatFits(in: .horizontal)` with three progressively more compact presentations:

1. normal icon + label;
2. compact icon + label;
3. icon-only fallback.

All variants preserve the same accessibility labels and at least a 44-point-high tap target.

When `Solar PV panels installed` is on, seven page buttons are available:

```text
Prices   Solar   PV   Net   Save   Settings   Guide
```

When PV is off, the PV-dependent buttons are removed and the bar contains:

```text
Prices   Solar   Settings   Guide
```

The PV button uses `bolt.fill`.

## Header adaptation

Metric-page headers use `ViewThatFits`:

- on sufficient width, settings and information buttons sit to either side of the centred title/date;
- on narrower widths, the buttons occupy their own top row and the title/date are centred below them.

This avoids title/button collisions on smaller iPhones and when text requires more width.

## Wide-screen behaviour

On regular-width layouts, content is centred instead of stretching indefinitely. This keeps wheels, cards and text readable on larger iPhones in landscape and on iPad.

The current top-level maximum content width is 760 points for regular-width screens and 680 points otherwise.

## Dynamic Type and accessibility

Important controls retain explicit accessibility labels. Navigation buttons preserve a minimum 44-point target height.

Text that must remain on one line uses `minimumScaleFactor` where appropriate. Headers can reflow into the compact stacked arrangement if horizontal space becomes insufficient.

Very large accessibility text sizes should still be tested manually because some dense metric cards and wheel-centre labels are inherently space-constrained.

## Required testing matrix

Before release, test at least:

- a small iPhone width (for example iPhone SE class);
- a current standard iPhone;
- a large/Max iPhone;
- landscape where supported;
- iPad/regular-width layout;
- PV enabled and PV disabled;
- normal text size and at least one larger Dynamic Type setting.

For each size verify:

- bottom navigation is not clipped;
- no page title collides with settings/info controls;
- Now never covers explanatory text, wheels or cards;
- all wheel sectors remain selectable;
- cards remain readable and scroll when vertical space is limited;
- Settings remains usable;
- turning PV off/on correctly removes/restores PV, Net and Save without breaking layout.

## Design rule for future changes

Do not add page-specific fixed offsets to solve overlap problems. Prefer SwiftUI layout primitives such as `ViewThatFits`, flexible frames, size-class-aware margins, scrolling, and maximum-width constraints.
