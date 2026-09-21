# Raspberry Pi 5 — LAN setup (second-stage target)

Topology (SSH/scp approach — no netboot, no TFTP):

```text
Shared LAN (192.168.0.0/24)
├── PC  build host + NFS server (`$RPI_SERVER_IP` in env.sh)
└── Pi  SSH target (`$RPI_SSH_HOST` / `$RPI_SSH_USER` in env.local.sh)
```

The Pi boots its kernel from SD (Pi OS already installed). Deployment
is plain SSH: `scp` the built `Image`+DTB onto the SD boot partition,
reboot over `ssh`, verify over `ssh`. There is no dedicated link, no
dnsmasq, and no TFTP.

## One-time setup

1. `cp env.local.example.sh env.local.sh` and set `RPI_SSH_HOST` (Pi's
   LAN IP), `RPI_SSH_USER`, `RPI_SERVER_IP` (this PC). `env.local.sh`
   is gitignored; never commit real hosts/users.
2. Key auth (all scripts use `ssh -o BatchMode=yes`, so a password
   prompt fails the loop):
   `ssh-copy-id "$RPI_SSH_USER@$RPI_SSH_HOST"` once.
3. On the Pi (over SSH):
   - confirm `$RPI_BOOT_DIR` (`/boot/firmware` on Bookworm and newer,
     `/boot` on older).
   - allow passwordless sudo for the deploy step:
     ```bash
     echo "$USER ALL=(ALL) NOPASSWD:ALL" | sudo tee /etc/sudoers.d/010-$USER-nopasswd
     sudo chmod 440 /etc/sudoers.d/010-$USER-nopasswd
     sudo -n true && echo OK
     ```
     (`deploy.sh` copies via `scp` to `/tmp`, then moves into the
     root-owned boot partition with `sudo`; tighten the rule to the
     exact commands later if wanted.)
   - keep a backup of the working Pi OS kernel (`deploy.sh` keeps the
     previous one as `Image.prev` automatically).
4. Kernel filename: stock Pi OS boots `kernel_2712.img`
   (`auto_initramfs=1`), not `Image`. Only after `./rpi5/kexec-trial.sh`
   passes, add `kernel=Image` to the SD `config.txt` (see
   `rpi5/boot/config.txt`) to commit the self-built kernel.
5. NFS root (optional, only when wanted): `./rpi5/setup-host.sh` notes
   (install `nfs-kernel-server`, populate and export `$RPI_NFS_ROOT`
   to `192.168.0.0/24`), then put `rpi5/boot/cmdline.txt`
   (`root=/dev/nfs`, `nfsroot=<PC-IP>:<NFS-root>`) on the SD boot
   partition. Until then the Pi runs its stock Pi OS root; only the
   kernel is swapped.

## Inner loop (trial first — never brick remote access)

```bash
./scripts/build-kernel.sh   # one Image for QEMU and Pi, in out/
./rpi5/kexec-trial.sh       # trial-boot via kexec; SD untouched, any reboot lands on stock
# only after the trial passes:
./rpi5/deploy.sh            # scp Image to Pi boot partition (DTB only with DEPLOY_DTB=1)
./rpi5/reboot.sh            # reboot over SSH
./rpi5/test.sh              # waits for SSH, checks uname vs deployed build, shows KUnit
# or commit path all at once (Image must already be trial-proven):
./rpi5/deploy-and-test.sh
```

`deploy.sh` keeps the previous kernel as `Image.prev` on the Pi for
manual fallback. `test.sh` fails if the booted release does not match
the deployed build, so a stale SD boot is reported as failure.

## Recovery (Pi doesn't come back)

A `kexec-trial.sh` failure never touches the SD: power-cycle boots
stock. A committed bad kernel (`kernel=Image` in `config.txt`) needs
physical access:

1. Power off, pull the SD, mount the small FAT partition on a PC
   (the one with `kernel_2712.img` / `start*.elf` — NOT the ext4 rootfs).
2. In `config.txt`, delete the 2 kernel-lab lines (`kernel=Image`).
   Backup `config.txt.lab-bak` sits next to it.
3. If the DTB was replaced (`DEPLOY_DTB=1`), restore it: copy
   `bcm2712-rpi-5-b.dtb.prev` over `bcm2712-rpi-5-b.dtb`.
4. Reinsert, boot → stock kernel. Leftover `Image` / `Image.prev`
   files are harmless.

Never overwritten by our scripts: `kernel_2712.img`, `kernel8.img`,
`initramfs_2712`, `initramfs8`.

## Configuration

Defaults live in `env.sh`. Machine-specific values go in `env.local.sh`
(gitignored — copy from `env.local.example.sh`). Precedence: exported
environment > `env.local.sh` > built-in default, e.g.
`RPI_SSH_HOST=192.168.0.x ./rpi5/test.sh` still wins over the file.
