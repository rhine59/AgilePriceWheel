# Homely app API discovery register

Updated 25 October 2026. This register covers every Homely operation identified
so far, including ancillary app calls. It supplements the existing
[API reference](API-REFERENCE.md), which documents OAuth and the production calls.
There is no published developer API contract: evidence is the working client,
private Proxyman captures, and read-only installation responses.

## Evidence and boundaries

- The current app launch capture contains 12 distinct customer method names.
- Each of those methods has at least one captured HTTP 200 response.
- A later `getUser` attempt has a capture status of 999. This is not treated as a
  documented Homely HTTP error or successful response.
- The working production client separately establishes `setHotWaterSchedule`.
- Retained Proxyman history establishes `setSettings` with `hwSetPoint` only.
- Thus 15 customer method names and two OAuth endpoints have been identified.
- A supervised app test subsequently captured `setSettings` with boolean
  `hotWaterOnlyMode` in both directions, with HTTP 200 and readback. Heating
  mode was verified. A subsequent test captured `setHeatingBoost` cancellation
  (`status: false`), also HTTP 200. The user observed boost starting as soon as
  heating was enabled. A subsequent approved 25 October test captured explicit
  `setHeatingBoost` start and cancellation, both HTTP 200 with matching
  `boostActive` booleans. A later half-hour pilot observed native expiry, as
  documented at the end of this register. General duration limits and general
  sensor/zone mapping remain unverified.
- App launch itself registered a notification token and sent telemetry; these
  ancillary writes were made by the app, not replayed by the automation.

Raw captures, credentials, push tokens, user/house/zone/hub/schedule IDs, names,
addresses, actual usage data and installation values remain private. Examples
below contain placeholders and illustrative values, not a replayable live test.
The accompanying [schema inventory](homely-observed-schemas.json) contains only
field names and JSON types from the capture, never actual response values.

## Transport and captured client headers

Customer calls use `POST https://customer-api.homelyenergy.com/`, with a JSON
`method` selecting the operation. The captured app used:

```http
Content-Type: application/json
version: 6.3.5
User-Agent: Homely_Customer_App/6.3.5 ios/27.0.1
Authorization: Bearer <access-token>
```

The production script currently emulates a different iOS User-Agent version;
that should not be confused with the observed app header. Do not replace client
constants merely because one observed header differs without testing.

For the table below, envelope **H** means:

```json
{
  "method": "<method>",
  "houseId": "<house-id>",
  "userId": "<user-id>"
}
```

When listed, `payload` is an additional property. Calls without a payload below
were actually captured without that property; this is not a guessed requirement
that every call accepts `{}`. No side effects have been experimentally excluded
for nominal getters; their read-only classification follows observed use and
response purpose.

## Complete customer method inventory

| Method | Request envelope / payload | Classification | Response / evidence |
| --- | --- | --- | --- |
| `userInfo` | `{"method":"userInfo"}` | Identity read | `{userId:string}`; current capture and production |
| `getUser` | method, userId, payload `{userId:string}`; no houseId | Account read; personal data | User/address/houseIds; current capture and production |
| `getSettings` | H; no payload | Installation settings read | Settings object; current capture and production |
| `getAllSchedules` | H; no payload | Schedule/override read | `{schedules:object,zones:number}`; current capture and production |
| `getZones` | H; no payload | Zone telemetry read | Array of zone objects; current capture |
| `getHeatingBoost` | H; no payload | Heating override state read | Array of override objects; current capture |
| `getHotWaterBoost` | H; no payload | Ancillary boost state read | `{end:number}`; current capture |
| `getHub` | H; no payload | Hub metadata read | `{hubId:string,hardwareVersion:string}`; current capture |
| `getInfoCards` | H + `{viewName:"home",locale:"en_GB"}` | App content read | `{cards:array,house_id:string}`; current capture |
| `getUsageStats` | H + `{date_range:"daily"}` or `{date_range:"rolling_7d"}` | Usage/statistics read | Status and data objects; both requests captured |
| `updatePushTokens` | H + `{token:string,type:"apns"}` | **Writes notification registration** | JSON `null`, HTTP 200; current capture |
| `beacon` | method + telemetry payload; no top-level userId/houseId | **Writes telemetry** | JSON `null`, HTTP 200; current capture |
| `setHotWaterSchedule` | H + scheduleId/schedule payload | **Writes schedule; existing separate workflow** | Production implementation and write/readback checks; not in this launch capture |
| `setHeatingBoost` | Start: H + `{status:true,start:integer,end:integer,zoneId:string}`; cancel: H + `{status:false,zoneId:string}` | **Starts/cancels live boost** | Both captured HTTP 200 with `boostActive:true/false`; start/end are Unix milliseconds; observed end normalisation below |
| `setHeatingSchedule` | H + `{scheduleId:string,schedule:{id:string,name:string,data:array}}` | **Replaces a heating schedule** | Approved 27 October target edit and restoration, both HTTP 200 / JSON null; restored state independently checked |
| `setSettings` | H + `{hotWaterOnlyMode:boolean}`; separately observed `{hwSetPoint:"<numeric-string>"}` | **Writes live settings** | Both heating-mode values captured with readback; setpoint field from retained history |

