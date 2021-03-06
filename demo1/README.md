# NVUE First Steps

> All commands are executed from the perspective of leaf1

* how to start

```
sudo apt-get update && sudo apt install -y jq
sudo systemctl status nvued
sudo systemctl start nvued
sudo systemctl status nvued
```

* View the logs 

```
sudo journalctl -u nvued -f &
```

* Enable debug if necessary
```
cat /etc/default/nvued
sudo systemctl restart nvued
```

* trace API calls 

```
nv show system
INFO:  <local> - - [08/Oct/2021 16:11:39] "GET /nvue_v1/system?rev=operational HTTP/1.1" 200 -
INFO:  <local> - - [08/Oct/2021 16:11:39] "GET /nvue_v1/system?rev=applied HTTP/1.1" 200 -
```

* set switch loopback on leaf01

```
nv set interface lo ip address 10.10.10.1/32
nv set interface swp1,swp2
```

* view the current diff

```
nv config diff
- set:
    interface:
      lo:
        ip:
          address:
            10.10.10.1/32: {}
        type: loopback
      swp1-2:
        type: swp
```

* apply the config

```
nv config apply -y
```

* View the config metadata
```
$ sudo -i
$ ls /var/lib/nvue/meta/
changeset  empty  startup
$ cat /var/lib/nvue/meta/changeset/cumulus/2021-10-11_13.27.23_T9YW
state: applied
$ cat /var/lib/nvue/meta/empty
{}
```

* View the commit history

```
nv config history
- apply-meta:
    method: CLI
    reason: Config update
    rev_id: changeset/cumulus/2021-10-11_13.27.23_T9YW
    state_controls:
      confirm: 600
    user: cumulus
  date: '2021-10-11T13:28:41+00:00'
  message: Config update by cumulus via CLI
  ref: apply/2021-10-11_13.28.31_T9YX/done
```

* View the staged config files

```
$ cd /var/lib/nvue/config/
$ cat eni
...
auto lo
iface lo inet loopback
    address 10.10.10.1/32

auto swp1
iface swp1

auto swp2
iface swp2 
...
```

* Verify that the ref is based on the git tag 

```
git log --pretty=oneline --abbrev-commit
3e380e5 (HEAD -> applied, tag: apply/latest/success, tag: apply/2021-10-11_13.28.31_T9YX/success, tag: apply/2021-10-11_13.28.31_T9YX/done) Config update by cumulus via CLI
83f46bb (apply/2021-10-11_13.28.31_T9YX) Reloading
e1d47bc Readying acltool_v1
e33818c Readying acltool_v1
afe8956 Readying dhcp_relay_v1
5251733 Readying dns_v1
25e7fc0 Readying env_v1
be5f722 Readying frr_v1
acefc30 Readying ifupdown2_v1
7f19baf Readying isc_dhcp_v1
a678c25 Readying linuxptp_v1
9ffe86b Readying lldp_v1
916833d Readying ntp_v1
8a72414 Readying platform_config_v1
7ca75d3 Readying ports_v1
06606ee Readying procps_v1
1f2fe14 Readying qos_v1
a64ba4a Readying rsyslog_v1
3272748 Readying snmp_server_v1
87b694a Readying switchd_v1
7ee6a5a Saving nvue.json
a58f059 Starting apply
2024c8d (tag: apply/2021-10-11_13.28.31_T9YX/start) Config repository created
```

* View the current configuration tree along with all its defaults

```
$ cat nvue.json  | jq '.opinions.interface.lo'
{
  "ip": {
    "address": {
      "10.10.10.1/32": {}
    }
  },
  "type": "loopback"
}
```

* another way to see what's changed

```
$ git log -p
diff --git a/eni.dst b/eni.dst
new file mode 100644
index 0000000..21698f6
--- /dev/null
+++ b/eni.dst
@@ -0,0 +1,29 @@
+# Auto-generated by NVUE!
+# Any local modifications will prevent NVUE from re-generating this file.
+# md5sum: f70bc940751a1b42f46bb9fb1abdb2b2
+# This file describes the network interfaces available on your system
+# and how to activate them. For more information, see interfaces(5).
+
+source /etc/network/interfaces.d/*.intf
+
+auto lo
+iface lo inet loopback
+    address 10.10.10.1/32
+
```

* add BGP config on leaf1

```
nv set router bgp autonomous-system 65101
nv set router bgp router-id 10.10.10.1
nv set vrf default router bgp neighbor swp2 remote-as external
```

* demonstrate commit confirm

```
nv config apply --confirm
nv config apply apply/2021-10-11_13.41.37_T9Z0/done  --confirm-yes
```

* rollback and roll forward

```
$ nv config history | grep ref
  ref: apply/2021-10-11_13.42.54_T9Z2/done
  ref: apply/2021-10-11_13.42.25_T9Z1/done
  ref: apply/2021-10-11_13.41.37_T9Z0/done
  ref: apply/2021-10-11_13.28.31_T9YX/done
$ nv config apply apply/2021-10-11_13.28.31_T9YX/done
```

* nv authentication

```
cat /etc/nvue-auth.yaml
```

* Redistribute loopback on leaf1 
```
nv set vrf default router bgp address-family ipv4-unicast redistribute connected
```

