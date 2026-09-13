# Agile Price Wheel

Agile Price Wheel is a native SwiftUI iPhone/iPad application for viewing Octopus Energy Agile electricity prices as an interactive 24-hour price wheel.

The app discovers currently available Octopus Agile import tariffs from the public Octopus Energy REST API, downloads the published half-hour prices for a selected UK calendar day, displays them visually, and caches previously downloaded tariff/rate data for offline use.

The project is deliberately lightweight: it uses only Apple frameworks and has no third-party package dependencies.

---

## Main features

- Dynamic discovery of currently available **Octopus Energy Agile import tariffs**.
- Support for all UK Octopus electricity regions represented by the API.
- Half-hour prices including and excluding VAT.
- Interactive circular price wheel.
- Tap/drag selection of individual half-hour periods.
- Selected price plus start/end time.
- Lowest price plus its half-hour time.
- Highest price plus its half-hour time.
- Daily average price.
- Relative day colour scale:
  - blue for negative prices,
  - green for cheaper positive periods,
  - yellow/orange through to red for more expensive periods.
- Prices, Chart and Details views.
- Offline-first persistent cache.
- Manual **Refresh from Octopus** action.
- Clear **SERVER DATA**, **LOCAL CACHE** or **NO DATA** status.
- UK BST/GMT handling for 46-, 48- and 50-period days.
- In-app **Guide & Documentation** available from the information button.
- No Octopus login, API key, MPAN or meter credentials required for the public tariff/rate endpoints used by the app.

---

## Architecture

```text
AgilePriceWheelApp
        |
        v
AgileViewModel
        |
        +----> OctopusAPI
        |        |
        |        +----> Octopus Energy REST API
        |
        +----> AgileCacheStore
        |        |
        |        +----> Application Support JSON cache
        |
        +----> TariffOption / HalfHourRate models
        |
        v
ContentView
        |
        +----> PriceWheelView
        +----> PriceColourScale
        +----> DocumentationView
```

`AgileViewModel` is the central state controller. The SwiftUI views do not perform network requests directly.

---

## Source files

### `AgilePriceWheelApp.swift`

Application entry point. It creates one `AgileViewModel` as a `@StateObject` and injects it into the SwiftUI hierarchy through `.environmentObject(...)`.

### `AgileViewModel.swift`

Owns the application state and coordinates:

- available tariffs,
- selected tariff,
- selected date,
- downloaded/cached rates,
- selected half-hour,
- loading/error state,
- server/cache source status,
- refresh behaviour.

It also calculates daily minimum, maximum and average prices.

The view model is `@MainActor` isolated because its published values directly drive SwiftUI.

### `OctopusAPI.swift`

Networking layer using:

- `URLSession`,
- `URLComponents`,
- `JSONDecoder`,
- Swift `async`/`await`.

The base API is:

```text
https://api.octopus.energy/v1/
```

It discovers products, retrieves product detail, identifies Agile import tariffs, follows API pagination, and downloads standard unit rates for the requested UK local day.

### `AgileCacheStore.swift`

Persistent offline cache stored under the app's **Application Support** directory.

It stores:

- the latest tariff-list snapshot,
- one rate snapshot for each tariff/date combination successfully downloaded.

The cache uses Codable JSON files and atomic writes.

### `Models.swift`

Contains the decoded API models and app models, including:

- `ProductPage`,
- `ProductSummary`,
- `ProductDetail`,
- `ElectricityTariff`,
- `TariffOption`,
- `RatePage`,
- `HalfHourRate`,
- UK region-name mapping.

`HalfHourRate` is Codable so rate data can be both decoded from Octopus and encoded into the local cache.

### `PriceColour.swift`

Implements the day-relative colour scale.

Positive prices are normalised between the selected day's minimum and maximum, then mapped from green through yellow/orange to red. Negative prices are always blue.

The colour scale therefore describes **relative cost within the selected day**, not fixed universal price thresholds.

### `PriceWheelView.swift`

Renders the circular price wheel and handles user interaction.

The wheel uses the actual number of rates returned, so it works with 46, 48 or 50 settlement periods.

Touch/drag position is converted to an angle and then into the corresponding half-hour index. The chosen sector is highlighted and its price/time becomes the selected rate.

### `ContentView.swift`

Main dashboard.

It provides:

- header and source-status indicator,
- settings button,
- information/documentation button,
- Prices tab,
- Chart tab,
- Details tab,
- lowest/highest/average/chosen-slot tiles,
- tariff/day settings,
- manual refresh,
- error/no-data handling.

The information button opens `DocumentationView`.

