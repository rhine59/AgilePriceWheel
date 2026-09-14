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

## Placement

The Now control is anchored at the trailing edge in the unused dark band immediately above the wheel area. It must not cover page descriptions, source-status text, wheel sectors, metric cards or other controls.

The vertical clearance is deliberately larger than the original implementation after testing on a physical iPhone showed that the earlier position could cover descriptive text on Solar Forecast, Net Electricity Price and Cost Savings. The Octopus Agile Prices page retains its own page-specific offset because its header layout differs from the other metric pages.

The placement must be checked on all supported iPhone screen sizes whenever page-header or wheel geometry changes.

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
5. confirm the Now control does not obscure the page description, source-status text, wheel, or metric cards.

For Cost Savings, confirm the selected saving corresponds to the same current half-hour used by Net Electricity Price.

Also test after selecting tomorrow or another date. Tapping Now must return the shared selected date to today and then select the current half-hour.

Test with cached data and with a network connection. The control must not appear on App Settings or User Guide and must not obscure content on supported iPhone sizes.
