# DSM reverse proxy, certificate and router forwarding

This documents the existing Synology access design. It is separate from rebuilding
or testing an image. None of the supplied build/test scripts changes DSM, router,
firewall, DNS, certificates or live activation. Public examples use placeholders;
the actual hostname/LAN address belong in the owner's private deployment notes.

## End-to-end route

```text
Phone, including away from home
  https://heating.example.com:8451
        |
        | TCP 8451 to the home's public address
        v
Router: external TCP 8451 -> <NAS-LAN-IP>:8451
        |
        v
DSM reverse proxy: HTTPS, host heating.example.com, port 8451
        | TLS certificate assigned to this rule
        | HTTP request + Authorization header
        v
NAS loopback http://127.0.0.1:8086
        | Docker publishes 8086 on loopback only
        v
homely-heating container: HTTP port 8080
```

The three port roles are different: **8451** is router/DSM HTTPS, **8086** is the
NAS loopback backend, and **8080** is inside the container. The router forwards
to the NAS LAN address and DSM port 8451, never to 127.0.0.1 or directly to 8086.
The loopback destination in DSM means this NAS, where Docker is running.

## DNS / DDNS

Use a stable hostname resolving to the home's public address. Configure the
required A/AAAA or CNAME/DDNS records using the existing provider. DNS does not
map ports: the app address still includes `:8451`. Check both address families
if an AAAA record exists; an IPv4 port forward alone does not establish IPv6
reachability. Keep a fixed/reserved LAN address for the NAS so forwarding does
not drift to a different device after DHCP renewal.

## DSM reverse-proxy rule

For the existing DSM 7 setup: **Control Panel → Login Portal → Advanced → Reverse
Proxy**. Inspect the existing heating rule rather than creating a duplicate.

| Field | Value |
| --- | --- |
| Name | A recognisable heating-controller name |
| Source protocol | HTTPS |
| Source hostname | `heating.example.com` (hostname only) |
| Source port | 8451 |
| Destination protocol | HTTP |
| Destination hostname | `127.0.0.1` |
| Destination port | 8086 |

The API is plain HTTP only behind the local proxy. Preserve the Authorization
header, JSON body and API status codes. Do not redirect the API to a DSM login
page or intercept it with an HTML/SSO page. These are ordinary HTTP JSON requests;
WebSocket configuration is not required. A source-host mismatch can select a
different DSM rule, certificate or application, even when the port is open.

## Certificate assignment

In **Control Panel → Security → Certificate**, select/import/renew a trusted
certificate covering the exact source hostname, or a suitable wildcard. Then use
**Settings** (service certificate assignment) to assign it to the heating reverse
proxy service/rule. Preserve assignments for other services.

For example, `heating.example.com` or `*.example.com` covers this example hostname.
A certificate only for `example.com` does not cover `heating.example.com`.
Likewise, a NAS DDNS parent certificate does not automatically cover a further
heating subdomain unless it includes that name or the correct wildcard.

Verify the hostname, chain and expiry through the actual HTTPS route. A valid
certificate present in DSM is insufficient if a different certificate is assigned
to the rule. Preserve normal certificate checking in the app and Python client;
fix a certificate mismatch/expiry rather than disabling validation.

## Router port forwarding and DSM firewall

| Router field | Value |
| --- | --- |
| Protocol | TCP |
| External/WAN port | 8451 |
| Internal device/address | The reserved NAS LAN address |
| Internal destination port | 8451 |

No UDP rule is required for this HTTP API. If DSM's firewall is enabled, allow
TCP 8451 under the intended remote-access policy. Do not forward raw backend
ports 8086/8080, expose unrelated services, change existing SSH rules, disable
the firewall or put the NAS in a DMZ as part of this setup.

Double NAT or an ISP address behind CGNAT can prevent inbound IPv4 forwarding.
An IPv6 route requires its own firewall/reachability verification. Treat those
as network diagnoses, not a reason to change controller authentication.

## App / Python connection

Use the origin only: `https://heating.example.com:8451`. Do not add `/v1/status`
to the app setting. The key is the value of `HEATING_API_TOKEN` in the private NAS
runtime environment; keep it out of URLs, public docs, command arguments and logs.
The iOS app stores it in Keychain and refuses redirects. The sample also refuses
redirects and reads the key from a private file or environment.

```sh
python3 examples/heating_services.py \
  --url https://heating.example.com:8451 \
  --key-file /private/path/controller-key.txt --samples 1
```

This reads policy, status, automation and weekly history. Omit live write options
for a connection test. These checks do not change heating or release a hold.

## Verify in layers

The following optional diagnostics require curl and do not include a key:

```sh
# On the NAS: prove the backend answers; expected 401.
curl --silent --show-error --output /dev/null --write-out '%{http_code}\n' \
  http://127.0.0.1:8086/v1/status
# On the NAS: test DSM + certificate while bypassing router/DNS; expected 401.
curl --silent --show-error --output /dev/null --write-out '%{http_code}\n' \
  --resolve heating.example.com:8451:127.0.0.1 \
  https://heating.example.com:8451/v1/status
# From an outside connection: DNS + router + DSM; expected 401.
curl --silent --show-error --output /dev/null --write-out '%{http_code}\n' \
  https://heating.example.com:8451/v1/status
```

Then use the authenticated read-only Python sample and expect HTTP 200 JSON.
An unauthenticated **401** is the correct result, not a failed deployment. A DSM
HTML page or redirect is the wrong route. The client must validate TLS normally.
Finally inspect `stale`, source/control errors, worker-check freshness, hold and
shutdown state; successful HTTP alone does not prove heating operation.

A successful public-hostname request from inside the home LAN may use router
loopback/hairpin NAT. Verify away-from-home access using cellular data with Wi-Fi
off or another genuinely external network. It is not established by LAN testing
alone. Router settings cannot be audited from Docker inspection.

| Failure | Check |
| --- | --- |
| DNS does not resolve | DDNS/current WAN address and A/AAAA/CNAME records |
| Connection refused or timeout | Forwarding destination, TCP port, DSM listener/firewall, double NAT/ISP |
| TLS mismatch/expiry | Correct hostname, source rule and assigned certificate |
| 502 | Container health and loopback backend 8086; destination must be HTTP |
| 401 with the key | Exact current key and Authorization header forwarding |
| HTML/login/redirect | Wrong DSM source rule or login/SSO interception |
| HTTP works but data/control fails | Status freshness/errors/hold; not a port-forward problem |

The current public endpoint was checked on 27 October with normal TLS: 401
without a key and 200 JSON with a key. Exact private details and the distinction
between end-to-end tests and direct router/DSM-config inspection are retained
outside GitHub. See [container guide](CONTAINER.md), [full service API](SERVICES.md)
and [rebuild/rollback guide](REBUILD.md).