* Verify the current state of BGP
```
cumulus@leaf1:mgmt:~$ sudo vtysh -c "show ip bgp summary"

IPv4 Unicast Summary:
BGP router identifier 10.10.10.1, local AS number 65101 vrf-id 0
BGP table version 0
RIB entries 0, using 0 bytes of memory
Peers 1, using 23 KiB of memory

Neighbor        V         AS   MsgRcvd   MsgSent   TblVer  InQ OutQ  Up/Down State/PfxRcd   PfxSnt
swp2            4          0         0         0        0    0    0    never         Idle        0

Total number of neighbors 1
```

======================================== CUT ========================================


* Verify BGP sessions
```
cumulus@spine:mgmt:~$ sudo vtysh -c "show ip bgp summary"

IPv4 Unicast Summary:
BGP router identifier 10.10.10.100, local AS number 65100 vrf-id 0
BGP table version 0
RIB entries 0, using 0 bytes of memory
Peers 2, using 46 KiB of memory

Neighbor        V         AS   MsgRcvd   MsgSent   TblVer  InQ OutQ  Up/Down State/PfxRcd   PfxSnt
leaf1(swp1)     4      65101       105       105        0    0    0 00:05:08            0        0
leaf2(swp2)     4      65102       104       104        0    0    0 00:05:05            0        0
```

* Configure spine01
```
sudo systemctl start nvued
sudo systemctl enable nvued
nv set system hostname spine
nv set interface lo ip address 10.10.10.100/32
nv set interface swp1,swp2
nv set router bgp autonomous-system 65100
nv set router bgp router-id 10.10.10.100
nv set vrf default router bgp neighbor swp1 remote-as external
nv set vrf default router bgp neighbor swp2 remote-as external
nv config apply -y
```


* Configure leaf2

```
sudo systemctl start nvued
sudo systemctl enable nvued
nv set system hostname leaf2
nv set interface lo ip address 10.10.10.2/32
nv set interface swp1,swp2
nv set router bgp autonomous-system 65102
nv set router bgp router-id 10.10.10.1
nv set vrf default router bgp neighbor swp2 remote-as external
nv config apply -y
```

* Verify BGP sessions
```
cumulus@spine:mgmt:~$ sudo vtysh -c "show ip bgp summary"

IPv4 Unicast Summary:
BGP router identifier 10.10.10.100, local AS number 65100 vrf-id 0
BGP table version 0
RIB entries 0, using 0 bytes of memory
Peers 2, using 46 KiB of memory

Neighbor        V         AS   MsgRcvd   MsgSent   TblVer  InQ OutQ  Up/Down State/PfxRcd   PfxSnt
leaf1(swp1)     4      65101       105       105        0    0    0 00:05:08            0        0
leaf2(swp2)     4      65102       104       104        0    0    0 00:05:05            0        0
```

* Redistribute loopback on leaf1, leaf2 and spine 

```
nv set vrf default router bgp address-family ipv4-unicast redistribute connected```
```

* Verify BGP sessions
```
cumulus@spine:mgmt:~$ sudo vtysh -c "show ip bgp summary"

IPv4 Unicast Summary:
BGP router identifier 10.10.10.100, local AS number 65100 vrf-id 0
BGP table version 3
RIB entries 5, using 1000 bytes of memory
Peers 2, using 46 KiB of memory

Neighbor        V         AS   MsgRcvd   MsgSent   TblVer  InQ OutQ  Up/Down State/PfxRcd   PfxSnt
leaf1(swp1)     4      65101       258       259        0    0    0 00:12:39            1        3
leaf2(swp2)     4      65102       257       258        0    0    0 00:12:36            1        3

Total number of neighbors 2
```

* Verify the BGP table in the default vrf
```
cumulus@spine:mgmt:~$ sudo vtysh -c "show ip bgp"
BGP table version is 3, local router ID is 10.10.10.100, vrf id 0
Default local pref 100, local AS 65100
Status codes:  s suppressed, d damped, h history, * valid, > best, = multipath,
               i internal, r RIB-failure, S Stale, R Removed
Nexthop codes: @NNN nexthop's vrf id, < announce-nh-self
Origin codes:  i - IGP, e - EGP, ? - incomplete

   Network          Next Hop            Metric LocPrf Weight Path
*> 10.10.10.1/32    swp1                     0             0 65101 ?
*> 10.10.10.2/32    swp2                     0             0 65102 ?
*> 10.10.10.100/32  0.0.0.0                  0         32768 ?

Displayed  3 routes and 3 total paths
```

* Validate the loopback connectivity between the leaf1 and leaf2
```
cumulus@leaf1:mgmt:~$ ping -c4 10.10.10.2
vrf-wrapper.sh: switching to vrf "default"; use '--no-vrf-switch' to disable
PING 10.10.10.2 (10.10.10.2) 56(84) bytes of data.
64 bytes from 10.10.10.2: icmp_seq=1 ttl=63 time=0.541 ms
64 bytes from 10.10.10.2: icmp_seq=2 ttl=63 time=0.536 ms
64 bytes from 10.10.10.2: icmp_seq=3 ttl=63 time=0.588 ms
64 bytes from 10.10.10.2: icmp_seq=4 ttl=63 time=0.620 ms

--- 10.10.10.2 ping statistics ---
4 packets transmitted, 4 received, 0% packet loss, time 85ms
rtt min/avg/max/mdev = 0.536/0.571/0.620/0.038 ms

