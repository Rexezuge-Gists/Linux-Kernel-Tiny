# KernelSlim Agent Guide

## Background

KernelSlim is a reproducible Linux kernel slimming project for ARM64 virtual machines. The work started from the running Ubuntu Azure kernel configuration on the build host and migrated it to the latest Linux `6.18` longterm release available at the time: `6.18.32`.

The project builds Debian kernel packages from upstream Linux source and validates them on disposable Azure ARM64 virtual machines. The primary runtime requirements are cloud VM bootability and container support, specifically Docker and LXC with real container launches.

The original build host was Ubuntu 24.04 ARM64 running:

```text
Linux build 6.17.0-1013-azure #13~24.04.1-Ubuntu SMP Wed Apr 15 17:07:43 UTC 2026 aarch64
```

The source kernel used is:

```text
Linux 6.18.32 longterm
https://cdn.kernel.org/pub/linux/kernel/v6.x/linux-6.18.32.tar.xz
```

## Goal

Build a minimal but practical Linux kernel for ARM64 cloud virtual machines that can run on environments such as:

- KVM/QEMU
- Microsoft Azure
- Google Cloud
- AWS
- General virtio-based VM platforms

The kernel must support container workloads, especially:

- Docker with `overlayfs`, cgroup v2, namespaces, seccomp, bridge networking, veth, and netfilter/NAT.
- LXC with Debian ARM64 containers, namespaces, cgroups, veth, bridge networking, and basic container process isolation.

The project intentionally progresses in passes:

- Conservative: maximize boot/container success.
- Balanced: remove obvious non-VM hardware/subsystems while preserving broad cloud/container support.
- Aggressive: remove additional optional protocols/subsystems while preserving tested Docker/LXC functionality.

## Current Status

Three useful custom kernels were produced and tested:

| Kernel | Package version | Local version | Image package size | Status |
| --- | --- | --- | --- | --- |
| Conservative Azure builtins | `6.18.32-kernelslim2` | `-kernelslim-conservative-azure` | `102M` | Boots, Docker passes, LXC passes |
| Balanced | `6.18.32-kernelslim3` | `-kernelslim-balanced` | `69M` | Boots, Docker passes, LXC passes |
| Aggressive | `6.18.32-kernelslim4` | `-kernelslim-aggressive` | `59M` | Boots, Docker passes, LXC passes |

The best current output is the aggressive kernel:

```text
artifacts/linux-image-6.18.32-kernelslim-aggressive_6.18.32-kernelslim4_arm64.deb
artifacts/linux-headers-6.18.32-kernelslim-aggressive_6.18.32-kernelslim4_arm64.deb
```

## Important Incident

The first conservative kernel, `6.18.32-kernelslim-conservative`, built successfully but failed to bring the first test VM back on SSH after reboot. After that failure, the config was updated so Azure/Hyper-V storage and network paths are built into the kernel instead of modules. The fixed config became `04-conservative-azure-builtins` and successfully booted on the replacement test VM.

If a future kernel fails to boot and kills the test VM, do not keep retrying on that dead VM. Modify the config based on the suspected failure, build the next package, then stop and ask the user to provide a fresh test machine.

## Project Structure

```text
.
├── AGENTS.md
├── artifacts/
│   ├── linux-image-*.deb
│   ├── linux-headers-*.deb
│   └── linux-libc-dev_6.18.32-kernelslim1_arm64.deb
├── build/
├── configs/
│   ├── 00-current-host-6.17.0-1013-azure.config
│   ├── 01-olddefconfig-6.18.32.config
│   ├── 02-conservative-vm-containers-6.18.32.config
│   ├── 03-conservative-no-debug-6.18.32.config
│   ├── 04-conservative-azure-builtins-6.18.32.config
│   ├── 05-balanced-vm-containers-6.18.32.config
│   ├── 05-balanced-vs-04.diff
│   ├── 06-aggressive-vm-containers-6.18.32.config
│   └── 06-aggressive-vs-05.diff
├── logs/
│   ├── commands.md
│   ├── 00-system-info.log
│   ├── 01-dependencies.log
│   ├── 02-download.log
│   ├── 03-current-config.log
│   ├── 04-config-conservative.log
│   ├── 05-build-conservative.log
│   ├── 05-build-conservative-azure.log
│   ├── 06-package-list.log
│   ├── 08-test-host-20.9.44.143.log
│   ├── 09-config-balanced.log
│   ├── 10-build-balanced.log
│   ├── 11-kernel-memory-usage.log
│   ├── 12-test-balanced-20.9.44.143.log
│   ├── 13-config-aggressive.log
│   ├── 14-build-aggressive.log
│   ├── 15-original-kernel-memory-135.119.42.168.log
│   ├── 16-test-aggressive-20.9.44.143.log
│   └── 17-final-summary.log
├── scripts/
│   ├── kernel-memory-usage.sh
│   └── run_logged.sh
└── sources/
    ├── linux-6.18.32/
    └── linux-6.18.32.tar.xz
```