For full `userInfo`, `getUser`, `getSettings`, `getAllSchedules` and
`setHotWaterSchedule` examples, see sections 5–9 of [API reference](API-REFERENCE.md).
The additional observed `getUser` response fields are `address` (county, country,
postCode, line2, city, line1), lastName, id, firstName, email and
installerSharingEnabled. Never publish their actual values.

## getZones

Request: envelope H with `method` set to `getZones`.

Illustrative response:

```json
[
  {
    "id": "<zone-id>",
    "name": "<zone-name>",
    "temperature": 21.0,
    "heatingOn": false,
    "hotwaterOn": false,
    "lastUpdated": 1700000000000,
    "activeScheduleId": "<schedule-id>",
    "nodeLost": false,
    "dhwTemp": 50.0,
    "outdoorTemp": 10.0,
    "chosenName": "<display-name>"
  }
]
```

`temperature` is the candidate room-temperature reading. `lastUpdated` is an
integer whose magnitude and correlation with capture times are consistent with
Unix milliseconds; that interpretation is an inference to validate before live
control. Use an aware UTC timestamp and reject stale/future readings or a lost
node. `heatingOn` is the API's reported state; its exact relationship to
compressor operation or physical power is not established by this capture.

The opaque string `id` must not be assumed equal to the integer `zoneId` in
`getHeatingBoost`. The inspected responses had different array lengths. Do not
infer zone selection from array position or the installation's `zones` count.

## getHeatingBoost

Request: envelope H with `method` set to `getHeatingBoost`.

Illustrative response:

```json
[
  {
    "start": 1700000000000,
    "temperature": 20,
    "end": 1700001800000,
    "min": 19,
    "max": 21.0,
    "zoneId": 0
  }
]
```

All six fields were observed; `zoneId` is an integer. Start/end magnitudes look
like Unix milliseconds, but unit/expiry semantics remain to be validated.
The actual captured values included a long-lived interval even while heating
was off and its app boost control was disabled. Therefore **a non-empty array
is not proof that a timed heating boost is active**. It may represent more
general temporary/override state. The illustrative short interval above is not
an observation of automatic expiry. The heating-mode write and subsequent `setHeatingBoost` cancellation described
below have been captured, including an explicit start on 25 October. The precise
meaning of min/max/temperature in normal operation is not fully established.

### Active timed-boost response variant (25 October pilot)

An explicit approximately half-hour boost returned a **different getter shape**:

```json
[{"zoneId": 0, "end": 1700001800000}]
```

Only `zoneId` and `end` were present, both JSON integers. `start`, `temperature`,
`min` and `max` were absent. Therefore a getter parser must not require the start
response's fields during an active boost, nor identify an active interval by an
exact start/end record match. Inactive override arrays and active timed-boost
arrays are observed variants, not a universal schema guarantee.

The pilot's requested end was exactly a half-hour boundary and the start response
accepted that exact end. Its response target was inherited from Homely; the
request contained no temperature fields. This additional sample shows that the
previously observed end normalisation is not universal. Native expiry was subsequently observed in this pilot as documented below;
an accepted future timestamp alone would not have verified it.

## getHotWaterBoost

Request: H, `method: "getHotWaterBoost"`. Observed response: `{end:number}`.
This was read by the app at launch. A zero/non-zero convention and timestamp
unit are not established here. No related write is introduced by this work.

## getHub

Request: H, `method: "getHub"`.
Observed response: `{hubId:string,hardwareVersion:string}`.
Treat the identifier as private and the hardware-version string as an observation,
not a capability flag for a heating command.

