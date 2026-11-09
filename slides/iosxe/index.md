---
marp: true
theme: default
author: Michal Bakalarski
title: IPsec on Cisco IOS XE, from Kubernetes
keywords: kubernetes,crossplane,cisco,iosxe,ipsec,ikev2,ppk,rfc8784,vti,vrf,restconf,yang,brownfield,gitops,netdevops,networkautomation,netclab,configuration-iosxe
paginate: true
backgroundColor: '#1E293B'  # dark slate
color: '#F8FAFC'            # light text
---

# IPsec on Cisco IOS XE, from Kubernetes
*[**configuration-iosxe**](https://github.com/netclab/netclab-xp) 0.2.0, powered by [crossplane.io](https://www.crossplane.io)*
<br>

- Tunnels with a post-quantum preshared key (PPK, RFC 8784)
- Overlays of static VTIs in VRFs
- Keys rotated from their Secrets
- Brownfield adoption: observed first, written when you choose

---

# A section of the router is an object

```yaml
kind: Ikev2Proposal
metadata: {name: r1--classical-proposal--3a16aab3}
spec:                                  # the intent
  deviceRef: {name: r1}
  name: CLASSICAL-PROPOSAL
  encryption: [aes-cbc-256]
  integrity: [sha512]
  group: [20]
status:                                # what the router holds
  drift: []
  extra: []
  observed:
    encryption: [aes-cbc-256]
    group: [20]
    integrity: [sha512]
```

Read again on every poll, over RESTCONF.

---

# Adopt: observe first

A router configured by hand, its sections imported as objects in `Observe`. Then, on r1 by hand, group 19 in place of 20:

```console
$ kubectl get ikev2proposal r1--classical-proposal--3a16aab3 -n ipsec -o yaml   # status, trimmed
status:
  drift:
  - device:
    - "19"
    field: group
    spec:
    - "20"
  observed:
    group:
    - 19
```

**Shown, not written.** The object is not Ready while `drift` has an entry.

---

# Take over when you choose

- `Observe` reads
- `Merge` writes the fields of the spec, and leaves the rest of the section
- `Replace` makes the section the spec

In `Replace`, the change by hand is put back at the next poll, and recorded:

```console
$ kubectl get ikev2proposal r1--classical-proposal--3a16aab3 -n ipsec -o yaml   # status, trimmed
status:
  observed:
    group:
    - 20
  reverted:
    extra:
    - device:
      - "19"
      field: group
```

---

# The PPK

```console
r1#show crypto ikev2 sa detailed | include READY|Quantum
2         10.0.12.1/500         10.0.23.2/500         none/none            READY
      Quantum-safe Encryption using Manual PPK
```

The YANG of IOS XE 17.18 has no PPK. The package writes it over RESTCONF, as CLI lines in the `Cisco-IOS-XE-cli-rpc` RPC, and keeps it.

---

# Keys rotated from their Secrets

Next to each key, the package keeps a mark of it in an EEM variable, never the key itself:

```console
r1#show running-config | include ^event manager environment netclab-0fb93954
event manager environment netclab-0fb93954 "5af41a49 Ikev2Keyring/CLASSICAL-KEYRING/R3/ppk"
```

```console
$ kubectl patch secret ike-keys -n lab --type merge \
    -p "{\"stringData\":{\"ppk-hex\":\"$(printf %s RotatedPostQuantum | xxd -p -u)\"}}"
secret/ike-keys patched
```

The new key reaches both routers, and the mark changes with it:

```console
r1#show running-config | include ^event manager environment netclab-0fb93954
event manager environment netclab-0fb93954 "a15a673d Ikev2Keyring/CLASSICAL-KEYRING/R3/ppk"
```

---

# An overlay of static VTIs in VRFs

The WAN interfaces in a front-door VRF, the tunnel in a VRF of its own:

```console
r1#show crypto ikev2 sa
Tunnel-id Local                 Remote                fvrf/ivrf            Status
3         10.0.12.1/500         10.0.23.2/500         WAN/OVERLAY          READY
r1#ping vrf OVERLAY 192.168.100.2
!!!!!
Success rate is 100 percent (5/5), round-trip min/avg/max = 1/24/114 ms
```

---

# Try it

[**https://netclab.dev**](https://netclab.dev)

*Read:*
[https://netclab.dev/netclab-xp/iosxe/](https://netclab.dev/netclab-xp/iosxe/)

*Install:*
[https://marketplace.upbound.io/configurations/netclab/configuration-iosxe](https://marketplace.upbound.io/configurations/netclab/configuration-iosxe)