## Logging Requirements

Every substantive command must be recorded under `logs/`. Use the helper:

```sh
./scripts/run_logged.sh logs/<log-name>.log '<description>' <command> [args...]
```

When running from inside the Linux source tree, use absolute paths:

```sh
/home/azureuser/KernelSlim/scripts/run_logged.sh \
  /home/azureuser/KernelSlim/logs/<log-name>.log \
  '<description>' \
  make -j8 bindeb-pkg KDEB_PKGVERSION=<version>
```

The logger records:

- UTC timestamp
- description
- working directory
- exact command with shell quoting
- stdout/stderr
- exit code

Update `logs/commands.md` when adding major workflow stages or new config branches.

## Build Host Dependencies

The build host uses Ubuntu 24.04 ARM64. Required packages include:

```sh
sudo apt-get update
sudo apt-get install -y \
  build-essential bc bison flex libssl-dev libelf-dev libdw-dev dwarves \
  fakeroot rsync openssh-client libncurses-dev debhelper xz-utils zstd \
  kmod cpio
```

Dependencies installed during this run are logged in:

```text
logs/01-dependencies.log
```

## Source Download

The Linux source was downloaded from kernel.org:

```sh
wget -O sources/linux-6.18.32.tar.xz \
  https://cdn.kernel.org/pub/linux/kernel/v6.x/linux-6.18.32.tar.xz
sha256sum sources/linux-6.18.32.tar.xz
tar -C sources -xf sources/linux-6.18.32.tar.xz
```

Recorded checksum:

```text
067dadd445578284ea6158f312f7970d8940fed3e094dbe49cff66d188d3bda4  sources/linux-6.18.32.tar.xz
```

## Config Lineage

Always create a numbered config copy for each meaningful change. Do not overwrite a previous config stage without saving a new numbered copy.

### `00-current-host-6.17.0-1013-azure.config`

Copied from the build host:

```sh
cp /boot/config-$(uname -r) configs/00-current-host-6.17.0-1013-azure.config
```

### `01-olddefconfig-6.18.32.config`

The current Ubuntu Azure config migrated to Linux `6.18.32`:

```sh
cp configs/00-current-host-6.17.0-1013-azure.config sources/linux-6.18.32/.config
make olddefconfig
cp sources/linux-6.18.32/.config configs/01-olddefconfig-6.18.32.config
```

### `02-conservative-vm-containers-6.18.32.config`

Conservative cloud VM and container support policy. Explicitly preserves or enables:

- cgroups and cgroup BPF
- namespaces including user and network namespaces
- seccomp and seccomp filter
- BPF syscall/JIT
- overlayfs
- bridge, veth, tun
- netfilter, nftables, iptables compatibility, NAT, conntrack
- virtio PCI/block/net/SCSI
- NVMe
- AWS ENA, Google GVE, Azure Hyper-V net/storage, Microsoft MANA
- EFI/EFI stub
- ext4

### `03-conservative-no-debug-6.18.32.config`

Conservative config with debug info disabled through the Kconfig choice:

```text
CONFIG_DEBUG_INFO_NONE=y
# CONFIG_DEBUG_INFO_DWARF5 is not set
# CONFIG_DEBUG_INFO_BTF is not set
```

### `04-conservative-azure-builtins-6.18.32.config`

This is the first tested-good config. It changes boot-critical Azure/Hyper-V and virtio paths from modules to built-ins where needed:

