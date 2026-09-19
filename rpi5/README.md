# Raspberry Pi 5 — LAN setup (second-stage target)

Topology:

```text
Shared LAN (192.168.0.0/24)
├── PC  192.168.0.27  (build host + NFS server, fixed IP)
└── Pi  LAN DHCP       (SSH via raspberrypi.local, no fixed IP needed)
```

The Pi boots its kernel from SD (Pi OS already installed) and mounts
rootfs over NFS from this PC. There is no dedicated link, no dnsmasq,
and no TFTP.

## One-time setup

1. On the PC: `./rpi5/setup-host.sh` notes (install `nfs-kernel-server`,
   populate and export `$RPI_NFS_ROOT` to `192.168.0.0/24`).
2. On the Pi (over SSH, `pi@raspberrypi.local`):
   - confirm `$RPI_BOOT_DIR` (`/boot/firmware` on Bookworm, `/boot` on older).
   - keep a backup of the working Pi OS kernel.
3. When NFS-root testing is wanted, put `rpi5/boot/cmdline.txt`
   (`root=/dev/nfs`, `nfsroot=<PC-IP>:/srv/nfs/rpi5-root`) and
   `rpi5/boot/config.txt` (`kernel=Image`) on the SD boot partition.
   Until then the Pi runs its stock Pi OS root; only the kernel is swapped.

## Inner loop

```bash
./scripts/build-kernel.sh   # one Image for QEMU and Pi, in out/
./rpi5/deploy.sh            # scp Image+DTB to Pi /boot, records expected version
./rpi5/reboot.sh            # reboot over SSH
./rpi5/test.sh              # waits for SSH, checks uname vs deployed build, shows KUnit
# or all at once:
./rpi5/deploy-and-test.sh
```

`deploy.sh` keeps the previous kernel as `Image.prev` on the Pi for
manual fallback. `test.sh` fails if the booted release does not match
the deployed build, so a stale SD boot is reported as failure.

## Configuration

All in `env.sh`: `RPI_SERVER_IP` (default `192.168.0.27`),
`RPI_SSH_HOST` (default `raspberrypi.local`), `RPI_SSH_USER`,
`RPI_NFS_ROOT`, `RPI_BOOT_DIR`. Override via environment, e.g.
`RPI_SSH_HOST=192.168.0.x ./rpi5/test.sh` if mDNS is unavailable.
