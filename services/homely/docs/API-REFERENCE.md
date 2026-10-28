# Homely API Calls and Observed Interfaces

## Scope and status

This document records the network interfaces that have been identified and used while developing this Homely automation.

The Homely calls below are based on the behaviour observed/reproduced from the Homely customer application and the working project code. They should be treated as **unofficial/undocumented application interfaces**, not as a published public Homely developer API contract. Homely can change endpoints, request fields, mobile-app headers or response schemas without notice.

By contrast, the Octopus Energy REST API is publicly documented. Open-Meteo also provides a public forecast API.

Do not put real Homely passwords, OAuth access tokens, house IDs, user IDs or email credentials into documentation, Git commits or bug reports.

---

# 1. Interface map

The production scheduler uses five Homely customer operations plus the two OAuth endpoints. The expanded [discovery register](HOMELY-OBSERVED-CALLS.md) covers all 16 identified customer methods, including calls observed only in Proxyman and retained history.

| Stage | Endpoint / method | Purpose |
|---|---|---|
| Login | `POST https://oauth.homelyenergy.com/auth` | Obtain OAuth authorization code |
| Token | `POST https://oauth.homelyenergy.com/token` | Exchange code + PKCE verifier for access token |
| Identity | `POST https://customer-api.homelyenergy.com/` / `userInfo` | Discover logged-in user ID |
| User | same endpoint / `getUser` | Discover house ID(s) |
| Settings | same endpoint / `getSettings` | Read timezone and DHW capability/settings |
| Schedules | same endpoint / `getAllSchedules` | Read current schedules |
| Schedule update | same endpoint / `setHotWaterSchedule` | Replace the hot-water schedule |
| Heating schedule target | same endpoint / `setHeatingSchedule` | Captured whole-schedule replacement; a scheduled 16→22→16°C edit, not an independently temperature-controlled boost |

The optimisation code additionally calls:

| Service | Endpoint | Purpose |
|---|---|---|
| Octopus Energy | tariff `standard-unit-rates` endpoint | Half-hour Agile prices |
| Open-Meteo | `/v1/forecast` | Solar shortwave-radiation forecast |

---

# 2. Homely OAuth authorization

## Endpoint

```text
POST https://oauth.homelyenergy.com/auth
```

This is not a conventional browser redirect in the current implementation. The script sends the Homely username/password and OAuth parameters as JSON.

## Constants observed in the working implementation

```text
client_id    = xxxxxx
scope        = mobile
redirect_uri = auth.homelyenergy://oauthredirect
```

The current emulated OAuth user agent is:

```text
Homely/190 CFNetwork/3860.700.1 Darwin/25.6.0
```

These application identifiers/version strings are implementation observations, not guaranteed API constants.

## PKCE preparation

Before the request, the application generates:

- a random PKCE `code_verifier`;
- `SHA256(code_verifier)`;
- Base64-URL encoding without padding to form `code_challenge`;
- a random OAuth `state`.

## Representative request

```http
POST /auth HTTP/1.1
Host: oauth.homelyenergy.com
Accept: */*
Content-Type: application/json
User-Agent: Homely/190 CFNetwork/3860.700.1 Darwin/25.6.0

{
  "email": "user@example.com",
  "password": "<HOMELY_PASSWORD>",
  "params": {
    "response_type": "code",
    "client_id": "xxxxxx",
    "scope": "mobile",
    "state": "<random-state>",
    "redirect_uri": "auth.homelyenergy://oauthredirect",
    "code_challenge": "<pkce-challenge>",
    "code_challenge_method": "S256"
  }
}
```

## Likely successful response

The code relies on at least:

```json
{
  "code": "<authorization-code>",
  "state": "<same-state-sent-in-request>"
}
```

Additional fields may be present.

The program explicitly verifies that returned `state` equals the state it generated. It then requires `code`.

## Failure behaviour

Non-2xx HTTP responses are treated as login failure. Missing authorization code or a state mismatch is also fatal.

---

# 3. Homely OAuth token exchange

## Endpoint

```text
POST https://oauth.homelyenergy.com/token
```

## Content type

```text
application/x-www-form-urlencoded
```

## Representative request