## getInfoCards

Request: H plus:

```json
{"payload":{"viewName":"home","locale":"en_GB"}}
```

Observed response shape:

```text
cards: array of {
  title: string, text: string, call_to_action: null,
  id: string, content_identifier: string, locale: string, dismissible: boolean
}
house_id: string
```

Only `home` and `en_GB` were captured; other values are not asserted supported.
`call_to_action` happened to be null; its non-null schema is unknown.

## getUsageStats

Request: H plus one of these **observed** payloads:

```json
{"payload":{"date_range":"daily"}}
```

```json
{"payload":{"date_range":"rolling_7d"}}
```

Response has `status:string` and `data:object`. Captured `data` fields:

| Metric | Captured field types |
| --- | --- |
| heatingEnergyUsed | value:number, units:string |
| hotWaterEnergyUsed | value:number, units:string |
| totalEnergyUsed | value:number, units:string |
| estimatedCoP | value:number |
| carbonSavings | value:number, units:string |
| heatingEnergyCost | value:number, units:string |
| hotWaterEnergyCost | value:number, units:string |
| totalEnergyCost | value:number, units:string |

These are historical statistics, not instant power measurements. Calculation,
reporting delay, unit meanings and other date ranges are not established merely
by the JSON field names. No real household usage values are included here.

## updatePushTokens

Request: H plus:

```json
{"payload":{"token":"<private-push-token>","type":"apns"}}
```

Response: HTTP 200 with JSON `null`. This registers/updates a notification token
and is state-changing even though it does not control heating. The app sent it
on launch. The automation must not replay it for API exploration.

## beacon

This call differs from H. Its captured request shape is:

```json
{
  "method":"beacon",
  "payload":{
    "type":"interaction",
    "action":"focus",
    "screen":"/",
    "focus_time":1000,
    "user_id":"<user-id>",
    "house_id":"<house-id>"
  }
}
```

Response: HTTP 200 with JSON `null`. The duration above is illustrative; the
unit of `focus_time` has not been verified. The snake_case identifiers are inside
payload, unlike H's top-level camelCase identifiers. This is state-changing app
telemetry, not a heating command. Do not replay it as a read-only test.

## setSettings: verified heating-mode control

The supervised Off → On → Off app capture established the following exact
requests. H identifiers must be discovered dynamically, not copied from a capture.

Allow space heating:

```json
{
  "method":"setSettings",
  "houseId":"<house-id>",
  "userId":"<user-id>",
  "payload":{"hotWaterOnlyMode":false}
}
```

Disable space heating (retaining the native frost-protection strategy):

```json
{
  "method":"setSettings",
  "houseId":"<house-id>",
  "userId":"<user-id>",
  "payload":{"hotWaterOnlyMode":true}
}
```

The value is a JSON **boolean**, not a quoted string. The setting has a
hot-water-related name because it disables space heating while retaining the
normal water strategy. This work does not change water schedules or setpoints.

### Observed response and side effects

All three captured mode writes returned HTTP 200 and a JSON object containing
`settings` and `schedules`. The app sent `false` twice, then `true`; the first
allow request and final disable request were about 14 seconds apart. Both false
requests returned false for `settings.hotWaterOnlyMode`,
`settings.summerMode` and `settings.settings.hot_water_only_mode`. The true
request returned true for those three fields. Do not infer independent write
access to either mirrored field.

The response differs from `getAllSchedules`: `schedules.heating` and
`schedules.hotwater` are **objects keyed by private schedule IDs**, whereas the
getter returns arrays. Never publish those dynamic keys or parse both response
shapes as though they were identical. The schema inventory models these maps
with additionalProperties.

The mode write also **rebuilds temporary override records**, including start/end
timestamps. In this installation, allowed mode produced bounds 18..22°C and
disabled mode produced 12..12.01°C, with temperature 20°C in both. These are
installation-specific observations, not universal constants or a claim that a
physical room-temperature ceiling is enforced. Repeating the same mode write
also rebuilt timestamps; therefore the operation is not strictly idempotent in
all returned state. Avoid redundant writes on each polling tick.

### Restoration verification and limits

Independent getters after the test confirmed:

- the same house and exactly the same installation settings as the baseline;
- reported heating off;
- unchanged non-temporary schedules, including both heating and water data;
- unchanged override temperature/min/max values;
- new temporary-override start/end timestamps created by the native mode switch.

