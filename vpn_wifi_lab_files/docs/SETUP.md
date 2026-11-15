# Lab setup (VMware Workstation Pro + Vagrant)

## Topology

| VM        | Role                          | Networks                                              |
|-----------|-------------------------------|-------------------------------------------------------|
| client    | the person in the cafe        | CAFE `10.10.0.10`                                     |
| attacker  | passive observer, same Wi-Fi  | CAFE `10.10.0.66` (promiscuous mode)                  |
| gateway   | cafe router + NAT to internet | CAFE `10.10.0.254`, TRANSIT `10.20.0.254`, NAT uplink |
| vpnserver | remote VPN endpoint           | TRANSIT `10.20.0.2`                                   |

The host's own VMware adapter takes `.1` on each network, which is why the gateway uses `.254`.

## One-time installation (PowerShell or Git Bash, any folder)

```
vagrant plugin install vagrant-vmware-desktop
```

Also install the **Vagrant VMware Utility** (HashiCorp download page), then restart Windows if asked.

## Running the lab (always from the repo folder, the one containing `Vagrantfile`)

```
vagrant up                 # creates and provisions all 4 VMs (first time: 15-30 min)
vagrant status             # all four should say "running"
bash scripts/tests/check_connectivity.sh
bash scripts/tests/check_attacker_visibility.sh
```

Useful commands:

```
vagrant ssh client         # open a shell inside a VM (exit with `exit`)
vagrant halt               # shut all VMs down
vagrant up gateway         # start a single VM
vagrant provision client   # re-run the provisioning script of one VM
vagrant destroy -f         # delete all VMs (the repo files stay)
```

Start order matters only on the very first run; `vagrant up` handles it
(gateway, vpnserver, client, attacker).

## If the attacker sees nothing

1. Check that VMware allows promiscuous mode (Windows: it normally does for administrators; run VMware as administrator once).
2. Fall back to capturing on the gateway's cafe-side interface:
   `vagrant ssh gateway -c "source /etc/lab-env; sudo tcpdump -i \$CAFE_IF -nn -w /tmp/cafe.pcap"`.
   This sees the same frames as a passive attacker on the same network; document this choice in the threat-model chapter.

## Known limitations

- Virtual L2 network, not real 802.11 Wi-Fi.
- CPU and throughput measurements inside VMs are noisy, hence repeated runs and confidence intervals.