```http
POST /token HTTP/1.1
Host: oauth.homelyenergy.com
Accept: */*
Content-Type: application/x-www-form-urlencoded

grant_type=authorization_code&
client_id=xxxxxx&
code_verifier=<original-pkce-verifier>&
code=<authorization-code>&
redirect_uri=auth.homelyenergy://oauthredirect
```

## Likely successful response

The current program requires `access_token` and also observes `expires_in`:

```json
{
  "access_token": "<bearer-token>",
  "expires_in": 3600,
  "token_type": "Bearer"
}
```

The exact token lifetime and presence/names of other token fields should not be assumed.

The access token is then supplied to the customer API as:

```text
Authorization: Bearer <access_token>
```

---

# 4. Homely customer API transport

## Endpoint

All discovered customer operations are sent as HTTP POSTs to one endpoint:

```text
POST https://customer-api.homelyenergy.com/
```

The operation is selected by a JSON `method` property rather than by a different URL path.

## Current headers

The working client sends approximately:

```http
Accept: application/json, text/plain, */*
version: 6.3.5
User-Agent: Homely_Customer_App/6.3.5 ios/26.6
Authorization: Bearer <access-token>
Content-Type: application/json
```

The app/version headers are particularly likely to change over time.

---

# 5. userInfo

## Purpose

Discovers the Homely user identifier associated with the authenticated token.

## Request

```http
POST https://customer-api.homelyenergy.com/
Authorization: Bearer <access-token>
Content-Type: application/json

{
  "method": "userInfo"
}
```

## Response fields used

The program requires:

```json
{
  "userId": "<homely-user-id>"
}
```

There may be additional account/profile information. The automation intentionally depends only on `userId`.

The returned ID is subsequently used in customer API calls.

---

# 6. getUser

## Purpose

Retrieves the Homely user record and, importantly for the scheduler, the house IDs accessible to that user.

## Request

```json
{
  "method": "getUser",
  "payload": {
    "userId": "<user-id>"
  },
  "userId": "<user-id>"
}
```

Sent to:

```text
POST https://customer-api.homelyenergy.com/
```

## Response fields used

The application expects:

```json
{
  "houseIds": [
    "<house-id>"
  ]
}
```

Other user metadata may be returned.

## Safety behaviour

The current scheduler accepts exactly one house. If `houseIds` is empty it fails; if more than one house is returned it also fails rather than guessing which installation to control.

This means the observed call can discover multiple house IDs, but the automation does not currently provide an explicit house selector.

---

# 7. getSettings

## Purpose

Retrieves settings/capabilities for the selected house.

## Request

```json
{
  "method": "getSettings",
  "houseId": "<house-id>",
  "userId": "<user-id>"
}
```

## Response fields known to be used

The project currently uses at least:

```json
{
  "timezone": "Europe/London",
  "hasWater": true,
  "hwSetPoint": 50,
  "dhwSetpointRange": {
    "min": 40,
    "max": 60
  }
}
```

The numbers above are examples only.

The code uses:

- `timezone` to perform all date/day calculations in the installation's timezone;
- `hasWater` to verify that DHW control exists;
- `dhwSetpointRange.min` and `.max` as validation;
- `hwSetPoint` for reporting.

The full response is likely richer than this minimal shape.

---

# 8. getAllSchedules

## Purpose

Reads the current live Homely schedules before making any modification.

## Request

```json
{
  "method": "getAllSchedules",
  "houseId": "<house-id>",
  "userId": "<user-id>"
}
```

## Response shape used by the project

The code expects a top-level `schedules` object containing a `hotwater` list:

```json
{
  "schedules": {
    "hotwater": [
      {
        "id": "<hot-water-schedule-id>",
        "data": [
          {
            "id": "<entry-id>",
            "weekdayId": 0,
            "start": 420,
            "end": 450
          },
          {
            "id": "<entry-id>",
            "weekdayId": 1,
            "start": 390,
            "end": 450
          }
        ]
      }
    ]
  }
}
```

Values are representative.

## Schedule semantics inferred by the implementation

`weekdayId` is treated using Python's weekday numbering:

```text
0 Monday
1 Tuesday
2 Wednesday
3 Thursday
4 Friday
5 Saturday
6 Sunday
```

`start` and `end` are treated as minutes after midnight.

