# Agile Price Wheel

Agile Price Wheel is a native SwiftUI iPhone/iPad application for viewing Octopus Energy Agile electricity prices as an interactive 24-hour price wheel.

The app discovers currently available Octopus Agile import tariffs directly from the public Octopus Energy REST API, allows the user to select the appropriate regional tariff, downloads the half-hour unit rates for a selected UK calendar day, and presents those prices visually so that low- and high-cost periods can be identified quickly.

The project is intentionally lightweight. It is written entirely in Swift/SwiftUI and currently has no third-party package dependencies.

---

## Features

- Discovers currently available **Octopus Energy Agile import tariffs** dynamically rather than relying on one hard-coded product or tariff.
- Supports all UK Octopus electricity regions represented by the Agile tariff data.
- Downloads the published **half-hourly unit rates including and excluding VAT**.
- Displays the day's prices as an interactive circular price wheel.
- Uses a relative colour scale:
  - **Blue** for negative prices.
  - **Green** for the cheaper positive prices of the selected day.
  - Green progresses through yellow/orange to **red** for the most expensive prices.
- Touch or drag around the wheel to select a half-hour period.
- Displays the selected period's price and time.
- Calculates the daily:
  - lowest price,
  - average price,
  - highest price.
- Remembers the last selected tariff using `UserDefaults`.
- Uses the **Europe/London** calendar and correctly handles UK daylight-saving transitions, including days containing **46, 48 or 50 half-hour periods**.
- Includes loading and error handling for tariff and price retrieval.
- Includes SwiftUI accessibility information for the price wheel.

---

## How the application works

The application follows a simple SwiftUI model/view structure:

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
        +----> HalfHourRate / TariffOption models
        |
        v
ContentView
        |
        +----> PriceWheelView
        |
        +----> PriceColourScale