```text
CONFIG_HYPERV=y
CONFIG_HYPERV_VMBUS=y
CONFIG_HYPERV_STORAGE=y
CONFIG_HYPERV_NET=y
CONFIG_MICROSOFT_MANA=y
CONFIG_VIRTIO_PCI=y
CONFIG_VIRTIO_BLK=y
CONFIG_VIRTIO_NET=y
CONFIG_SCSI_VIRTIO=y
CONFIG_BLK_DEV_NVME=y
CONFIG_BLK_DEV_SD=y
CONFIG_EXT4_FS=y
CONFIG_VETH=y
CONFIG_TUN=y
CONFIG_OVERLAY_FS=y
```

### `05-balanced-vm-containers-6.18.32.config`

Balanced removes obvious non-VM subsystems while keeping the tested boot/container core.

Major removals include:

- media
- sound
- Bluetooth
- Wi-Fi/wireless stack
- CAN
- hamradio
- NFC
- InfiniBand
- many uncommon filesystems
- DRM/framebuffer/display stack
- joystick/tablet/touchscreen/gameport paths

Size movement:

```text
04 config lines: 14503
05 config lines: 11781
05-balanced-vs-04.diff lines: 3573
```

### `06-aggressive-vm-containers-6.18.32.config`

Aggressive removes more optional networking/filesystem/protocol subsystems while preserving tested Docker/LXC functionality.

Major removals include:

- DSA
- MPLS
- L2TP
- Open vSwitch
- vsockets
- 9p
- USB stack
- SPI
- network scheduler/classifier/action stack
- many optional network protocols

Size movement:

```text
05 config lines: 11781
06 config lines: 9925
06-aggressive-vs-05.diff lines: 3947
```

Note: `CONFIG_I2C=m` remained due dependencies in the aggressive pass. Do not force-remove dependency chains without testing.

## Package Build Commands

Run builds from `sources/linux-6.18.32`.

Conservative Azure builtins:

```sh
make -j8 bindeb-pkg KDEB_PKGVERSION=6.18.32-kernelslim2
```

Balanced:

```sh
make -j8 bindeb-pkg KDEB_PKGVERSION=6.18.32-kernelslim3
```

Aggressive:

```sh
make -j8 bindeb-pkg KDEB_PKGVERSION=6.18.32-kernelslim4
```

After a successful build, copy packages from `sources/` into `artifacts/` and record checksums:

```sh
cp sources/linux-image-*.deb sources/linux-headers-*.deb artifacts/
sha256sum artifacts/*.deb
```

## Artifact Checksums

Final checksums are recorded in `logs/06-package-list.log` and `logs/17-final-summary.log`.

Important image package checksums:

```text
3b8d1c307f6cbf6cf8ddc77c182b17fd7bd44cd8828756df2616c356d1aabd0d  artifacts/linux-image-6.18.32-kernelslim-conservative-azure_6.18.32-kernelslim2_arm64.deb
796094849bb556739bac1c0955aed980e26df0d3fb5c7fe606ea4f5b7fb74d8c  artifacts/linux-image-6.18.32-kernelslim-balanced_6.18.32-kernelslim3_arm64.deb
99e3810e39799c144edf992d1be8b00ebe1fcc9f0096a874e5ccd251cf9578b5  artifacts/linux-image-6.18.32-kernelslim-aggressive_6.18.32-kernelslim4_arm64.deb
```

## Test Procedure

Use disposable ARM64 test VMs. The known tested VM was:

```text
20.9.44.143
Ubuntu 24.04 ARM64
Original kernel: 6.17.0-1013-azure
```

Accept the host key:

```sh
ssh-keyscan -H <ip> >> ~/.ssh/known_hosts
```

Verify host state:

```sh
ssh <ip> 'set -x; uname -a; dpkg --print-architecture; df -h /boot /'
```

Copy packages:

```sh
ssh <ip> 'mkdir -p ~/kernelslim-test'
scp artifacts/linux-image-<kernel>.deb artifacts/linux-headers-<kernel>.deb \
  <ip>:/home/azureuser/kernelslim-test/
```

Install packages:

```sh
ssh <ip> 'set -x; cd ~/kernelslim-test; sudo dpkg -i ./linux-image-<kernel>.deb ./linux-headers-<kernel>.deb'
```