### `DocumentationView.swift`

User-facing guide shipped inside the app.

It explains:

- how the wheel works,
- selected/lowest/highest times,
- colours,
- tabs,
- tariff/day selection,
- server versus local-cache status,
- manual refresh,
- offline behaviour and limitations,
- Octopus API use,
- privacy/local storage,
- architecture/dependencies,
- documentation-maintenance policy.

Because this view is part of the app binary, the guide remains available without a network connection.

---

## Octopus tariff discovery

The app does not rely on one hard-coded Agile product code.

It retrieves the Octopus product catalogue and keeps products that:

- identify as Agile by code/name,
- are import products,
- belong to Octopus Energy where brand metadata is present,
- are still available.

It then retrieves each matching product's detail and extracts electricity tariffs that expose a `standard_unit_rates` link.

A `TariffOption` contains:

- product code,
- product name,
- tariff code,
- region code,
- payment method,
- standing charge including VAT when supplied.

The user's selected tariff code is remembered using `UserDefaults`.

---

## Half-hour rate retrieval

For the selected tariff the app requests:

```text
/v1/products/{product-code}/electricity-tariffs/{tariff-code}/standard-unit-rates/
```

with:

```text
period_from
period_to
page_size=100
```

The requested day's boundaries are calculated using a `Europe/London` calendar. API timestamps are sent as UTC ISO-8601 values.

The API client follows pagination until all matching rates have been downloaded, then filters and sorts them by `valid_from`.

---

## UK daylight-saving handling

A UK electricity day must not be assumed to contain exactly 48 half-hours.

The application uses a UK calendar configured to `Europe/London` and calculates the end of the selected day by adding one local calendar day to its local start.

Therefore:

- normal day: **48** half-hours,
- spring clock change: **46** half-hours,
- autumn clock change: **50** half-hours.

The price wheel divides itself by `rates.count`, so DST days render correctly.

---

## Offline cache and refresh behaviour

The application is offline-first.

### Startup

On startup it attempts to:

1. load the cached tariff list,
2. restore the last selected tariff,
3. load cached rates for the selected tariff/date,
4. display cached data immediately when available,
5. contact Octopus,
6. replace cached data with fresh server data if successful,
7. keep cached data if the network/server request fails.

### Rate snapshots

Each tariff/day pair is stored independently with:

```text
RateSnapshot
├─ savedAt
├─ tariffCode
├─ dayKey
└─ rates[]
```

This means any tariff/date previously downloaded can later be displayed offline.

### Data-source indicator

The UI tells the user where the currently displayed data came from:

```text
SERVER DATA · updated <time>
LOCAL CACHE · saved <date/time>
NO DATA
```

If a refresh fails while cached data is available, cached information remains on screen.

### Manual refresh

Open **Settings** and choose **Refresh from Octopus**.

A successful refresh updates both the displayed data and persistent cache. A failed refresh never deliberately deletes valid cached data.

### Offline limitation

The app cannot invent or download a tariff/day that has never previously been cached. An internet connection is required for newly published prices or newly discovered tariffs.

---

## Main screen behaviour

### Prices

The Prices tab shows:

- interactive wheel,
- lowest price and its half-hour,
- highest price and its half-hour,
- average price,
- selected/chosen price and half-hour.

Small time labels are intentionally used in the summary tiles so the existing two-column dashboard layout is preserved.

### Chart

Lists each half-hour and provides a visual bar representation of the day's price values.

### Details

Shows precise information for the chosen half-hour plus the selected tariff's metadata.

---

## In-app documentation

Tap the **ⓘ information button** at the top-right of the main dashboard to open **Guide & Documentation**.

This documentation is local to the app and does not depend on GitHub or a live network connection.

The GitHub `README.md` is the comprehensive developer/technical reference; `DocumentationView.swift` is the user-facing companion.

---

## Documentation maintenance policy

The repository also contains:

```text
DOCUMENTATION_POLICY.md
```

The rule for this project is:

> Any future change that affects features, controls, calculations, API behaviour, caching, networking, setup, dependencies, privacy, build or deployment must update the relevant documentation in the same change.

At minimum, a functional change should review and update as necessary:

```text
README.md
AgilePriceWheel/DocumentationView.swift
```

This is part of the definition of done for future updates.

---

## Privacy and credentials

The current version does **not** request or store:

- Octopus login credentials,
- Octopus API keys,
- account numbers,
- MPANs,
- meter serial numbers,
- payment information,
- user location.

The app stores only:

- the selected tariff preference in `UserDefaults`,
- public tariff metadata and public half-hour rates in Application Support for offline use.

---

