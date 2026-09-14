# Now button and current-time selection

## Purpose

Five metric/display pages provide a **Now** button so the user can immediately return the displayed values to the half-hour containing the current UK time.

The affected pages are:

1. Octopus Agile Prices
2. Solar Forecast
3. PV Forecast
4. Net Electricity Price
5. Cost Savings

App Settings and User Guide do not show a Now button because they do not display half-hour metrics.

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

The Now control is no longer positioned with fixed top offsets inside a floating `ZStack` overlay. That approach could cover descriptive text or other controls on different iPhone screen sizes.

Instead, the control now participates in normal SwiftUI layout:

- Solar Forecast, PV Forecast, Net Electricity Price and Cost Savings place a dedicated right-aligned Now row directly below the page header and above the page-specific metric content;
- Octopus Agile Prices uses a reserved safe-area row above the bottom navigation so the control cannot obscure the existing price-page header, wheel, summary cards or tab control;
- no fixed per-device vertical positioning is used;
- the surrounding `ScrollView` can naturally move content on shorter screens.

This makes the control substantially more robust across supported iPhone sizes because SwiftUI allocates real layout space for the button instead of drawing it over other views.

## Shared date

The selected date is shared across all five metric pages. Tapping Now on any of them returns the whole metric dashboard to today.

## Accessibility

The Now control has the accessibility label:

```text
Show values for the current time
```

## Testing

For each of the five metric pages:

1. select a non-current half-hour;
2. tap **Now**;
3. confirm the highlighted wheel sector is the half-hour containing the current time;
4. confirm the centre/selected metrics correspond to that sector;
5. confirm the Now control occupies its own layout space and never obscures headings, descriptive text, source-status text, wheel sectors, metric cards, tabs or other controls;
6. repeat on the smallest and largest supported iPhone screen sizes, in both portrait and any supported larger text settings.

For Cost Savings, confirm the selected saving corresponds to the same current half-hour used by Net Electricity Price.

Also test after selecting tomorrow or another date. Tapping Now must return the shared selected date to today and then select the current half-hour.

Test with cached data and with a network connection. The control must not appear on App Settings or User Guide.
