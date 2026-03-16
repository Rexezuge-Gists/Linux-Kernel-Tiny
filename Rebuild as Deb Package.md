## Rebuild as Deb Package

#### Install Dependencies

```bash
sudo apt install -y dpkg-dev git debhelper-compat rsync libdw-dev

## On Debian Bookworm, debhelper defaults to a later compatibility level (e.g., 13). To match the kernel packaging expectations, install debhelper explicitly and create the required compat file:
echo "12" | sudo tee debian/compat
```

#### Initalize Git Repo (Required)

```bash
git config --global user.email "you@example.com"
git config --global user.name "Your Name"

git init
git add .
git commit -m "Initial commit"
```

#### Build Kernel

```bash
make -j$(nproc) deb-pkg LOCALVERSION=-tiny
```

### Installing

```bash
sudo dpkg -i linux-image-6.12.41-tiny-g9bece1ba9fee_*.deb
sudo dpkg -i linux-libc-dev_*.deb  # Optional
```

- Installing the kernel image is mandatory.
- Installing the linux-libc-dev is optional, useful if you're compiling programs that depend on the new kernel headers.

#### Regenerate (if not done autotomatically when installed deb package)

```bash
sudo update-grub
sudo update-initramfs -c -k 6.12.41-tiny-g9bece1ba9fee
```