For example:

```text
420 = 07:00
450 = 07:30
1380 = 23:00
```

The current application expects one hot-water schedule. It refuses to guess if more than one is returned.

---

# 9. setHotWaterSchedule

## Purpose

Writes the revised complete DHW schedule.

This is the principal state-changing Homely API operation used by the project.

## Request

```json
{
  "method": "setHotWaterSchedule",
  "houseId": "<house-id>",
  "payload": {
    "scheduleId": "<hot-water-schedule-id>",
    "schedule": {
      "id": "<hot-water-schedule-id>",
      "data": [
        {
          "id": "<entry-id>",
          "weekdayId": 0,
          "start": 420,
          "end": 450
        }
      ]
    }
  },
  "userId": "<user-id>"
}
```

The real `data` array normally contains the complete schedule across all weekdays, not just the example entry above.

## Why the complete schedule is sent

The project first retrieves `getAllSchedules`, preserves all entries for the other six weekdays, replaces only the target weekday, then sends the resulting complete schedule.

This reduces the risk of accidentally destroying schedules that the optimiser was not asked to change.

## Likely response

The current code only requires a successful HTTP status and valid JSON. It does not depend on a particular success field.

A successful response may therefore resemble a status/updated object, but its exact schema has not been established strongly enough to document as a contract.

**Do not build logic around a guessed success-response field.** Treat HTTP success plus parseable JSON as the currently observed contract unless a captured response proves more.

---

# 10. Example Homely call sequence

A normal run follows this dependency chain:

```text
POST oauth.homelyenergy.com/auth
       |
       +--> authorization code

POST oauth.homelyenergy.com/token
       |
       +--> access token

POST customer-api / userInfo
       |
       +--> userId

POST customer-api / getUser
       |
       +--> houseIds[0]

POST customer-api / getSettings
       |
       +--> timezone, DHW capability/settings

POST customer-api / getAllSchedules
       |
       +--> scheduleId + current schedule

       [Octopus + solar calculations]

POST customer-api / setHotWaterSchedule
       |
       +--> updated live schedule
```

`--auth-test` stops after discovery/settings/schedule validation without changing the DHW schedule.

`--dry-run` continues through the price/solar calculations and proposed schedule generation but deliberately omits `setHotWaterSchedule`.

---

# 11. Octopus Agile price API

The Homely scheduler also uses the public Octopus Energy REST API.

## URL pattern

```text
GET https://api.octopus.energy/v1/products/<PRODUCT>/electricity-tariffs/<TARIFF>/standard-unit-rates/
```

Representative example:

```text
https://api.octopus.energy/v1/products/AGILE-24-10-01/electricity-tariffs/E-1R-AGILE-24-10-01-G/standard-unit-rates/
```

The actual product/tariff must come from the profile configuration.

## Query parameters

The application sends:

```text
period_from=<UTC ISO timestamp>
period_to=<UTC ISO timestamp>
page_size=100
```

For a local UK day these boundaries are calculated in the Homely timezone and converted to UTC, which is important around BST/GMT transitions.

## Representative response

The Octopus endpoint returns a paginated object with results similar to:

```json
{
  "count": 48,
  "next": null,
  "previous": null,
  "results": [
    {
      "value_exc_vat": 10.0,
      "value_inc_vat": 10.5,
      "valid_from": "2026-09-21T00:00:00Z",
      "valid_to": "2026-09-21T00:30:00Z",
      "payment_method": null
    }
  ]
}
```

The scheduler uses `value_inc_vat`, `valid_from` and `valid_to`.

---

# 12. Open-Meteo solar forecast API

## Endpoint

```text
GET https://api.open-meteo.com/v1/forecast
```

## Parameters used

```text
latitude=<LAT>
longitude=<LON>
hourly=shortwave_radiation
forecast_days=3
timezone=UTC
```

Representative URL shape:

```text
https://api.open-meteo.com/v1/forecast?latitude=54.0&longitude=-2.0&hourly=shortwave_radiation&forecast_days=3&timezone=UTC
```

Coordinates above are illustrative only.

## Representative response shape

