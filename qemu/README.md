# QEMU — Debian guest (default flow)

The default QEMU target is a Debian cloud guest (arm64). A self-built
kernel is booted on it with `-kernel`; the rootfs stays untouched apart
from normal guest writes to a working copy.

## Image source

Debian Cloud, forky daily, generic arm64 (pinned build):

```text
https://cloud.debian.org/images/cloud/forky/daily/20260920-2607/debian-14-generic-arm64-daily-20260920-2607.qcow2
```

Metadata (package list, digests):

```text
https://cloud.debian.org/images/cloud/forky/daily/20260920-2607/debian-14-generic-arm64-daily-20260920-2607.json
```

Facts about this build (verified 2026-09-20):

* size 437 MiB qcow2 (3 GiB virtual), digest (sha512, base64) matches
  the JSON entry.
* kernel `7.1.13+deb14-arm64`, dracut initramfs, GRUB EFI, cloud-init,
  openssh-server.
* partition layout: `vda1` ext4 root, `vda15` EFI vfat. There is **no**
  `vda2` — `root=/dev/vda2` panics; use `root=/dev/vda1`.

Store it at (outside git; `*.qcow2` is gitignored):

```text
~/vm/debian/debian-14-generic-arm64-daily-20260920-2607.qcow2
```

## Run

```bash
./qemu/run.sh                       # boots $KERNEL_OUT/.../Image
KERNEL_IMAGE=/path/to/Image ./qemu/run.sh
```

First run copies the pristine image to `~/vm/debian/debian-qemu.qcow2`
and boots the copy. Quit with `Ctrl-A`, then `X`.

Override the disk locations if needed:

```bash
DEBIAN_QCOW2_BASE=... DEBIAN_QCOW2_WORK=... ./qemu/run.sh
```

## Booting a self-built kernel

`run.sh` passes the kernel directly (`-kernel`), no initrd. This works
if the kernel has the virt essentials builtin:

```text
VIRTIO_PCI, VIRTIO_BLK, VIRTIO_NET, EXT4_FS, DEVTMPFS, SERIAL_AMBA_PL011
```

Plain arm64 `defconfig` satisfies all of them (verified). Append line is
`root=/dev/vda1 console=ttyAMA0` (override via `QEMU_APPEND`).

Verified matrix:

| kernel | result |
|---|---|
| Debian `7.1.13+deb14-arm64` (image's own, via UEFI) | boots to login |
| self-built `7.3.0-rc3` defconfig (`-kernel`, no initrd) | boots to login |

## Known guest quirks (not kernel failures)

* First boot takes a few minutes (cloud-init waits on metadata source).
* `ssh.service` fails on first boot (no host keys without a seed).
  Serial console (`ttyAMA0`) is the way to observe boot; login needs a
  nocloud seed ISO (future work: `genisoimage` + user-data with SSH key).

## Legacy flow

`qemu/run-initramfs.sh` + `qemu/build-initramfs.sh` keep the old minimal
BusyBox initramfs flow (KUnit smoke tests). Debian is the default.
