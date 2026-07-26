# Pi-hole

Network-wide DNS ad blocking on **dns-01** (VM 102, `192.168.0.211`).

- Admin UI: <http://192.168.0.211/admin>
- Password: in the vault as *Pi-hole admin (dns-01)*, or
  `sops -d ansible/inventory/group_vars/dns_hosts/secrets.sops.yaml`
- Currently blocking ~301,000 domains across 7 lists

Nothing uses it until you point your network at it — see
[Pointing the network at it](#pointing-the-network-at-it).

## What this actually blocks

Set expectations before you judge it, because DNS blocking is strong in some
places and useless in others.

**Blocks well**

- Smart TV telemetry and screen-content recognition — Samsung ACR, LG, Vizio,
  Sony. `samsungacr.com` is sinkholed, which is the one that watches what is on
  your screen.
- Home-screen and menu ads on Roku, Fire TV, Android TV
- Ads in mobile and desktop apps
- Web ads, trackers and analytics on every device, with no per-device setup
- Malware and phishing domains

**Does not block**

- **In-stream video ads on YouTube, Hulu, Peacock and similar.** These come
  from the same domains — often the same TCP connections — as the video itself.
  Blocking `googlevideo.com` would break YouTube entirely rather than skip the
  ad. No DNS-based blocker solves this; it is a limitation of the approach, not
  of this setup.
- Anything inside an app that talks to a hardcoded IP instead of a name
- Ads served from the same domain as the content (first-party)

If in-stream YouTube ads are the goal, the answers are a client-side blocker
(uBlock Origin in a browser, SmartTube on Android TV) or YouTube Premium.

## Pointing the network at it

Nothing changes until DHCP hands out Pi-hole's address as the DNS server.

On your router (192.168.0.1), find the LAN/DHCP settings and set the **DNS
server** handed to clients to:

```
192.168.0.211
```

**List only that address.** The common mistake is adding `1.1.1.1` or `8.8.8.8`
as a secondary — clients pick between DNS servers unpredictably rather than
using the second only on failure, so ads leak through at random and the
symptoms look like flaky blocking. One entry, or you get a coin flip.

Devices pick this up on their next DHCP lease renewal. Reboot a device, or
release/renew, to test immediately.

Confirm a client is actually using it:

```bash
nslookup doubleclick.net
```

An answer of `0.0.0.0` means Pi-hole handled it.

## Devices that ignore your DNS setting

Chromecast, Google/Android TV and some smart TVs ship with `8.8.8.8` compiled
in and ignore whatever DHCP tells them. They will bypass Pi-hole silently — the
admin UI simply never shows their queries.

The fix is a router firewall rule that redirects outbound DNS back to Pi-hole:

- **Port forward / NAT redirect**: any LAN traffic to TCP+UDP port 53 destined
  anywhere except `192.168.0.211` gets rewritten to `192.168.0.211:53`
- Exempt `192.168.0.211` itself, or Pi-hole cannot reach its own upstreams and
  the whole network loses DNS

Exact steps depend on the router — OPNsense/pfSense, OpenWrt and UniFi all
support it; most ISP-supplied routers do not.

Devices using **DNS-over-HTTPS** (Firefox by default, some smart TVs) bypass
Pi-hole regardless, since the queries ride inside normal HTTPS on port 443.
Blocking DoH takes a separate blocklist of known DoH endpoints.

## When something breaks

Aggressive blocklists occasionally break a device — an app that will not load,
an update that will not download, a TV feature that hangs. Diagnose it in the
admin UI under **Tools → Query Log**: a legitimate domain showing as blocked is
the culprit.

Fix the narrow thing, not the broad thing:

```bash
docker exec pihole pihole allow <domain>
```

Allowlist the specific domain rather than disabling a whole list. If you must
disable a list, do it in **Lists** in the UI, then re-run the playbook — the
role uses `INSERT OR IGNORE`, so it will not re-enable what you turned off.

To pause blocking entirely for a few minutes while testing, use **Disable
blocking** in the admin UI.

## Pi-hole is now a single point of failure

Once DHCP points at it, every device on the network depends on dns-01 being up.
If it stops answering, everything looks broken to everyone — not "ads come
back", but "the internet is down".

What mitigates that here:

- `restart: unless-stopped` on the container, `on_boot` on the VM
- Nightly Proxmox backup at 03:15, keep-last 3
- Its own VM, so redeploying the Discord bot cannot take DNS down
- Rebuildable from this repo in a few minutes

What would mitigate it further, if you care: a second Pi-hole on another host
with both addresses in DHCP. Note the caveat above still applies — clients
alternate between listed servers, so both must block for it to work. Two
Pi-holes is fine; one Pi-hole plus a public resolver is not.

If you ever need to bail out fast, set your router's DNS back to its own
address or `1.1.1.1` and everything resolves again immediately.

## Changing the configuration

Upstreams, blocklists and the image tag are in
[`ansible/inventory/group_vars/dns_hosts/vars.yml`](../ansible/inventory/group_vars/dns_hosts/vars.yml).
Edit, commit, then:

```bash
cd ansible && ansible-playbook playbooks/site.yml --limit dns_hosts
```

Gravity only rebuilds when the number of lists actually changed, so re-running
the playbook is cheap.

The image is pinned to a specific tag rather than `latest` on purpose: DNS
should not change underneath you unattended. Bump `pihole_image` deliberately.