```json
{
  "latitude": 54.0,
  "longitude": -2.0,
  "hourly_units": {
    "time": "iso8601",
    "shortwave_radiation": "W/m²"
  },
  "hourly": {
    "time": [
      "2026-09-21T00:00",
      "2026-09-21T01:00"
    ],
    "shortwave_radiation": [
      0.0,
      0.0
    ]
  }
}
```

The scheduler takes the hourly `time` and `shortwave_radiation` arrays and linearly interpolates them onto the 30-minute Agile periods.

---

# 13. HTTP/API failure handling

The current Homely customer client treats any non-success HTTP response as fatal and includes the status code and returned body in the raised error.

Invalid JSON is also rejected.

This is preferable to silently accepting a changed API schema because these interfaces are not documented as a stable public developer API.

The scheduler additionally validates required semantic fields after JSON parsing, including:

- OAuth state;
- authorization code;
- access token;
- user ID;
- house IDs;
- timezone;
- DHW capability/range;
- schedule object;
- hot-water schedule ID/data;
- Agile result availability;
- solar forecast arrays.

---

# 14. API discovery notes

The interfaces recorded here came from the project's working integration and application-observation work. When investigating future Homely app changes, useful items to record are:

- hostname;
- HTTP method;
- path;
- request headers;
- mobile app `version` header;
- User-Agent;
- JSON `method`;
- request body;
- response HTTP status;
- response JSON keys and types;
- whether the operation is read-only or state-changing.

Never store real `Authorization: Bearer` values, passwords or personally identifying IDs in Git.

---

# 15. Known operations currently used

As of the current production implementation, the complete set of Homely customer methods actually found in the repository's current/retained implementations is:

```text
userInfo
getUser
getSettings
getAllSchedules
setHotWaterSchedule
```

No additional customer API method should be documented as known merely because its name seems plausible. Add methods here only after they have been observed or tested.

---

# 16. Stability warning

The Homely website describes its consumer product and app capabilities, but the mobile customer API documented above is not presented there as a public developer API. Treat this integration as potentially version-sensitive.

In particular, monitor:

- OAuth `client_id`, scope and redirect URI;
- app/version headers;
- customer API method names;
- schedule schema;
- weekday/time representation;
- token response fields.

If Homely introduces a supported public integration API, it should be preferred and this document should clearly distinguish that interface from these app-derived calls.

# 17. Space-heating inspection (24 October 2026)

Read-only `getAllSchedules` on the selected installation also exposed `heating`
entries (temperature/start/end/weekdayId/id) and `temporary` entries
(start/end/temperature/min/max). `getSettings` exposed zone count and summer/
hot-water-only flags. No heating write operation or native expiry contract was established in that initial inspection. A later Proxyman capture established `getZones` (including temperature, reported heating state and update time) and `getHeatingBoost`; see the [expanded discovery register](HOMELY-OBSERVED-CALLS.md). These shapes must not be treated
as a write contract. See [Heating boost](HEATING-BOOST.md) for the prepared
read-only planner, offline controller and remaining evidence required.


# 18. Complete discovery register

See [Homely app API discovery register](HOMELY-OBSERVED-CALLS.md) for all observed calls, request/response details, ancillary writes, evidence limits, and the value-free [schema inventory](homely-observed-schemas.json). Current capture observations supersede the limited production-only method list in section 15.


# 19. Heating enable/disable captured and verified

The supervised app test established `setSettings` with payload
`{"hotWaterOnlyMode": false}` to allow the normal space-heating strategy and
`{"hotWaterOnlyMode": true}` to disable space heating while retaining native
frost protection. Both values returned HTTP 200 with `settings` and `schedules`.
The response mirrors the value into `summerMode` and nested
`settings.hot_water_only_mode`; independent writes to those fields are not
established. Mode changes recreate temporary override timestamps, even on a
repeated same-value write. They do not provide native timed expiry.

