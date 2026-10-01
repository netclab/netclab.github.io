---
marp: true
theme: default
author: Michal Bakalarski
title: Your AVD fabric, live in Kubernetes
keywords: kubernetes,crossplane,arista,avd,ansible,evpn,vxlan,eos_designs,networkautomation,cloudNative,eapi,iac,devops,gitops,netdevops,netclab,netadopt,function-avd
paginate: true
backgroundColor: '#1E293B'  # dark slate
color: '#F8FAFC'            # light text
---

# 🌐 Your AVD fabric, live in Kubernetes
*[**netadopt**](https://github.com/netclab/netadopt) and [**function-avd**](https://github.com/netclab/function-avd), powered by AVD*
<br>
> ***An extensible data model that defines Arista's Unified Cloud Network architecture as "code"***
> Powered by [avd.arista.com](https://avd.arista.com) and [crossplane.io](https://www.crossplane.io)

---

# 📐 Where this sits
<br>

***Your AVD repository*** <span style="color:#60A5FA">inventory · group_vars · playbook</span>
      ▼ <span style="color:#FBBF24">`netadopt`</span>
***Kubernetes objects*** <span style="color:#60A5FA">`Fabric` · `FabricInput`</span>
      ▼ <span style="color:#FBBF24">`function-avd`</span> runs AVD
***Every switch*** <span style="color:#60A5FA">`Device` → eAPI</span>

---

# 🔍 netadopt reads the repository

```console
$ git clone --depth 1 --branch v6.4.0 https://github.com/aristanetworks/avd
$ cd avd/ansible_collections/arista/avd/examples
$ uvx "netadopt[avd]" avd report single-dc-l3ls --playbook build.yml

Inventory   named by ansible.cfg   8 hosts, 8 groups
Variables   8 files                group_vars 8, host_vars 0
Playbook    build.yml              1 play

#   Play                                     Hosts    Roles
0   Build Configurations and Documentation   FABRIC   eos_designs, eos_cli_config_gen

Carried
  Fabric         single-dc-l3ls, from play 0
  FabricInputs   7
```

AVD's own `single-dc-l3ls` example, as Ansible reads it.

---

# 🧩 The repository, as objects

```console
$ uvx "netadopt[avd]" avd emit single-dc-l3ls --playbook build.yml > fabric.yaml
```

```yaml
kind: Fabric
metadata: {name: single-dc-l3ls}
spec:
  inputs: [single-dc-l3ls-network-services, ...]   # seven, one per group_vars directory
---
kind: FabricInput
metadata: {name: single-dc-l3ls-network-services}
spec:
  appliesTo: {group: NETWORK_SERVICES}
  design:                                    # group_vars/NETWORK_SERVICES/, unchanged
    tenants:
    - name: TENANT1
```

---

# 🧪 A lab from the same repository

```console
$ uvx "netadopt[avd]" avd lab single-dc-l3ls --playbook build.yml --namespace dc1 \
    --extra-vars-out lab-vars.yml --ceos-image ceos:4.36.1F \
    --ceos-cpu 800m --ceos-memory 1500Mi > values.yaml
$ uvx "netadopt[avd]" avd emit single-dc-l3ls --playbook build.yml \
    -e @lab-vars.yml > fabric.yaml
$ uvx netclab up --namespace dc1 --values values.yaml --crossplane v2.4.2 \
    --configuration xpkg.upbound.io/netclab/configuration-avd:v0.2.2 \
    --manifest runtime.yaml --manifest providerconfig.yaml --manifest fabric.yaml
```

- **One cEOS per switch in the inventory**, cabled as AVD cables them
- **`lab-vars.yml` points each switch at its cEOS pod**

---

# ✅ Eight switches, eight Devices

```console
$ kubectl -n dc1 get devices
NAME                        SYNCED   READY   COMPOSITION   AGE
single-dc-l3ls-dc1-leaf1a   True     True    device-avd    17s
single-dc-l3ls-dc1-leaf1b   True     True    device-avd    17s
single-dc-l3ls-dc1-leaf1c   True     True    device-avd    17s
single-dc-l3ls-dc1-leaf2a   True     True    device-avd    17s
single-dc-l3ls-dc1-leaf2b   True     True    device-avd    17s
single-dc-l3ls-dc1-leaf2c   True     True    device-avd    17s
single-dc-l3ls-dc1-spine1   True     True    device-avd    17s
single-dc-l3ls-dc1-spine2   True     True    device-avd    17s
```

One `Device` per switch, each holding the configuration AVD built for it.

---

# 🔁 Built, and running

```console
$ kubectl -n dc1 get devices single-dc-l3ls-dc1-leaf1a \
    -o jsonpath='{.status.configHash}{"\n"}{.status.deployed}'
sha256:6471751dc97b16d9
{"configHash":"sha256:6471751dc97b16d9","digest":"e31f4f334660655755ef8b069042c8485c80c360"}
```

- **`configHash`** — the configuration AVD built
- **`deployed`** — the configuration the switch runs

The same hash: the switch runs what the model says.

---

# ✍️ The change

```console
$ kubectl -n dc1 patch fabricinputs.avd.netclab.dev single-dc-l3ls-network-services \
    --type=json -p '[{"op": "add", "path": "/spec/design/tenants/0/vrfs/0/svis/-",
      "value": {"id": 13, "name": "VRF10_VLAN13", "enabled": true,
                "ip_address_virtual": "10.10.13.1/24"}}]'
```

One SVI, in a tenant VRF — the same edit as in `group_vars`.

**On `dc1-leaf1a` within a minute** — 34 s in this run.

---

# 📥 What reached `dc1-leaf1a`

```console
$ kubectl -n dc1 exec dc1-leaf1a -- Cli -p 15 -c "show running-config"   # the VLAN 13 lines
vlan 13
   name VRF10_VLAN13
interface Port-Channel8
   switchport trunk allowed vlan 11-13,21-22,3401-3402
interface Vlan13
   description VRF10_VLAN13
   vrf VRF10
   ip address virtual 10.10.13.1/24
interface Vxlan1
   vxlan vlan 13 vni 10013
router bgp 65101
   vlan 13
      rd 10.255.0.3:10013
      route-target both 10013:10013
```

---

# 🧠 Computed, not written
<br>

- **`vni 10013`** — the VXLAN VNI
- **`rd 10.255.0.3:10013`** — the route distinguisher, built from the leaf's own loopback
- **`route-target both 10013:10013`** — the EVPN route-target
- **`switchport trunk allowed vlan 11-13,…`** — the trunk list, *widened* rather than replaced

None of it is in the patch. AVD derived all of it from the design.

---

# 🎯 And where it did *not* land
<br>

```console
$ kubectl -n dc1 exec dc1-spine1 -- Cli -p 15 -c "show vlan 13"
% VLAN 13 not found in current VLAN database at line 1
```

`dc1-spine1` is in the same fabric. Nothing was excluded by hand: a tenant SVI belongs on leaves, so the model put it on leaves.

---

# ↩️ A change by hand goes back

```console
$ kubectl -n dc1 exec dc1-leaf1a -- Cli -p 15 -c $'configure\nno interface Vlan13\nend'
```

**Within about a minute `interface Vlan13` is back.**

The switch runs what the model says. To change it, change the model.

---

# ♻️ Delete it, the config stays
<br>

```console
$ kubectl -n dc1 delete -f fabric.yaml
$ kubectl -n dc1 exec dc1-leaf1a -- Cli -p 15 -c "show vlan 13"
VLAN  Name                             Status    Ports
----- -------------------------------- --------- -------------------------------
13    VRF10_VLAN13                     active    Cpu, Po3, Po8, Vx1
```

The Fabric, its Devices and their Requests are gone. **The configuration stays**: a push replaces a switch's whole configuration, so reverting it on delete would wipe the switch.

---

# 🎯 Try it

[**https://netclab.dev**](https://netclab.dev)

*Read a repository, and bring up its lab:*
[https://pypi.org/project/netadopt/](https://pypi.org/project/netadopt/)
[https://pypi.org/project/netclab/](https://pypi.org/project/netclab/)

*Run it in Kubernetes:*
[https://github.com/netclab/function-avd](https://github.com/netclab/function-avd)
[https://marketplace.upbound.io/configurations/netclab/configuration-avd](https://marketplace.upbound.io/configurations/netclab/configuration-avd)