This establishes restoration of the prior **mode and operational values**, not
byte-for-byte restoration of the old override records. Do not attempt to replay
the old timestamps through an unverified setter.

`false` permits the normal heating strategy to operate; it is not a command to
force the compressor on, request maximum-power boost or guarantee a higher
room temperature. `true` is not a hardware emergency stop: the product retains
frost protection. The test did not prove compressor start/stop timing, a
server-side timed lease or safe automatic restoration after
a worker/internet failure. The NAS controller stays plan-only. No further live
writes are authorised just by documenting this capture.

## setHeatingBoost: verified explicit start and cancellation (25 October)

The user approved a short test and then specified that the existing **heating
enabled** state must be preserved. The app showed boost off and normal heating
on before the test. The user performed the boost-on/off actions on the phone
while Proxyman recorded them. Both requests returned HTTP 200:

Start, using H's redacted identifiers:

```json
{
  "method": "setHeatingBoost",
  "houseId": "<house-id>",
  "userId": "<user-id>",
  "payload": {
    "status": true,
    "start": 1577836800000,
    "end": 1577838600000,
    "zoneId": "0"
  }
}
```

The example uses **illustrative past timestamps**, not captured values or a
request to replay. `status` is boolean, `start` and `end` are integer Unix
milliseconds, and `zoneId` is a string. No temperature or separate duration field
was present. The app's requested interval was just under 30 minutes; supported
minimum/maximum durations and arbitrary timestamp acceptance are not established.
Only the currently selected app zone, observed as string `"0"`, was tested.
Its general mapping to the opaque sensor ID remains unverified.

Cancel:

```json
{"method":"setHeatingBoost","houseId":"<house-id>","userId":"<user-id>","payload":{"status":false,"zoneId":"0"}}
```

Both responses were flat objects with integer `start`, `end`, `min`, `max`,
`temperature`, string `zoneId`, and boolean `boostActive`. The start response
confirmed `boostActive: true`; cancellation confirmed `boostActive: false`.
The captured request interval between start and cancellation was **14.917 seconds**.
This establishes API boost activation/cancellation, not physical compressor or
maximum flow-temperature behaviour.

### Observed end-time normalisation

The start response echoed the requested start exactly, but its end was 54.690
seconds earlier than requested and fell on a whole-minute boundary. This single
observation is consistent with truncation to a minute; it is not a universal
rounding contract. A client must inspect returned times rather than assume the
requested end is echoed. The request covered about 29m56s; the response interval
was about 29m01s. **Automatic expiry was not observed** because the boost was
manually cancelled after about 15 seconds. Returned expiry fields alone are not
proof of a crash-safe lease, automatic mode restoration or conditional ownership.

### Baseline, fallback and final readback

Before the phone-operated test, mirroring failed before a start could be
verified. A prepared cancellation fallback returned HTTP 200 and boost inactive.
No start request was captured for that failed UI attempt. Readback after that
cancellation matched all settings, complete schedules and complete heating
override records. The subsequent phone-operated test is the verified pair above.

Final readback after the verified pair again matched **all prior settings, the
complete schedule response and complete heating override records**, including
their timestamps. Heating remained enabled as requested. Room telemetry was
read, but its update cadence/freshness contract remains to be established. No
hot-water schedule or other setting was written by this test.

The NAS controller remains plan-only. The production transport currently
implements the earlier captured mode/cancel calls, not this newly captured start
request. Live activation and further tests require their own agreed scope.

## Earlier enable-to-boost sequence (24 October)


During the approved app test on 24 October 2026, the user reports that the boost
started immediately when heating was enabled. The captured sequence was:

1. `setSettings` with `{ "hotWaterOnlyMode": false }`, HTTP 200.
2. About 18 seconds later, `setHeatingBoost` with the payload below, HTTP 200.
3. About 9 seconds later, `setSettings` with `{ "hotWaterOnlyMode": true }`, HTTP 200.

Heating was enabled for approximately 27 seconds. No separate boost-start
request appeared in that 24 October capture; the explicit 25 October pair is
documented above. The user's observation is evidence of the
app's behaviour in this installation and initial state; it does not establish
that every enable request starts a boost or explain whether existing override
state caused it. Treat enabling heating as potentially starting a boost.

Cancellation request (H includes the redacted household and user identifiers):

