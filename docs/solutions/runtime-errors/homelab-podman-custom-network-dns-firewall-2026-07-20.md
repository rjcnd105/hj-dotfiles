---
title: homelab Podman custom-network DNS blocked by the NixOS firewall
date: 2026-07-20
status: resolved
last_verified: 2026-07-20
category: runtime-errors
module: homelab app containers
problem_type: runtime_error
component: tooling
symptoms:
  - "Aardvark DNS queries to the custom network gateway timed out"
  - "The backend resolved deopjib-dev-db as :nxdomain while direct TCP by container IP worked"
  - "HTTP /health stayed 200 because it did not query the database"
root_cause: config_error
resolution_type: config_change
severity: high
related_components:
  - nixos
  - podman
  - quadlet
  - aardvark-dns
  - deopjib
  - hindsight
tags: [homelab, nixos, podman, quadlet, aardvark-dns, firewall, container-dns]
---

# homelab Podman custom-network DNS blocked by the NixOS firewall

## Problem

The Deopjib backend could reach Postgres by container IP, but could not resolve
the `deopjib-dev-db` network alias. Postgrex repeatedly logged
`non-existing domain - :nxdomain`, so DB-backed RPC returned an unknown error.
The public `/health` endpoint still returned `200 ok` because it only proved
that the Phoenix endpoint process was alive.

The failure remained after Podman, Netavark, and Aardvark were restarted from
the current Nix store and after the unrelated Hindsight DB network stopped
using Aardvark.

## Decisive evidence

Before the fix, evaluated NixOS firewall state allowed DNS only on Podman's
default bridge:

```json
{
  "podman0": {
    "allowedUDPPorts": [53]
  }
}
```

The affected Quadlet network was a different, dynamically named bridge:

```text
deopjib-dev interface=podman1 dns=true gateway=10.89.0.1
```

From `deopjib-dev-web`, even an explicit IPv4 query timed out:

```text
nslookup -type=A deopjib-dev-db 10.89.0.1
;; connection timed out; no servers could be reached
```

This distinguished the failure from Aardvark's IPv4-only `AAAA`/`NXDOMAIN`
behavior. Direct backend TCP to the Postgres container IP succeeded, and the
database logs showed that Postgres was ready. The missing path was UDP 53 from
the custom bridge into the host input chain.

## What did not fix it

The investigation produced several useful lifecycle improvements, but they did
not open the blocked DNS path:

| PR | Change | Result |
| --- | --- | --- |
| #68 | Render app resources through typed `quadlet-nix`; remove the activation refresh script | Generated units became declarative, but the existing network was not yet recreated |
| #69 | Add a Podman-package restart trigger to each app network | Too narrow for the rootful Aardvark process shared by multiple networks |
| #70 | Coordinate app and Hindsight units through one systemd lifecycle | First adoption did not restart every already-active member |
| #71 | Move lifecycle ownership to `podman-dns-lifecycle.nix` with a content-addressed member topology | All containers and current-store Aardvark restarted; DNS still timed out |
| #72 | Give Hindsight DB a DNS-disabled Quadlet network | Ruled out a Hindsight startup race; Deopjib DNS still timed out |
| #73 | Give app bridges stable names and declare their firewall DNS allowance | Fixed container DNS and DB-backed RPC |

Do not replace these declarations with `pkill aardvark-dns`, activation hooks,
or a host recovery script. A current Aardvark process cannot answer packets
that the NixOS firewall drops.

## Solution

`systems/homelab/app-containers.nix` now derives one host bridge name from the
existing app unit prefix:

```nix
unitPrefixFor = app: "${app.contract.name}-${app.contract.channel}";
bridgeInterfaceFor = app: "br-${unitPrefixFor app}";
```

That single value owns both sides of the contract:

```nix
networkConfig = {
  name = unitPrefix;
  interfaceName = bridgeInterfaceFor app;
};

networking.firewall.interfaces = appDnsFirewallInterfaces;
```

Each enabled app contributes only:

```nix
{
  allowedUDPPorts = [ 53 ];
}
```

The module asserts that the derived bridge name fits Linux's 15-character
interface limit. The flake check also asserts the evaluated firewall value and
the generated Quadlet `--interface-name br-deopjib-dev` argument.

### Ownership boundary

- `systems/homelab/default.nix` only composes modules. It owns no Hindsight or
  app-specific DNS behavior.
- `systems/homelab/app-containers.nix` owns generic app bridge naming and the
  matching firewall allowance.
- `systems/homelab/hindsight-stack.nix` owns only Hindsight's network choice;
  its DB bridge has `disableDns = true` because the API reaches it through the
  host-published loopback port.
- `systems/homelab/podman-dns-lifecycle.nix` owns generic rootful Podman
  lifecycle coordination, not app or Hindsight resource definitions.

## Verification

Static checks:

```sh
nix fmt -- --ci
nix flake check --no-build --all-systems
nix eval --json '.#nixosConfigurations.homelab_hj.config.networking.firewall.interfaces'
nix eval --raw '.#nixosConfigurations.homelab_hj.config.virtualisation.quadlet.networks.deopjib-dev._configText'
```

GitHub PR #73 passed the Linux `homelab-quadlet-lifecycle-invariants` build.
comin then switched commit `220e486cc8417082b2516cb6893ba3a843c17000`
to `/nix/store/gxdz49rny5vri3ynb34rmcl2z2x8bi8p-nixos-system-homelab-26.11.20260629.b5aa0fb`.

Live state after the switch:

```text
deopjib-dev network_interface=br-deopjib-dev dns_enabled=true
deopjib-dev-db.dns.podman -> 10.89.0.4
backend getent ahostsv4 deopjib-dev-db -> 10.89.0.4
POST https://dev.deopjib.site/rpc/run action=list_rooms -> HTTP 200, success=true
GET https://dev.deopjib.site/health -> HTTP 200, ok
GET http://127.0.0.1:8888/health -> HTTP 200, database=connected
```

No new backend `nxdomain` or `non-existing domain` entry appeared after the
11:56 KST restart.

## Version and source boundary

Verified runtime versions were NixOS `26.11.20260629.b5aa0fb`, Podman `5.8.4`,
Netavark `2.0.0`, Aardvark `2.0.0`, and locked `quadlet-nix`
`f1652b490b812c4e0b2a36565cdbedf87f35e438`.

Primary sources:

- [quadlet-nix DNS guidance](https://github.com/SEIAROTg/quadlet-nix/blob/f1652b490b812c4e0b2a36565cdbedf87f35e438/README.md#podman-dns-not-working) declares a stable custom-network `interfaceName` and UDP 53 firewall rule.
- [Podman network documentation](https://docs.podman.io/en/stable/markdown/podman-network.1.html#dns-notes) documents Aardvark-backed name and alias registration on DNS-enabled networks.
- [Podman Quadlet network documentation](https://docs.podman.io/en/latest/markdown/podman-systemd.unit.5.html#interfacename) maps `InterfaceName=` to `podman network create --interface-name`.

## Follow-up

Make `/health` DB-aware so the normal homelab smoke path detects a recurrence
without a separate RPC probe. That is an application readiness change, not part
of the host DNS fix.
