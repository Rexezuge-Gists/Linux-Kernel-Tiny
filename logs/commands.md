# KernelSlim Command Log

This directory contains command-by-command logs for reproducing the kernel build and test workflow.

Commands run before this logger was created during initial inspection:

```sh
pwd
uname -a
ls
ls /boot
nproc
df -h .
free -h
test -r /proc/config.gz && zgrep '^CONFIG_' /proc/config.gz | wc -l || true
dpkg-query -W build-essential bc bison flex libssl-dev libelf-dev dwarves fakeroot rsync openssh-client 2>/dev/null || true
test -r /boot/config-$(uname -r) && wc -l /boot/config-$(uname -r) || true
dpkg-query -W dwarves pahole libncurses-dev bindeb-pkg 2>/dev/null || true
ssh -o BatchMode=yes -o ConnectTimeout=5 172.171.1.151 'uname -a'
```

Initial findings: host is Ubuntu aarch64 running `6.17.0-1013-azure`; current config is `/boot/config-6.17.0-1013-azure`; latest 6.18 LTS from kernel.org is `6.18.32`; first SSH attempt failed with host key verification.

## Reproducibility Map

- Build host/resource/dependency logs: `00-system-info.log`, `01-dependencies.log`
- Source download/extract logs: `02-download.log`
- Config migration and staged configs: `03-current-config.log`, `04-config-conservative.log`, `09-config-balanced.log`, `13-config-aggressive.log`
- Package build logs: `05-build-conservative.log`, `05-build-conservative-azure.log`, `10-build-balanced.log`, `14-build-aggressive.log`
- Package artifact checksums and sizes: `06-package-list.log`, `17-final-summary.log`
- Test VM logs: `07-test-host.log`, `08-test-host-20.9.44.143.log`, `12-test-balanced-20.9.44.143.log`, `16-test-aggressive-20.9.44.143.log`
- Kernel memory usage logs: `11-kernel-memory-usage.log`, `15-original-kernel-memory-135.119.42.168.log`

## Config Stages

- `configs/00-current-host-6.17.0-1013-azure.config`: copied from `/boot/config-$(uname -r)` on the build host.
- `configs/01-olddefconfig-6.18.32.config`: migrated to Linux `6.18.32` with `make olddefconfig`.
- `configs/02-conservative-vm-containers-6.18.32.config`: conservative VM/container feature enablement.
- `configs/03-conservative-no-debug-6.18.32.config`: conservative config with debug info disabled.
- `configs/04-conservative-azure-builtins-6.18.32.config`: conservative config with Azure/Hyper-V boot-critical network/storage built in; this booted and passed Docker/LXC tests.
- `configs/05-balanced-vm-containers-6.18.32.config`: removes obvious non-VM subsystems; booted and passed Docker/LXC tests.
- `configs/06-aggressive-vm-containers-6.18.32.config`: removes additional optional protocols/subsystems; booted and passed Docker/LXC tests.

## Built Kernel Package Versions

- Conservative: `6.18.32-kernelslim1`, localversion `-kernelslim-conservative`; built but failed first test VM boot.
- Conservative Azure builtins: `6.18.32-kernelslim2`, localversion `-kernelslim-conservative-azure`; passed on `20.9.44.143`.
- Balanced: `6.18.32-kernelslim3`, localversion `-kernelslim-balanced`; passed on `20.9.44.143`.
- Aggressive: `6.18.32-kernelslim4`, localversion `-kernelslim-aggressive`; passed on `20.9.44.143`.