```json
{"method":"setHeatingBoost","houseId":"<house-id>","userId":"<user-id>","payload":{"status":false,"zoneId":"0"}}
```

`status` is a JSON boolean. The request's `zoneId` is a **string**, whereas
`getHeatingBoost` returns numeric zone IDs. `"0"` was observed for this test;
do not generalise it to other installations or infer its mapping to the opaque
`getZones.id`. No duration or temperature field was present in this cancel request.

The response is a flat object with `start`, `end`, `zoneId`, `min`, `max`,
`temperature` and `boostActive`. Timestamp/bounds/temperature fields were
integers, `zoneId` a string, and `boostActive` boolean `false`. In this test the
cancel response set min/max/temperature to the same value. Disabling heating
then restored the installation's disabled-mode bounds. These are observations,
not universal defaults or evidence of physical compressor timing.

Readback confirmed the original settings, heating disabled, reported heating
off, and unchanged non-temporary schedules. Temporary override timestamps were
recreated by mode changes. That earlier capture did not establish a `status: true` request. The later
25 October start is documented above. A later half-hour pilot observed native
expiry; crash-safe restoration and general zone selection remain unverified.
The NAS controller remains plan-only. This documentation authorises no further
live heating changes.

## setSettings: separately observed setpoint field

The older private Proxyman request history includes H with:

```json
{"method":"setSettings","payload":{"hwSetPoint":"40.0"}}
```

In a real request H's houseId/userId are also present. The numeric string is an
illustrative setpoint, not an instruction to send it. The observed response
contains `settings` and `schedules`. That older capture establishes only the setpoint field and response wrapper.
The later mode capture above separately establishes `hotWaterOnlyMode`. Neither
capture establishes independently writable `summerMode`, a heating-temperature
setter or independently prove maximum-power physical operation. Explicit
boost start/cancel are separately established by the 25 October capture above. Never use a settings
write as a substitute for a getter. Current production reads `getSettings`.

## OAuth operations

Both endpoints are already established by the working client and documented
in sections 2–3 of [API reference](API-REFERENCE.md):

| Endpoint | Purpose / request | Successful fields used |
| --- | --- | --- |
| `POST https://oauth.homelyenergy.com/auth` | Email/password + OAuth authorization parameters, PKCE S256 challenge and random state | code, matching state |
| `POST https://oauth.homelyenergy.com/token` | Form-encoded authorization code, verifier, client_id, redirect_uri and grant_type | access_token; expiry fields may vary |

These are authentication operations, not anonymous reads. No raw login body,
password, verifier, authorization code, bearer token or push token is published.
This customer-domain-only launch export is not new evidence for OAuth schemas;
the client and previous authentication runs are the evidence for those sections.

## Discovery procedure and remaining heating evidence

For each newly observed method, record request envelope/field types, captured
header versions, HTTP status, response types, read/write classification, examples
with identifiers replaced, capture date, verification scope and unresolved
semantics. Update this register and schema inventory together. Decode HAR
base64 response bodies locally; do not mistake encoded JSON `null` for no data.
Do not infer a success contract from one HTTP 200 alone.

Before any live heating write, record current modes, schedule, overrides and
reported room state; confirm the household and obtain approval for the concrete
short test. Capture on/off/cancel and readback, then restore and verify the
original state. Native expiry requires its own observation. Do not implement
additional heating writes, automatic renewal or zone selection from guessed
field names. The captured mode toggle alone does not satisfy timed-boost safety.
Raw captures stay in the private workspace, outside Git and exported deliverables.


## Docker transport implementation status

The captured `setSettings` mode, explicit `setHeatingBoost` start and cancellation
payloads are implemented in `controller/heating.py`, used by the price-only
`controller/slot_control.py` driver. Automatic starts require administrative
activation, matching private installation-specific expiry evidence and the app's
persistent Automation switch ON. Explicit authenticated app OFF has separate
stop-only permission, even when automatic starts are disabled. It cannot send
start/enable/temperature payloads. Saving prices alone never activates controls.
The API does not supply atomic ownership; fresh state comparisons and persistent
manual holds reduce but cannot eliminate simultaneous app-write races. This code
introduces no guessed Homely method or temperature setter.


## Native half-hour expiry and subsequent shutdown (25 October)

One approved pilot requested a boost for the 16:00–16:30 UTC slot, while leaving
normal heating enabled and sending no temperature fields. The start response
confirmed `boostActive: true` and accepted exactly 16:30 as its end. During the
interval `getHeatingBoost` returned the compact `zoneId`/`end` variant above.