Set a one-time GRUB boot entry:

```sh
ssh <ip> 'sudo grub-reboot "Advanced options for Ubuntu>Ubuntu, with Linux <kernel-release>"; sudo grub-editenv list'
```

Reboot:

```sh
ssh <ip> 'sudo reboot'
```

Wait for SSH:

```sh
for i in $(seq 1 72); do
  if ssh -o BatchMode=yes -o ConnectTimeout=5 <ip> 'set -x; uname -a'; then
    exit 0
  fi
  sleep 5
exit 1
```

If SSH does not return, treat the VM as potentially dead. Do not assume it recovered unless SSH confirms it. Prepare a config fix, then ask the user for a new test VM.

## Required Runtime Validation

Every accepted kernel must pass all of these under the custom kernel:

1. Boot and return on SSH.
2. Run `scripts/kernel-memory-usage.sh`.
3. Start Docker and run a real Docker container.
4. Create and launch a real Debian LXC container.

### Docker Test

Install Docker/LXC if not already present:

```sh
sudo apt-get update
sudo DEBIAN_FRONTEND=noninteractive apt-get install -y \
  lxc lxc-templates uidmap bridge-utils docker.io
```

Start services:

```sh
sudo systemctl enable --now lxc-net lxc docker containerd
```

Run Docker validation:

```sh
sudo docker info
sudo docker run --rm hello-world
```

Expected signal:

```text
Hello from Docker!
```

### Debian LXC Test

Run a Debian Bookworm ARM64 container:

```sh
sudo lxc-destroy -n kernelslim-debian-<tag> -f 2>/dev/null || true
sudo lxc-create -n kernelslim-debian-<tag> -t download -- -d debian -r bookworm -a arm64
sudo lxc-start -n kernelslim-debian-<tag>
sudo lxc-info -n kernelslim-debian-<tag>
sudo lxc-attach -n kernelslim-debian-<tag> -- /bin/sh -lc 'uname -a; cat /etc/os-release; hostname; ip addr show || true'
sudo lxc-stop -n kernelslim-debian-<tag>
```

Expected signal:

```text
PRETTY_NAME="Debian GNU/Linux 12 (bookworm)"
```

## Kernel Memory Usage Script

The script is saved at:

```text
scripts/kernel-memory-usage.sh
```

Copy and run it on every tested kernel:

```sh
scp scripts/kernel-memory-usage.sh <ip>:/home/azureuser/kernelslim-test/kernel-memory-usage.sh
ssh <ip> 'chmod +x ~/kernelslim-test/kernel-memory-usage.sh; uname -a; ~/kernelslim-test/kernel-memory-usage.sh'
```

Recorded memory measurements:

```text
Original Ubuntu Azure kernel on fresh VM 135.119.42.168: 110.77 MB
Conservative Azure-builtins on container test VM:         199.73 MB
Balanced on container test VM:                           107.40 MB
Aggressive on container test VM:                         102.11 MB
```

Memory results are workload-sensitive. The conservative/balanced/aggressive values were collected on a VM where Docker/LXC packages and tests had been installed and run. The original value was collected on a fresh unmodified VM.

## Version Diff Summary

The project started from Ubuntu Azure `6.17.0-1013-azure` config and migrated to upstream Linux `6.18.32`.

Line count by config stage:

```text
14432 configs/00-current-host-6.17.0-1013-azure.config
14521 configs/01-olddefconfig-6.18.32.config
14515 configs/02-conservative-vm-containers-6.18.32.config
14503 configs/03-conservative-no-debug-6.18.32.config
14503 configs/04-conservative-azure-builtins-6.18.32.config
11781 configs/05-balanced-vm-containers-6.18.32.config
 9925 configs/06-aggressive-vm-containers-6.18.32.config
```

Package size movement:

```text
102M linux-image-6.18.32-kernelslim-conservative-azure_6.18.32-kernelslim2_arm64.deb
 69M linux-image-6.18.32-kernelslim-balanced_6.18.32-kernelslim3_arm64.deb
 59M linux-image-6.18.32-kernelslim-aggressive_6.18.32-kernelslim4_arm64.deb
```

Boot image movement on test VM:

