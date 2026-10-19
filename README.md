# kazeta-nix

Kazeta is a game console OS: it boots, logs a single user in automatically, and
starts the launcher under gamescope. Game carts are overlay filesystems mounted
from removable media.

This repository is the Nix flake version of
[kazetaos/kazeta](https://github.com/kazetaos/kazeta), which builds an Arch
Linux image. It is a flake exposing `nixosModules`, `packages`, a host template,
and an ISO configuration.

## Layout

```text
flake.nix                 nixosModules, packages, templates, ISO configuration
modules/kazeta.nix        the console configuration (boot, audio, graphics, identity)
modules/installer.nix     the live image: boot straight into the launcher
modules/services/*.nix    services.kazeta.* options
pkgs/by-name/ka/*         kazeta, kazeta-session, kazeta-mount, kazeta-runtimes
templates/host-*/         example host configuration, one per architecture
Taskfile.yaml             test / build:iso / build:package / update tasks
```

## Boot overview

```text
power on
  └─ systemd-boot / isolinux
      └─ greetd autologins as `gamer` on VT1
          └─ kazeta-session (session scope, gamescope compositor)
              └─ the launcher UI, reading carts from /run/media
```

## Carts

A cart is a directory tree plus an overlay stack. `kazeta-mount` builds it from:

- `.kzp` — the cart payload (squashfs or a plain directory)
- `.kzi` — cart metadata (title, runtime, icon)
- `.kzr` — a runtime image (Wine, Proton, a native runtime, or `none.kzr`)

The overlay is mounted with `metacopy=on` and `xino=off` so writes land in the
writable upper layer without changing inode numbers, which games that memory-map
files depend on. Cart mounts are performed through polkit: the `wheel` group may
run `kazeta-mount` without a password.

## Installing and upgrading

The whole system is one derivation, so updates replace packages wholesale:

```bash
# Install the console from a host flake built on the template
nixos-rebuild switch --flake .#kazeta

# Update everything (packages and the OS) at once
nix flake update
nixos-rebuild switch --flake .

# Boot the live image instead of installing it
make build-iso
```

## Verification

```bash
make test                    # build the host-template system toplevel
make test-format             # nixfmt is clean
nix flake check
```

## Console user

The launcher runs as `gamer` (groups `wheel` and `input`). The account has no
password, which is what makes autologin and passwordless polkit actions work.
Set one with `passwd gamer` if the machine is shared.