After the accepted end, the getter returned the exact pre-test inactive override
array. Final settings, schedules and override records all matched their baseline
by 16:30:15 UTC. No cancellation command was sent. This establishes native expiry
and API-record restoration for this one observed approximately half-hour boost.
It does not establish arbitrary durations, other zones, atomic ownership,
compressor behaviour, or restoration after every possible outage.

The initial pilot parser conservatively required an exact start/end getter match
and therefore left its expiry flag false when the active compact variant lacked
`start`. Raw evidence was retained unchanged. The reviewed result instead uses
an observed compact active record with the accepted end, followed by exact
baseline restoration after that end, with no intervening cancellation. That
review verifies the API-record expiry; it does not rely on the initial flag.

The user then requested heating disabled after verification, superseding the
previous instruction to preserve enabled mode. A subsequent `setSettings` with
only `hotWaterOnlyMode: true` was independently read back as true at 16:30:28 UTC.
The saved price thresholds were unchanged. No temperature or schedule setter was
sent. Ongoing production automatic control remained disabled throughout. Private
raw evidence and actual installation identifiers are excluded from this repo.


## Production-driver start and policy stop (25 October, 18:00)

An approved bounded test exercised the captured calls through the deployed
price-only driver, starting from heating disabled. A temporary 35p threshold
allowed the real 30.06p slot. The controller waited for the half-hour boundary,
confirmed the explicit bounded boost, then cancelled/disabled heating after the
original 0p/2p policy was restored. The app OFF state also survived restart.
Heating schedules and hot-water settings/schedules matched their baselines. No
new method or temperature setter was introduced. The active compact getter shape
and existing mode/start/cancel contracts were sufficient for the observed cycle.

The original harness's short wait expired before the completed policy stop was
reported; response ordering was reviewed without changing raw evidence. This is
not a claim that the harness passed, nor a naturally occurring price-boundary
crossing or physical meter observation. See the [supervised verification report](../controller/SUPERVISED-TEST.md).
The run motivated immediate durable OFF acknowledgement and stale-decision
masking, tested with 135 backend checks. These change controller handling, not
Homely payloads. Ongoing activation remains separately approved; the bounded test
finished with automation/heating OFF and the live gate disabled.

## 27 October: read-only temperature-control preparation

A new Homely-only Proxyman export reverified HTTP 200 for `getSettings`,
`getZones`, `getHeatingBoost`, `getAllSchedules`, `getInfoCards` (home/notices)
and `getUsageStats`. HAR response text uses base64 encoding in this export;
decode it before interpreting JSON. Raw exports remain private and untracked.

The Heating page exposes the scheduled interval/temperature plus Add, edit and
Heating Settings. Navigating to this page did not establish a temperature write.
The observed settings object also contains `heatingTypeNew`, `nightShift`,
`overnightHeatSavings` and `nibe`; these are observed response fields, not a
verified write contract. No payload using them is authorised by this observation.
The idle boost response has full override records, not the compact timed-boost
shape; its numerical min/max fields do not prove a physical temperature ceiling.

The current room value matched the phone display, but one concurrent API check
was about eight minutes old. Sensor cadence/freshness semantics remain unverified.
A proposed 22°C preheat/ceiling therefore still requires an observed temperature
control, restoration behaviour and suitable telemetry. This preparation made no
heating, boost, temperature or schedule change, and did not clear a manual hold.

### Heating Settings screen and existing boost target

Read-only inspection on 27 October found Disable heating, Limit overnight heating
and Temperature flexibility controls. With heating disabled, the UI shows boost
unavailable. Captured settings correspond to `hotWaterOnlyMode:true`,
`flexibility:0`, `overnightHeatSavings:false` and `nightShift:false`.

The earlier explicit boost-start response returned `min:20`, `max:20`,
`temperature:20` and `boostActive:true`. Its request had no temperature field.
This is evidence for that individual 20°C boost response, not a contract that
all boosts always use 20°C or that an arbitrary requested target can be supplied.
A 22°C preheat request remains unsupported by the verified transport. A scheduled
target edit would establish a different command; it must not automatically be
assumed to control the boost target or provide safe temporary ownership/restoration.
No schedule or temperature edit has been performed in this inspection.

## setHeatingSchedule: approved target edit and restoration (27 October)