```text
18M /boot/vmlinuz-6.18.32-kernelslim-conservative-azure
17M /boot/vmlinuz-6.18.32-kernelslim-balanced
16M /boot/vmlinuz-6.18.32-kernelslim-aggressive
```

Initramfs movement on test VM:

```text
56M /boot/initrd.img-6.18.32-kernelslim-conservative-azure
51M /boot/initrd.img-6.18.32-kernelslim-balanced
46M /boot/initrd.img-6.18.32-kernelslim-aggressive
```

## Configuration Safety Rules

Keep these enabled or built-in unless there is a tested reason to change them:

```text
CONFIG_HYPERV=y
CONFIG_HYPERV_VMBUS=y
CONFIG_HYPERV_STORAGE=y
CONFIG_HYPERV_NET=y
CONFIG_MICROSOFT_MANA=y
CONFIG_VIRTIO_PCI=y
CONFIG_VIRTIO_BLK=y
CONFIG_VIRTIO_NET=y
CONFIG_SCSI_VIRTIO=y
CONFIG_BLK_DEV_NVME=y
CONFIG_BLK_DEV_SD=y
CONFIG_EXT4_FS=y
CONFIG_DEVTMPFS=y
CONFIG_TMPFS=y
CONFIG_PROC_FS=y
CONFIG_SYSFS=y
CONFIG_OVERLAY_FS=y
CONFIG_VETH=y
CONFIG_TUN=y
CONFIG_BRIDGE=y
CONFIG_NETFILTER=y
CONFIG_NF_TABLES=y
CONFIG_NF_NAT=y
CONFIG_NF_CONNTRACK=y
CONFIG_IP_NF_IPTABLES=y or m
CONFIG_IP_NF_NAT=y or m
CONFIG_IP6_NF_IPTABLES=y or m
CONFIG_IP6_NF_NAT=y or m
CONFIG_CGROUPS=y
CONFIG_MEMCG=y
CONFIG_CGROUP_BPF=y
CONFIG_CGROUP_PIDS=y
CONFIG_NAMESPACES=y
CONFIG_USER_NS=y
CONFIG_NET_NS=y
CONFIG_PID_NS=y
CONFIG_IPC_NS=y
CONFIG_UTS_NS=y
CONFIG_SECCOMP=y
CONFIG_SECCOMP_FILTER=y
CONFIG_BPF=y
CONFIG_BPF_SYSCALL=y
```

Be careful disabling these because they are commonly required for cloud-init, initramfs, Docker, LXC, or cloud networking:

- `CONFIG_FHANDLE`
- `CONFIG_EVENTFD`
- `CONFIG_EPOLL`
- `CONFIG_UNIX_DIAG`
- `CONFIG_INET_DIAG`
- `CONFIG_PACKET_DIAG`
- `CONFIG_NETLINK_DIAG`
- `CONFIG_POSIX_MQUEUE`
- `CONFIG_KEYS`
- `CONFIG_SECURITY`
- `CONFIG_SECURITY_APPARMOR`
- `CONFIG_TMPFS_POSIX_ACL`
- `CONFIG_TMPFS_XATTR` if unprivileged LXC or some systemd/container features regress

## Future Work Ideas

Potential next reductions, each requiring a new numbered config and full boot/Docker/LXC test:

- Remove remaining optional TCP congestion modules if not needed.
- Further trim IPv6 tunneling, IPsec/XFRM, and diagnostic modules if Docker/LXC/networking still pass.
- Investigate remaining `CONFIG_I2C=m` dependency chain.
- Compare memory usage on equal fresh VMs for original, conservative, balanced, and aggressive to reduce workload bias.
- Test the aggressive package on AWS/GCP/KVM ARM64 if available.

## Agent Operating Notes

- This workspace may not be a git repository. Do not assume git history exists.
- Do not delete or overwrite logs, configs, or artifacts from previous stages.
- Always create the next numbered config copy for every config mutation.
- Always run package builds through `scripts/run_logged.sh`.
- Always copy final `.deb` packages into `artifacts/` and record `sha256sum`.
- Always validate with both Docker and Debian LXC, not just config checks.
- If a test VM dies, stop testing on it. Modify config if there is an obvious cause, then ask the user for a new test VM.