See the [complete verified requests and side effects](HOMELY-OBSERVED-CALLS.md#setsettings-verified-heating-mode-control).
Post-test getters verified prior settings/mode, schedule data and override
bounds, with heating reported off. Absolute override timestamps changed as a
native side effect. A later capture verified `setHeatingBoost` cancellation
with `status: false` and string `zoneId`, returning `boostActive: false`. The
user observed boost starting immediately on enabling heating; no separate
start request was captured. See the discovery register for that sequence and
its limits. The NAS controller remains plan-only.


# 20. Docker controller integration

The observed calls above now have a narrow, gated transport in
`controller/heating.py`. It implements only the captured mode boolean and boost
cancellation payload; it does not infer a `status:true` start contract. Production
constructs it read-only and has no live heating endpoint. The separate safety
supervisor is tested against a fake native-expiry/ownership adapter, which is not
a verified Homely capability. See [controller status and recovery contract](../controller/README.md#heating-supervisor-and-recovery).
No additional Homely API call was discovered or sent by this implementation.


# 21. homely-heating service catalogue

The [complete container service catalogue](../controller/SERVICES.md) documents
the controller-facing HTTP API, all policy/status fields, background workers,
persistence, health checks and configuration. These services are distinct from
the Homely vendor API methods above. Production live heating remains disabled.


A [runnable Python client and offline walkthrough](../examples/README.md) now
exercises the controller services and documents the use case, revision-safe
policy save/restore and simulated-only control/recovery boundary. No new Homely
vendor method is introduced.


# 22. Published-price coverage and UTC solar ranges

The heating service now accepts a contiguous published local-day price prefix
covering the current period, with an unavailable future tail. The separate DHW
scheduler retains strict full-day validation: `fetch_agile_prices` defaults to
`require_complete_day=True`. Only the heating controller opts out before applying
its own current-period and gap validation. No prices are estimated or filled.

`GET /v1/status` adds `price_day_complete`, `price_coverage_end` and `error_stage`.
Configuration, Agile retrieval and solar failures now produce distinct safe
messages rather than the same generic refresh error. Solar uses the provider's
[explicit 15-minute UTC time-range parameters](https://open-meteo.com/en/docs)
so a clock-change day includes all required instants across local/UTC midnight.
No Homely control call or policy value is changed by this correction.


# 23. Explicit heating boost start/cancel verified (25 October 2026)

The approved phone test captured `setHeatingBoost` with boolean `status:true`,
integer Unix-millisecond `start`/`end`, and string `zoneId`; cancellation uses
`status:false` and string `zoneId` without start/end. Both returned HTTP 200
and the corresponding `boostActive` boolean. Requests were 14.917 seconds apart.

The response start matched; its end was earlier on a whole-minute boundary in
this sample. Do not assume arbitrary durations, exact end echoing or native expiry.
Full settings, schedules and overrides matched the enabled baseline afterward.
See [verified payloads, normalisation and limits](HOMELY-OBSERVED-CALLS.md#setheatingboost-verified-explicit-start-and-cancellation-25-october).
The production transport has not gained a start implementation, and automatic
control remains disabled. Earlier no-start statements describe the 24 October
capture/implementation at that point, not the current observed vendor contract.


### Additional timed-boost observation — 25 October

A subsequent approved half-hour pilot established an active `getHeatingBoost`
variant containing only integer `zoneId` and `end`. Its explicitly requested
half-hour-boundary end was accepted exactly. After that end, the original
inactive records, settings and schedules returned without a cancel command.
The user-requested heating disable was then confirmed by settings readback.
See the [full evidence and limits](HOMELY-OBSERVED-CALLS.md#native-half-hour-expiry-and-subsequent-shutdown-25-october).
This is one observed native-expiry case, not a general supported API contract.


## 27 October heating target capture

`setHeatingSchedule` was captured with `scheduleId` and the complete `schedule`
object (`id`, `name`, `data`). Each entry contains `id`, `weekdayId`, `start`,
`end` and `temperature`. The approved target edit and restoration returned HTTP
200 / JSON null; independent final readback matched the original state exactly.
See the [observed register](HOMELY-OBSERVED-CALLS.md#setheatingschedule-approved-target-edit-and-restoration-27-october)
for fields, timing, tested limits and the distinction between scheduled targets
and boost targets. The current production allowlist still refuses this setter.


27 October follow-up: adding/removing one one-hour heating period was captured
using the same whole-schedule setter and exactly restored. Offline planning now
has 200 backend checks plus the 62-check service walkthrough; the deployed driver
and six public HTTP services are unchanged. See the observed register and
`controller/SCHEDULE-TARGET-PREPARATION.md` for the remaining live-control limits.
