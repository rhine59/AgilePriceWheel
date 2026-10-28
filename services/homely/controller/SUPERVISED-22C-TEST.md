# Archived supervised boost-target test — not executed

On 27 October 2026 the owner clarified that the requirement is heating enabled
throughout qualifying price slots, using existing Homely temperature settings.
The 22°C target diagnostic was therefore cancelled before any heating write.
Read-only verification confirmed heating disabled, no timed boost, original
weekly schedule restored, other settings/hot-water configuration preserved,
and policy/automation switch unchanged. Do not execute the commands below as
the next step: they document the superseded diagnostic only.

This is a diagnostic experiment, not an enabled automation mode. The goal is to
observe whether a native boost reports a 22°C target when a 22°C scheduled period
covers the test time. The earlier native boost returned 20°C. Either result is
useful evidence; neither proves a physical room-temperature ceiling.

## Approval scope and expected finish

The user must approve this **specific heating test** before run. A prior approval
for editing/adding a schedule while heating was disabled does not authorise it.
The test may briefly start the heat pump even if the price does not meet policy.
It preserves the saved price thresholds, app Automation state and manual hold.

The user adds one one-hour 22°C period covering the test time in Homely, leaving
all existing entries intact. The operator then briefly enables space heating,
cancels an enable-generated boost if necessary, starts a captured native boost
ending at the next UTC half-hour boundary, records the returned target and checks
its selected-zone/end readback. **There is no warm-up or dwell**: heating is disabled
and boost cancelled as soon as those observations are available.

A separate 60-second timer requests stop using a stop-only session if the main
sequence stalls. Network/API delays can still postpone confirmed physical off;
this is not a hard real-time or process-kill-resilient shutdown guarantee. If the
process is forcibly killed, the timer dies too. Stop-only recovery is available.
Do not use this experiment as unattended production control.

The user then removes just the test period. Independent final readback must
confirm normal heating disabled, no timed boost, the original weekly schedule,
unchanged other settings/hot-water configuration, and unchanged policy/switch.
Do not finish at the boost-cancel step or claim full restoration before that
readback. Derived idle override timestamps may regenerate; never blindly write
an old full-settings/override snapshot to force an exact match.

## Preconditions (abort before enabling if any fails)

- Verified configured household, schedule and separate sensor/boost selection.
- A recent successful controller check showing a settled manual-change hold,
  no pending operation and no control error. The test never clears that hold.
- Saved policy and automation revision/enabled intent match the fresh baseline.
- Heating disabled and no active timed boost.
- Exactly one user-added period, 22°C, at least one hour, covering current local
  time with at least three minutes left; all original rows and other schedules
  preserved. No new schedule ID generator is guessed by the script.
- A room reading below22°C is required: either the selected API reading (not
  lost, no more than120seconds old), or a current independent thermometer value
  supplied by the user and explicitly timestamped within120seconds. A cached
  Homely display must never be relabelled as an independent reading. The observed sensor sometimes updates less frequently, so the
  test may need to wait or abort. Do not relax freshness to force a run.
- The start is not too close to a UTC slot boundary. An explicit boost must have
  at least 30 seconds remaining before its requested boundary end.

The sensor's general contract remains unverified. This conservative preflight
is a condition for the short experiment, not evidence of a reliable ongoing
22°C ceiling. A stale sample causes no start. The schedule editor's minimum one
hour is different from the native boost's maximum half-hour request.

## Code and offline checks

`controller/boost_target_probe.py` is the explicit, non-worker experiment engine.
It takes an injected adapter, refuses calls without `authorised=True`, checks
context/deadline before writes, and always attempts disable then cancel. The
watchdog cannot enable, start or write schedules. Cleanup continues if tracing
fails. Uncertain starts are not replayed. A valid 20°C response is reported as
20°C, never re-labelled a successful 22°C result.

`examples/supervised_boost_target.py` supplies the existing captured Homely
transport; it adds **no schedule setter**. `prepare` and `verify-restored` are
read-only Homely operations. `run` and `stop` require both the specific human
approval and the explicit `--approved-live` flag. Responses, action intent and
original state are saved privately without OAuth/password/Authorization fields.
An atomic private attempt marker is created before arming any heat write; a
consumed attempt cannot be run again, even after a lost response or process
restart. A preflight-only rejection does not consume the attempt. Reconcile and
prepare a new baseline/approval rather than replaying a heat attempt.
Preparation must precede the user's added test period and expire after 30 minutes.

`examples/launch_supervised_probe.py` runs this code in a separate temporary Python
process inside the existing NAS container via the established SSH account. It
uses existing dependencies and read-only credentials; no image replacement,
container restart, runtime policy edit or persistent source edit occurs. New
probe state/trace files are private `/data/supervised-target-*.json/jsonl` files.
The temporary source/key/installation copies under `/tmp` are removed on normal exit. A forced kill can leave temporary
private files until cleanup/restart; the live runtime is not replaced.

Context checks inside that container use its existing authenticated loopback HTTP
API at exactly `http://127.0.0.1:8080`. External clients still require HTTPS;
`--local-controller` refuses any other HTTP destination. Existing Homely calls
continue to use HTTPS with normal validation. No password is passed to SSH.

The offline suite rehearses success/20°C negative evidence, failed preflight,
lost enable/start responses, policy/hold changes, delayed context checks, deadline
and watchdog expiry, enable-generated boosts, mismatched readback, failed stop,
trace failure, independent stop sessions and CLI/launcher approval gates.
Nothing in the regression suite contacts Homely or switches real equipment.

## Operator commands (placeholders; run is not authorised by this document)

Create a private installation file from the already verified capture/configuration:

```json
{"profile":"<approved profile>","house_id":"<verified household>",
 "sensor_zone_id":"<verified sensor>","boost_zone_id":"<verified boost zone>",
 "schedule_id":"<verified schedule>"}
```

Keep this file and traces out of GitHub. Use a new dedicated state filename;
prepare refuses to overwrite an existing baseline. Example read-only preparation:

```sh
python3 examples/launch_supervised_probe.py prepare \
  --ssh-target account@nas.example.com --ssh-port 2233 \
  --installation-file /private/path/installation.json \
  --state-file /data/supervised-target-example.json
```

Then, only after the human approves and the prepared period is independently
verified, the operator changes `prepare` to `run` and adds `--approved-live`.
This intentionally issues heating writes outside the price policy for the brief
diagnostic. A nonzero exit is not permission to rerun a start.

### Stop-only fallback and final verification

For uncertain outcome during the approved test, use the same invocation with
`stop --approved-live`. It attempts heating disable and boost cancellation,
using a session independent of the failed main request. It cannot start anything
or change a schedule. Use Homely's Disable heating ON / boost OFF directly if
remote stop cannot be confirmed, and report the unconfirmed state promptly.
A cloud outage can affect both paths; do not claim a guaranteed off command.

After confirmed stop, remove only the new test period in Homely. Use the same
invocation with `verify-restored` (no live flag) for independent original-state
comparison. If another person or Homely changed configuration, preserve it and
investigate rather than restoring an old whole-schedule/settings snapshot blindly.

## Status

The preparation passed 226 offline backend checks plus the existing 62-check
service walkthrough. The approved live diagnostic was superseded before execution
by the owner's temperature-independent requirement. Final read-only restoration
checks passed. No 22°C boost or ceiling has been established. The regular
controller remains price-only; these scripts are not a new HTTP service.
