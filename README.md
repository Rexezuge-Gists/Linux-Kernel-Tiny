# KernelSlim

KernelSlim is a reproducible Linux kernel slimming project for ARM64 cloud virtual machines. It starts from the Ubuntu Azure ARM64 kernel configuration, migrates it to upstream Linux `6.18.32` longterm, and builds Debian kernel packages that preserve practical VM bootability and container support.

The current best tested kernel is:

```text
6.18.32-kernelslim-aggressive
```

It boots on an Azure ARM64 VM and passes real Docker and Debian LXC container launch tests.

## Goals

- Build a minimal practical ARM64 VM kernel for KVM/QEMU, Azure, Google Cloud, AWS, and virtio-based environments.
- Preserve Docker support: `overlayfs`, cgroup v2, namespaces, seccomp, bridge networking, veth, and netfilter/NAT.
- Preserve LXC support with real Debian ARM64 containers.
- Keep every meaningful command, config stage, build, checksum, and test result reproducible under `logs/`.

## Tested Kernels

| Kernel | Package Version | Local Version | Image Package Size | Status |
| --- | --- | --- | --- | --- |
| Conservative Azure builtins | `6.18.32-kernelslim2` | `-kernelslim-conservative-azure` | `102M` | Boots, Docker passes, LXC passes |
| Balanced | `6.18.32-kernelslim3` | `-kernelslim-balanced` | `69M` | Boots, Docker passes, LXC passes |
| Aggressive | `6.18.32-kernelslim4` | `-kernelslim-aggressive` | `59M` | Boots, Docker passes, LXC passes |

The first conservative package without Azure/Hyper-V storage and network built into the kernel did not return on SSH after reboot. The tested conservative baseline is therefore `04-conservative-azure-builtins-6.18.32.config`.

## Repository Contents

```text
.
├── AGENTS.md                  # Detailed operating guide for future agents
├── README.md                  # Project overview
├── configs/                   # Numbered kernel config stages and config diffs
├── logs/                      # Reproducibility logs and summaries
├── scripts/                   # Logging and measurement scripts
├── artifacts/                 # Local release package output, ignored by git
└── sources/                   # Downloaded/extracted upstream source, ignored by git
```

Large generated files are intentionally not tracked. Publish `.deb` packages as release assets instead of committing them to git.

## Source Kernel

```text
Linux 6.18.32 longterm
https://cdn.kernel.org/pub/linux/kernel/v6.x/linux-6.18.32.tar.xz
```

Recorded tarball checksum:

```text
067dadd445578284ea6158f312f7970d8940fed3e094dbe49cff66d188d3bda4  sources/linux-6.18.32.tar.xz
```

## Build Dependencies

Ubuntu 24.04 ARM64 packages used for this run:

```sh
sudo apt-get update
sudo apt-get install -y \
  build-essential bc bison flex libssl-dev libelf-dev libdw-dev dwarves \
  fakeroot rsync openssh-client libncurses-dev debhelper xz-utils zstd \
  kmod cpio
```

## Reproducible Workflow

Use `scripts/run_logged.sh` for substantive commands:

```sh
./scripts/run_logged.sh logs/<log-name>.log '<description>' <command> [args...]
```

When running from the kernel source tree, use absolute paths:

```sh
/home/azureuser/KernelSlim/scripts/run_logged.sh \
  /home/azureuser/KernelSlim/logs/<log-name>.log \
  '<description>' \
  make -j8 bindeb-pkg KDEB_PKGVERSION=<version>
```

## Config Stages

- `configs/00-current-host-6.17.0-1013-azure.config`: copied from the build host.
- `configs/01-olddefconfig-6.18.32.config`: migrated to Linux `6.18.32` with `make olddefconfig`.
- `configs/02-conservative-vm-containers-6.18.32.config`: conservative VM/container policy.
- `configs/03-conservative-no-debug-6.18.32.config`: debug info disabled.
- `configs/04-conservative-azure-builtins-6.18.32.config`: first tested-good config.
- `configs/05-balanced-vm-containers-6.18.32.config`: removes obvious non-VM subsystems.
- `configs/06-aggressive-vm-containers-6.18.32.config`: smallest currently tested config.

Config line count movement:

```text
14432 configs/00-current-host-6.17.0-1013-azure.config
14521 configs/01-olddefconfig-6.18.32.config
14503 configs/04-conservative-azure-builtins-6.18.32.config
11781 configs/05-balanced-vm-containers-6.18.32.config
 9925 configs/06-aggressive-vm-containers-6.18.32.config
```

## Build Commands

Run from `sources/linux-6.18.32` after placing the target config at `.config`:

```sh
make -j8 bindeb-pkg KDEB_PKGVERSION=6.18.32-kernelslim2
make -j8 bindeb-pkg KDEB_PKGVERSION=6.18.32-kernelslim3
make -j8 bindeb-pkg KDEB_PKGVERSION=6.18.32-kernelslim4
```

Expected package outputs are copied into `artifacts/` locally, then published through releases.

## Runtime Validation

Every accepted kernel must pass all checks on a disposable ARM64 VM:

1. Boot and return on SSH.
2. Run `scripts/kernel-memory-usage.sh`.
3. Start Docker and run `sudo docker run --rm hello-world`.
4. Create and launch a Debian Bookworm ARM64 LXC container.

Docker success signal:

```text
Hello from Docker!
```

LXC success signal:

```text
PRETTY_NAME="Debian GNU/Linux 12 (bookworm)"
```

## Memory Measurements

Measured with `scripts/kernel-memory-usage.sh`:

```text
Original Ubuntu Azure kernel on fresh VM: 110.77 MB
Conservative Azure-builtins:             199.73 MB
Balanced:                                107.40 MB
Aggressive:                              102.11 MB
```

Memory values are workload-sensitive. The original value was collected on a fresh VM, while custom kernels were measured on the container test VM after Docker/LXC setup.

## Release Assets

Recommended release assets:

- `linux-image-6.18.32-kernelslim-aggressive_6.18.32-kernelslim4_arm64.deb`
- `linux-headers-6.18.32-kernelslim-aggressive_6.18.32-kernelslim4_arm64.deb`
- `SHA256SUMS`
- Optional fallback packages for balanced and conservative Azure-builtins.

Important image checksums from the completed run:

```text
3b8d1c307f6cbf6cf8ddc77c182b17fd7bd44cd8828756df2616c356d1aabd0d  linux-image-6.18.32-kernelslim-conservative-azure_6.18.32-kernelslim2_arm64.deb
796094849bb556739bac1c0955aed980e26df0d3fb5c7fe606ea4f5b7fb74d8c  linux-image-6.18.32-kernelslim-balanced_6.18.32-kernelslim3_arm64.deb
99e3810e39799c144edf992d1be8b00ebe1fcc9f0096a874e5ccd251cf9578b5  linux-image-6.18.32-kernelslim-aggressive_6.18.32-kernelslim4_arm64.deb
```

## Future Work

- Test the aggressive config on AWS, GCP, and KVM ARM64.
- Compare memory on equal fresh VMs to reduce workload bias.
- Investigate remaining `CONFIG_I2C=m` dependencies.
- Trim remaining optional TCP congestion, IPv6 tunnel, IPsec/XFRM, and diagnostic modules after each change passes boot, Docker, and LXC tests.

See `AGENTS.md` for the detailed operating guide and safety rules.
