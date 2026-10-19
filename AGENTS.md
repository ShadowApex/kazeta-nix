# AGENTS.md

Rules for working in this repository.

## Shape of the flake

- `nixosModules.default` is the console configuration; `nixosModules.installer` is
  the live image. Host configs import `default` and add only machine-specific
  settings (bootloader, hardware-configuration, `system.stateVersion`).
- Custom packages live in `pkgs/by-name/<first-two-letters>/<name>/package.nix` and
  are exposed through `packages."x86_64-linux"`.
- Modules reach flake packages through the `kazetaPkgs` specialArg
- Service modules define `services.kazeta.<name>` options with `lib.mkEnableOption`
  and `lib.mkPackageOption`, and put everything behind `config = lib.mkIf cfg.enable`.

## Formatting

- Every `.nix` file is formatted with `nixfmt` (`make test-format`).
- Keep lines under 80 characters, including YAML and Markdown.
- Markdown fenced blocks need a language tag.

## Comments

- Basic doc comments are fine; comments that restate the code are not.
- Reserve explanatory comments for complex or non-intuitive parts, and keep them
  terse.
- Do not comment a plain value to say what it is, narrate a change, or restate
  what the reader already sees.

## Review

- Re-read a change after making it and look for what could be simpler.
- Prefer the smaller expression: drop indirection, merge duplicated blocks, and
  delete what the change made unnecessary.
- Simplify only what the change touches; do not rewrite unrelated code.

## Verification

Before calling work done:

```bash
nix flake check
make test                        # host-template system toplevel build
nix build .#kazeta .#kazeta-session .#kazeta-mount .#kazeta-runtimes
make test-format
```

Package builds must not depend on network access at build time beyond the pinned
`fetchFromGitHub` source, and every pinned rev needs a matching hash.

## Runtime facts worth knowing

- The console user is `gamer` with no password; autologin and polkit actions depend
  on that. Changing it is a policy decision, not a bug fix.
- Cart mounts go through polkit, so `security.polkit.enable` must stay on.
- Overlay mounts use `metacopy=on` and `xino=off`; games memory-map files and break
  with the default overlay settings.
- 32-bit graphics stacks must stay enabled — most of the catalog is 32-bit.
