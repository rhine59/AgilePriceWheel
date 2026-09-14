# Now button and current-time selection

## Purpose

The four metric/display pages provide a **Now** button so the user can immediately return the displayed values to the half-hour containing the current UK time.

The affected pages are:

1. Octopus Agile Prices
2. Solar Forecast
3. PV Forecast
4. Net Electricity Price

App Settings and User Guide do not show a Now button because they do not display half-hour metrics.

## Behaviour

Tapping **Now**:

- changes the shared selected date to today;
- loads today's Agile prices if required;
- loads today's solar forecast if required;
- selects the Agile half-hour containing the current time;
- selects the solar irradiance half-hour containing the current time;
- refreshes the PV Forecast view so its selected half-hour is the current period;
- refreshes the Net Electricity Price view so its selected half-hour is the current period.

If today's source data is already loaded, the app reuses it rather than forcing an unnecessary network download.

The current period test is:

```text
validFrom <= now < validTo
```

If no period contains the current time, the first available period is used as a safe fallback.

## Placement

The Now control is anchored in the unused dark area above and to the right of the wheel. It is no longer placed near the bottom-right of the page, where it could cover cards or other information on some iPhone screen sizes.

`SwipeDashboardView` uses a page-specific top offset:

- Octopus Agile Prices: slightly lower to clear the price-page title/header controls;
- Solar Forecast, PV Forecast and Net Electricity Price: aligned in the dark space below the page header and above/right of the wheel.

The button uses an opaque/dark capsule background so it remains visually distinct from the dashboard without obscuring useful content.

## Shared date

The selected date is shared across Octopus Agile Prices, Solar Forecast, PV Forecast and Net Electricity Price. Tapping Now on any of those pages therefore returns the whole metric dashboard to today.

## Display title

The first dashboard page is presented as:

```text
Octopus Agile Prices
```

The Xcode project/repository name remains `AgilePriceWheel`.

## Accessibility

The Now control has the accessibility label:

```text
Show values for the current time
```

## Testing

For each of the four metric pages:

1. select a non-current half-hour;
2. tap **Now**;
3. confirm the highlighted wheel sector is the half-hour containing the current time;
4. confirm the centre/selected metrics correspond to that sector;
5. confirm the Now button is in unused dark space above/right of the wheel and does not cover wheel sectors, metric cards, headings or page controls.

Also test after selecting tomorrow or another date. Tapping Now must return the shared selected date to today and then select the current half-hour.

Test with cached data and with a network connection. The control must not appear on App Settings or User Guide. Check the layout on smaller and larger supported iPhone screen sizes.