```

`AgileViewModel` is the central application state. It obtains tariff and rate data through `OctopusAPI`, publishes the results to SwiftUI, and keeps track of the selected tariff, selected date and selected half-hour rate.

The views do not make network requests directly.

---

## Source files

### `AgilePriceWheelApp.swift`

This is the application entry point.

It creates one `AgileViewModel` as a `@StateObject` and injects it into the SwiftUI view hierarchy as an environment object:

```swift
@StateObject private var model = AgileViewModel()
```

`ContentView` and its child views therefore share the same application state.

---

### `AgileViewModel.swift`

`AgileViewModel` contains the application state and coordinates the user interface with the Octopus API.

It is declared `@MainActor` because its published properties drive the SwiftUI interface.

Important published state includes:

- `tariffs` — all discovered Agile tariff choices.
- `selectedTariff` — the tariff currently being displayed.
- `selectedDate` — the UK calendar day requested.
- `rates` — all half-hour rates returned for that day.
- `selectedRateID` — identifies the selected half-hour period.
- `isLoadingTariffs` and `isLoadingRates` — loading-state flags.
- `errorMessage` — a user-displayable error message.

It also calculates:

```swift
minPrice
maxPrice
averagePrice
selectedRate
```

### Application startup

When the main view appears, it calls:

```swift
await model.start()
```

`start()` now follows an **offline-first** sequence:

1. restore the last cached tariff list, if available;
2. restore cached half-hour prices for the selected tariff/date, if available;
3. immediately make that local data available to the UI;
4. attempt to refresh tariff metadata from Octopus;
5. attempt to refresh the selected day's prices from Octopus;
6. replace the local data with fresh server data when the requests succeed;
7. keep the cached data on screen if the network or Octopus API is unavailable.

After tariff discovery/restoration, the view model chooses a default tariff in this order:

1. The previously selected tariff stored in `UserDefaults`.
2. A Yorkshire (`_M`) tariff if available.
3. The first available Agile tariff.

It then automatically downloads the rates for the selected date.

### Tariff persistence

The selected tariff code is saved locally using:

```text
selectedTariffCode
```

in `UserDefaults`.

Only the tariff selection is persisted. Downloaded price data is not stored permanently; it is fetched again from Octopus when required.

### Rate selection

After rates are loaded, the app selects:

1. The half-hour containing the current time, if the selected day includes the current time.
2. Otherwise, the first rate in the returned day.

Touching or dragging around the price wheel updates `selectedRateID`.

---

## Octopus Energy API integration

### `OctopusAPI.swift`

`OctopusAPI` is the networking layer.

It uses Apple's native:

- `URLSession`
- `URL`
- `URLComponents`
- `JSONDecoder`
- Swift `async`/`await`

No external networking framework is required.

The base API URL is:

```text
https://api.octopus.energy/v1/
```

### Authentication

The product and standard-unit-rate endpoints used by this application are public endpoints. The current implementation therefore does **not** require:

- an Octopus account number,
- an Octopus API key,
- an MPAN,
- meter serial details,
- login credentials.

The app only reads public product and tariff price information.

### Tariff discovery

The app first obtains the Octopus product catalogue and follows API pagination until all product pages have been retrieved.

Products are filtered so that they:

- contain `AGILE` in the product code or product name,
- are import products,
- belong to Octopus Energy where brand information is supplied,
- have not passed their `available_to` date.

For each matching product, the app retrieves the full product detail and reads:

```text
single_register_electricity_tariffs
```

Tariffs that expose a `standard_unit_rates` link are converted into `TariffOption` values.

This means the application is not tied to one historical Agile product code. A newly available Agile product can be discovered through the API without changing the source code, provided Octopus continues to expose it through the same API structure.

---

## Retrieving half-hour rates

For the selected tariff, the API client builds an endpoint in the following form:

```text
/v1/products/{product-code}/electricity-tariffs/{tariff-code}/standard-unit-rates/
```

The request includes:

```text
period_from
period_to
page_size=100
```

The start and end of the requested day are calculated using a UK calendar configured for:

```text
Europe/London
```

The resulting dates are then sent to the Octopus API as UTC ISO-8601 timestamps.

The app follows the API `next` link until all pages of results have been collected, then:

1. filters the results to the requested local calendar day,
2. sorts them by `valid_from`,
3. publishes them to the interface.

---

## Daylight-saving time handling

UK electricity settlement periods can be 46, 48 or 50 half-hour slots because of BST/GMT transitions. The app computes the local day's start and end using `Calendar.uk` with `Europe/London` time zone, so
 the price wheel contains the actual number of rates for the day.

---

## Offline cache

### `AgileCacheStore.swift`

`AgileCacheStore` provides persistent on-device storage for the information required to use the app when no network connection is available.

The cache is stored beneath the app's **Application Support** directory in a dedicated `AgilePriceWheel` folder. It uses JSON files encoded with `JSONEncoder` and decoded with `JSONDecoder`.

The cache contains two kinds of snapshots:

### Tariff snapshot

The latest successfully downloaded tariff list is stored together with the date/time it was saved.

```text
TariffSnapshot
├─ savedAt
└─ tariffs[]
```

This keeps the tariff picker and previously selected tariff available offline.

### Rate snapshot

Each successfully downloaded tariff/date combination is stored independently:

```text
RateSnapshot
├─ savedAt
├─ tariffCode
├─ dayKey
└▀ rates[]
```

The filename combines the tariff code and UK local calendar date. This allows prices for multiple days and tariffs that have already been viewed to remain available offline.

Cache writes use atomic file replacement. A cache-write failure is deliberately non-fatal: live server data must still be shown even if local persistence fails.

### Offline-first behaviour

For a selected tariff/date, the app first restores any cached rate snapshot and then tries to obtain a fresh copy from Octopus.

If the server request succeeds :

- the screen displays the new server data;
- the cache is replaced with the fresh response;
- the source indicator identifies the information as server data.

If the request fails:

- cached data remains displayed when it exists;
- the source indicator identifies the information as local cache data;
- the app shows a non-destructive sync message explaining that refresh failed.

If neither server nor cache data exists for the requested tariff/date, the app shows the normal no-data/error state.

### Data-source indicator

The view model publishes a `DataOrigin` value:

```swift
.none
.server(Date)
.localCache(Date)
```

The interface converts this into a concise status such as:

```text
SERVER DATA · updated 21:15
LOCAL CACHE ·’ saved 12 Sep 16:42
NO DATA
```

This makes it explicit whether the currently displayed prices came from Octopus or from persistent local storage.

### Manual refresh

The interface provides an explicit **Refresh from Octopus** action. Refresh attempts to update both the available Agile tariff metadata and the half-hour prices for the currently selected tariff/date.

If the refresh fails, the existing cached information is not discarded.

---

## Data models

### `Models.swift`

This file contains the Codable/Decodable data structures used to map the Octopus JSON responses into Swift values.

Important types include:

### `ProductPage`

Represents a paginated product-list response.

### `ProductSummary`

Represents the summary of an Octopus product returned by the products endpoint.

### `ProductDetail`

Contains the detailed tariff information for one product.

### `ElectricityTariff`

Contains the tariff code, standing charge and API links.

### `TariffOption`

The app-specific representation of a selectable Agile tariff.

It contains:

- product code,
- product name,
- tariff code,
- region code,
- payment method,
- standing charge including VAT.

### `HalfHourRate`

Represents one published pricing period:

```text
value_exc_vat
value_inc_vat
valid_from
valid_to
payment_method
```

`validFrom` is also used as the unique identifier for a half-hour rate.


---

## UK electricity regions

`RegionNames` converts Octopus region identifiers into readable names.

The current mapping is:

]| Code | Region |
|---|---|
| `_A` | Eastern England |
| `_B` | East Midlands |
| `_C` | London |
| `_D` | Merseyside & North Wales |
| `_E` | West Midlands |
| `_F` | North East England |
| `_G` | North West England |
| `_H` | Southern England |
| `_J` | South East England |
| `_K` | South Wales |
| `_L` | South West England |
| `_M` | Yorkshire |
| `_N` | South Scotland |
| `_P` | North Scotland |

---

## Price colour calculation

### `PriceColour.swift`

`PriceColourScale` calculates colours relative to the prices available for the selected day.

For positive prices:

1. the day's minimum and maximum values are identified,
2. the price is normalised into a value between 0 and 1,
3. the SwiftUI hue is moved progressively from green to red.

This deliberately makes the wheel useful as a visual comparison of periods **within the selected day**.

The colours therefore do not represent fixed universal price thresholds. A green sector means that the rate is relatively cheap compared with the other rates in that displayed day.

Negative prices are handled separately and displayed in blue.

The code also assigns descriptive bands:

- Negative price
- Very low
- Low
- Mid-range
- High
- Very high

---

## Price wheel

### `PriceWheelView.swift`

The price wheel is rendered using SwiftUI `Canvas`.

For each half-hour rate the view:

1. calculates the angular start and end position,
2. creates a sector `Path`,
3. fills it using `PriceColourScale`,
4. draws a subtle separator between sectors.

The sector count is dynamic and is not hard-coded to 48.

### Hour markings

The view checks the actual local time of each rate. Whole-hour periods are given rim marks and selected hour labels are placed around the wheel.

This is preferable to assuming that a particular array index always corresponds to a particular clock time, especially on DST transition days.

### Touch and drag selection

A zero-distance `DragGesture` allows both taps and continuous dragging.

The touch position is converted into an angle using `atan2`. That angle is converted into the corresponding sector index and the selected `HalfHourRate` is updated.

The currently selected sector is drawn with a stronger outline.

### Accessibility

The wheel exposes an accessibility label and an accessibility value describing the selected time range and price in pence per kWh.

---

## Main interface

### `ContentView.swift`

`ContentView` is the main SwiftUI screen.

It is responsible for:

- starting data loading,
- displaying the currently selected tariff,
- presenting the tariff picker,
- allowing the date to be changed,
- refreshing rates,
- displaying loading states,
- showing the price wheel,
- displaying selected-rate details,
- displaying lowest, average and highest prices,
- presenting the colour legend,
- presenting API errors,
- showing whether displayed information is **SERVER DATA** or **LOCAL CACHE**,
- providing an explicit **Refresh from Octopus** action.

Changing the date first attempts to restore a matching cached day and then requests a fresh server copy.

If no prices have yet been published for the selected tariff/date, the view model returns a user-friendly message rather than treating an empty result as a crash condition. If the server is unreachable but a cached copy exists, that cached copy remains usable.

---

## Setup

### Requirements

The repository currently contains an Xcode project created with:

- **Xcode 26.6**
- **iOS SDK / deployment target 26.5**
- SwiftUQ
- Swift
- automatic code signing
- iPhone and iPad target device families

The project currently has:

```text
MARKETING_VERSION = 1.0
CURRENT_PROJECT_VERSION = 1
PRODUCT_BUNDLE_IDENTIFIER = KRH.AgilePriceWheel
```

> **Important:** the checked-in Xcode project currently sets `IPHONEOS_DEPLOYMENT_TARGET = 26.5`. A device therefore needs to run a compatible iOS version unless that deployment target is deliberately lowered and the project is retested.

### Clone the repository

```bash
git clone https://github.com/rhine59/AgilePriceWheel.git
cd AgilePriceWheel
```

Open:

```text
AgilePriceWheel.xcodeproj
```

or from Terminal:

```bash
open AgilePriceWheel.xcodeproj
```

### Configure signing

In Xcode:

1. Select the **AgilePriceWheel** project.
2. Select the **AgilePriceWheel** application target.
3. Open **Signing & Capabilities**.
4. Leave **Automatically manage signing** enabled.
5. Select your Apple Developer team.
6. If necessary, change the bundle identifier to a value that is unique to your developer account.

No API secret needs to be added to the project.

### Run in the Simulator

1. Select an iPhone simulator from the Xcode destination menu.
2. Press **Run** (`⌘R`).

The Mac must have internet access so the simulated app can reach the Octopus API.

### Run on a physical iPhone

1. Connect the iPhone to the Mac.
2. Trust the Mac if prompted.
3. Enable Developer Mode on the iPhone if required.
4. Select the iPhone as the Xcode run destination.
5. Select the correct development team under Signing & Capabilities.
6. Press **Run** (`⌘R`).

For normal development, Xcode handles the development provisioning profile automatically when automatic signing is enabled.

---

## Dependencies

### Third-party dependencies

**None.**

The Xcode project currently contains no Swift Package Manager package product dependencies and requires no CocoaPods or Carthage setup.

There is therefore no separate dependency-installation step such as:

```text
pod install
swift package resolve
npm install
pip install
```

### Apple frameworks

The application uses only frameworks supplied by Apple:

- `SwiftUI`
- `Foundation`
- `Combine`

Networking is provided by `URLSession`.

JSON decoding is provided by `JSONDecoder`.

Local preference storage is provided by `UserDefaults`.

### External service dependency

The app depends on the availability and continued compatibility of the public Octopus Energy REST API:

```text
https://api.octopus.energy/v1/
```

An active internet connection is therefore required for tariff discovery and price retrieval.

The application does not bundle tariff data for offline operation.

---

## Privacy and credentials

The current version does not request or store:

- Octopus account credentials,
- Octopus API keys,
- MPAN numbers,
- electricity meter serial numbers,
- payment information,
- user location.

The app stores the previously selected tariff code in `UserDefaults`.

It also stores public tariff metadata and previously downloaded half-hour price data in its Application Support directory so that the app can continue to work offline. The cache contains no Octopus credentials or personal account/meter information.

All cached tariff and rate information ultimately originates from the public Octopus Energy product/rate endpoints.

---

## Error handling

The API layer defines explicit errors for:

- invalid URL construction,
- invalid calendar-date calculation,
- non-success HTTP responses,
- JSON decoding failures.

These errors implement `LocalizedError`, allowing readable error descriptions to be shown in the interface.

If the API returns no rate periods for a selected date, the app displays an explanatory message. This is particularly relevant when requesting future Agile prices before Octopus has published them.

---

## Concurrency

The application uses Swift structured concurrency (`async`/`await`).

Both `AgileViewModel` and `OctopusAPI` are `@MainActor` isolated in the current implementation.

The Xcode project also enables Main Actor default isolation. Keeping the model and API client on the same actor avoids Swift concurrency isolation conflicts when decoded application model values are passed directly into UI state.

Network I/O itself is performed asynchronously through `URLSession.data(from:)`, so awaiting an API request does not require manually creating background queues.

---

## Tests

The Xcode project contains:

```text
AgilePriceWheelTests
AgilePriceWheelUITests
```

These are the standard unit-test and UI-test targets created with the project.

Further useful tests would include:

- tariff filtering,
- region-name mapping,
- colour-scale boundaries,
- negative-price handling,
- normal 48-period days,
- 46-period spring DST days,
- 50-period autumn DST days,
- API decoding using saved sample responses,
- selection of the current half-hour,
- tariff persistence.

---

## Building an archive

To create an archive suitable for distribution:

1. In Xcode select **Any iOS Device (arm64)** or the appropriate generic device destination.
2. Choose **Product → Archive**.
3. When the archive completes, Xcode opens **Organizer**.
4. Select the AgilePriceWheel archive.
5. Choose **Distribute App**.

Distribution options depend on the Apple Developer account and signing configuration.

An Apple Developer Program membership is required for normal App Store, TestFlight and registered-device distribution workflows.

---

## Development workflow

A typical Git workflow is:

```bash
git status
git add .
git commit -m "Describe the change"
git push
```

Before committing a release, it is good practice to:

1. build the project,
2. run it on a simulator or physical device,
3. test tariff retrieval,
4. test rate selection,
5. verify the selected date,
6. confirm the lowest/average/highest values,
7. test a future date with unpublished prices,
8. check a daylight-saving transition day when making date-related changes.

---

## Design notes

A few implementation choices are deliberate:

**Dynamic tariff discovery**  
The application discovers current Agile products instead of embedding one tariff code. This reduces maintenance when Octopus introduces a newer Agile product.

**UK calendar rather than a fixed 24-hour interval**  
This ensures the data model remains correct over UK daylight-saving transitions.

**Relative daily colour scale**  
The wheel is intended to show the best and worst periods of the displayed day at a glance. It is therefore scaled to that day's actual prices rather than fixed arbitrary thresholds.

**Persistent offline cache rather than a database**  
Agile prices are relatively small datasets, so the app uses simple Codable JSON snapshots in Application Support rather than introducing Core Data or another database. The Octopus API remains the source of truth, while cached tariff/date snapshots provide fast startup and offline operation.

**No third-party libraries**  
Using standard Apple frameworks keeps the project small and makes it easier to build on a clean Mac with Xcode.

---

## Possible future enhancements

Potential additions include:

- cache management controls (age/size display and selective clearing),
- chart and tabular views,
- notifications for particularly cheap or negative periods,
- configurable fixed colour thresholds,
- Home Screen widgets,
- Apple Watch support,
- automatic selection of a region from a configured postcode,
- comparison of multiple Agile days,
- integration with EV charging, batteries or smart loads,
- export of rates to CSV/JSON,
- more comprehensive automated tests.

---

## Disclaimer

Agile Price Wheel is an independent application that consumes publicly available Octopus Energy tariff data.

It is not an official Octopus Energy application.

Electricity prices displayed by the app should be verified against the user's actual Octopus tariff/account information before they are relied upon for billing or other financial decisions.