## Dependencies

### Third-party packages

**None.**

No Swift Package Manager, CocoaPods or Carthage dependency-installation step is required.

### Apple frameworks

The project uses:

- SwiftUI,
- Foundation,
- Combine.

Networking uses `URLSession`; JSON uses `JSONEncoder`/`JSONDecoder`; simple preference persistence uses `UserDefaults`.

### External service

Fresh tariff/rate retrieval depends on availability of the public Octopus Energy REST API.

Cached data and the in-app documentation remain available offline.

---

## Xcode / build setup

The checked-in project was created with Xcode 26.6 and currently contains:

```text
PRODUCT_BUNDLE_IDENTIFIER = KRH.AgilePriceWheel
MARKETING_VERSION = 1.0
CURRENT_PROJECT_VERSION = 1
```

The checked-in project currently uses an iOS deployment target of **26.5**.

### Clone

```bash
git clone https://github.com/rhine59/AgilePriceWheel.git
cd AgilePriceWheel
open AgilePriceWheel.xcodeproj
```

### Signing

In Xcode:

1. Select the AgilePriceWheel project.
2. Select the AgilePriceWheel app target.
3. Open **Signing & Capabilities**.
4. Enable **Automatically manage signing**.
5. Select your Apple Developer team.
6. Change the bundle identifier if required for another developer account.

No Octopus API secret is required.

### Simulator

Select an iPhone simulator and press:

```text
⌘R
```

### Physical iPhone

1. Connect/trust the iPhone.
2. Enable Developer Mode if required.
3. Select the device in Xcode.
4. Confirm signing team.
5. Press `⌘R`.

---

## Building for distribution

1. Select the appropriate generic iOS/device destination.
2. Choose **Product → Archive**.
3. Open the resulting archive in Organizer.
4. Choose **Distribute App**.

The available distribution choices depend on the Apple Developer membership and signing configuration.

---

## Error handling

The API layer provides explicit errors for:

- invalid URL creation,
- date-calculation failure,
- non-success HTTP responses,
- JSON decoding failure.

If no rates are published for a requested date, the app shows a no-data message.

If server refresh fails but cached rates exist, the cached rates remain usable and the data-source indicator identifies them as local data.

---

## Concurrency

The app uses Swift structured concurrency (`async`/`await`).

`AgileViewModel` and the current API client are MainActor isolated to align with the project's actor-isolation settings and SwiftUI state updates.

`URLSession` network operations remain asynchronous while being awaited.

---

## Testing checklist

Before a release or significant commit, test at least:

- successful tariff discovery,
- selected tariff persistence,
- current/future date selection,
- 48-period normal day,
- 46-period spring DST day,
- 50-period autumn DST day,
- touch/drag wheel selection,
- lowest/highest/selected time labels,
- negative-price colouring,
- Prices/Chart/Details tabs,
- server-data status,
- manual refresh,
- cached startup,
- Airplane Mode/local-cache operation,
- no-cache/no-network state,
- in-app Guide & Documentation,
- README and in-app documentation consistency.

Automated unit/UI coverage can be expanded around API decoding, caching, DST handling, colour mapping and interaction.

---

## Git workflow

Typical local workflow:

```bash
git pull
git status
git add .
git commit -m "Describe the change"
git push
```

For functional changes, include documentation updates in the same commit or change set.

---

## Design decisions

**Dynamic tariff discovery**  
Avoids tying the app to one historic Agile tariff code.

**UK local-day calculation**  
Handles BST/GMT correctly instead of assuming every day is exactly 24 hours.

**Day-relative price colours**  
Optimised for quickly finding the cheaper/more expensive periods within the displayed day.

**Simple JSON cache**  
Agile rate datasets are small, so Codable JSON snapshots avoid unnecessary database complexity while providing reliable offline use.

**No third-party libraries**  
Keeps setup, maintenance and dependency risk low.

**Bundled in-app guide**  
Ensures help remains available when offline and keeps user-facing documentation alongside the code that implements the interface.

---

## Possible future enhancements

- cache-age/size controls and selective cache clearing,
- cheap/negative-price notifications,
- configurable fixed colour thresholds,
- Home Screen widgets,
- Apple Watch support,
- postcode-assisted region selection,
- comparison of multiple Agile days,
- EV/battery/smart-load integrations,
- CSV/JSON export,
- broader automated test coverage.

---

## Disclaimer

Agile Price Wheel is an independent application that consumes publicly available Octopus Energy tariff data. It is not an official Octopus Energy application.

Prices should be checked against the user's actual Octopus tariff/account before being relied upon for billing or other financial decisions.