The user approved a brief change to the existing scheduled target while normal
space heating stayed disabled and boost stayed off. Proxyman captured two calls:

| UTC request time | Target change | Result |
| --- | --- | --- |
| 08:47:48.019 | Existing scheduled entry 16°C → 22°C | HTTP 200, JSON `null` |
| 08:48:10.926 | Same entry 22°C → 16°C | HTTP 200, JSON `null` |

The requests were 22.907 seconds apart. Their payloads differed only at one
`temperature` value. The complete seven-entry heating-schedule object was sent
each time. All entry IDs, schedule IDs, names, weekdays and times were preserved.
Afterwards an independent API read exactly matched the preflight heating settings,
heating schedules and idle boost records. Heating remained disabled, no timed
boost was active, and the existing manual hold remained intact. There was no
independent intermediate 22°C getter sample or physical heating/meter test.

Observed envelope and field types (identities redacted):

```text
method: setHeatingSchedule
houseId: <existing house identity>
userId: <existing user identity>
payload:
  scheduleId: <selected existing schedule identity, string>
  schedule:
    id: <same existing schedule identity, string>
    name: <existing name, string>
    data: <complete original entry array; exactly one temperature changed>
      each entry: {id:string, weekdayId:integer, start:integer,
                   end:integer, temperature:number}
```

The edited entry had `start:300`, `end:960`, `weekdayId:1`; these matched the
phone's Tuesday 05:00–16:00 entry. This establishes minutes after local midnight
for that observed interval and Tuesday=1 in this installation. DST folds/gaps,
overnight entries, new-entry IDs, creation/deletion and repeated/overlapping
period handling have not been tested. Do not use an entry's array position as its
identity. Do not omit other existing entries when constructing a replacement.

A null response does not establish state or ownership. Read back the selected
schedule and reconcile an uncertain write before deciding whether to restore;
never blindly replay it. The API has no observed conditional-write token, so
comparison followed by a write is not atomic.

This command changes a **scheduled** target. It does not establish an independently
writable **boost** target, a temperature payload for `setHeatingBoost`, a strict
physical 22°C ceiling, server-side automatic restoration or an expiring override.
The production transport intentionally continues to reject this method.

The pure [offline planner](../controller/schedule_target.py) and
[narrated example](../examples/temperature_target_demo.py) rehearse editing an
existing identified entry, exact restoration and refusal after an external edit.
They do not call Homely or supply the still-missing live lifecycle.

### Approved period creation and removal (27 October, 17:14 UTC)

The user next approved adding a new period with heating disabled and boost off,
then removing only that period. The app rejected a half-hour period with a
minimum-one-hour message, so the supervised capture used Tuesday 16:00–17:00 at
22°C. That UI restriction does not establish an API-level minimum and is distinct
from the already observed 30-minute native boost.

After correcting the phone proxy, Proxyman recorded:

| UTC request time | Action | Result |
| --- | --- | --- |
| 17:14:26.032 | `setHeatingSchedule`: complete schedule plus one 16:00–17:00, 22°C entry | HTTP 200, JSON `null` |
| 17:14:33.610 | `setHeatingSchedule`: original complete schedule, new entry omitted | HTTP 200, JSON `null` |

The calls were 7.578 seconds apart. All existing entries/IDs/names/times were
preserved in both requests. The added entry used the same fields as an existing
entry: `id:string`, `weekdayId:1`, `start:960`, `end:1020`, `temperature:22`.
Its ID was a new opaque string of length 10; its generation algorithm was not
captured. Do not substitute a guessed server-ID or UUID contract.

Deleting the period was a replacement of the whole schedule without that entry,
not a new delete API method. Independent final readback exactly matched the
preflight settings, heating schedules and idle boost records; heating remained
disabled, no boost/lease was active and the existing manual hold was intact.
There was no independent intermediate getter sample or physical heating test.

Earlier reported errors did not produce a captured add request or change the
independently read schedule. The phone proxy was subsequently found incorrect.
Those attempts are not counted as successful or as Homely API rejection evidence.

The offline planner can now rehearse adding an explicit-identity, non-overlapping
local-day entry of at least one hour and removing it only if fresh readback still
matches the expected full heating schedule. External changes block restoration.
This remains preparation: no schedule writes were added to the production
allowlist, no timed 22°C boost/physical ceiling was verified and no free-price
policy or manual hold was changed.
