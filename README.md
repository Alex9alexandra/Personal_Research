# Empirical Evaluation of VPN Protocols on Public Wi-Fi

Research project: security benefits vs. performance cost of WireGuard, OpenVPN and
IKEv2/IPsec on a simulated public Wi-Fi network (cafe scenario with a passive attacker).

## What is here
- `Vagrantfile`, `scripts/provision/` - builds 4 Ubuntu VMs (client, attacker, gateway, vpnserver)
- `scripts/vpn/` - sets up WireGuard, OpenVPN and IKEv2 (strongSwan)
- `scripts/tests/` - checks that the lab works
- `scripts/experiments/` - E1 (what the attacker sees), E2 (performance), E3 (outage)
- `scripts/analysis/` - analysis of the results
- `config/sites.txt` - websites used in the experiments
- `results/` - small result files (CSV); raw captures are not committed
- `docs/` - the research report chapters and setup notes

## Requirements
Windows host, VMware Workstation Pro, Vagrant + `vagrant-vmware-desktop` plugin and the
Vagrant VMware Utility, Git for Windows (use Git Bash), Python 3.

## Reproduce
Run everything from the folder with the `Vagrantfile`, in Git Bash.

1. `vagrant up` (first time 15-30 min)
2. `bash scripts/tests/check_connectivity.sh` and `bash scripts/tests/check_attacker_visibility.sh`
3. `bash scripts/vpn/setup_wireguard.sh`, then `setup_openvpn.sh`, then `setup_ikev2.sh`
4. `bash scripts/experiments/run_e1.sh` (visibility)
5. `bash scripts/experiments/run_e2.sh`, then `python scripts/analysis/e2_analyze.py results/e2/<folder>`
6. `bash scripts/experiments/run_e3.sh`
7. `vagrant halt` when finished

If tests fail after a restart: `vagrant provision`

## Notes and limits
- Virtual layer-2 network, not real 802.11 Wi-Fi
- Measurements inside VMs are noisy, so each cell is repeated and reported with a 95 % confidence interval.
- Passive local attacker only. See `docs/` for the threat model and methodology.