# Now button and current-time selection

## Purpose

Five metric/display pages can provide a **Now** button so the user can immediately return the displayed values to the half-hour containing the current UK time:

1. Octopus Agile Prices
2. Solar Forecast
3. PV Forecast
4. Net Electricity Price
5. Cost Savings

PV Forecast, Net Electricity Price and Cost Savings are hidden when `Solar PV panels installed` is off, so their Now controls are also absent in that state. App Settings and User Guide do not show Now.

## Behaviour

Tapping **Now**:

- changes the shared selected date to today;
- loads today's Agile prices if required;
- loads today's solar forecast if required;
- selects the Agile half-hour containing the current time;
- selects the solar irradiance half-hour containing the current time;
- refreshes PV Forecast, Net Electricity Price and Cost Savings so their selected period is the current half-hour.

If today's source data is already loaded, the app reuses it rather than forcing an unnecessary network download.

The current period test is:

```text
validFrom <= now < validTo
```

If no period contains the current time, the first available period is used as a safe fallback.

## Adaptive placement

The Now control is not positioned with fixed top offsets inside a floating overlay.

Instead:

- Solar Forecast, PV Forecast, Net Electricity Price and Cost Savings place a dedicated right-aligned Now row below the adaptive page header and above page-specific metric content;
- Octopus Agile Prices uses a reserved safe-area row above the bottom navigation;
- surrounding scroll views can naturally move content on shorter screens;
- no device-specific vertical positioning is required.

Metric headers themselves can reflow on narrow screens, so the Now row remains separate from title, date, settings and information controls.

For wider displays, the metric content is centred and width-limited. See [`SCREEN_LAYOUT_AND_DEVICE_SUPPORT.md`](SCREEN_LAYOUT_AND_DEVICE_SUPPORT.md) for the full screen-size strategy.

## Shared date

The selected date is shared across all visible metric pages. Tapping Now on any of them returns the metric dashboard to today.

## Accessibility

The Now control has the accessibility label:

```text
Show values for the current time
```

## Testing

For each visible metric page:

1. select a non-current half-hour;
2. tap **Now**;
3. confirm the highlighted wheel sector is the half-hour containing the current time;
4. confirm centre/selected metrics correspond to that sector;
5. confirm Now occupies its own layout space and never obscures headings, descriptive text, source status, wheel sectors, metric cards, tabs or other controls.

Repeat the layout check on:

- a small iPhone width;
- a standard iPhone;
- a large/Max iPhone;
- regular-width iPad layout;
- at least one larger Dynamic Type setting.

For Cost Savings, confirm the selected saving corresponds to the same current half-hour used by Net Electricity Price.

Also test after selecting tomorrow or another date. Tapping Now must return the shared selected date to today and select the current half-hour.
