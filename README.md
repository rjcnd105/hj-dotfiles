# hj-dotfiles

snowfall dir sturcture

```
src/
│ The Snowfall root defaults to "src", but can be changed by setting "snowfall.root".
│ This is useful if you want to add a flake to a project, but don't want to clutter the
│ root of the repository with directories.
│
│ Your Nix flake.
├─ flake.nix
│
│ An optional custom library.
├─ lib/
│  │
│  │ A Nix function called with `inputs`, `snowfall-inputs`, and `lib`.
│  │ The function should return an attribute set to merge with `lib`.
│  ├─ default.nix
│  │
│  │ Any (nestable) directory name.
│  └─ **/
│     │
│     │ A Nix function called with `inputs`, `snowfall-inputs`, and `lib`.
│     │ The function should return an attribute set to merge with `lib`.
│     └─ default.nix
│
│ An optional set of packages to export.
├─ packages/
│  │
│  │ Any (nestable) directory name. The name of the directory will be the
│  │ name of the package.
│  └─ **/
│     │
│     │ A Nix package to be instantiated with `callPackage`. This file
│     │ should contain a function that takes an attribute set of packages
│     │ and *required* `lib` and returns a derivation.
│     └─ default.nix
│
│
├─ modules/ (optional modules)
│  │
│  │ A directory named after the `platform` type that will be used for modules within.
│  │
│  │ Supported platforms are:
│  │ - nixos
│  │ - darwin
│  │ - home
│  └─ <platform>/
│     │
│     │ Any (nestable) directory name. The name of the directory will be the
│     │ name of the module.
│     └─ **/
│        │
│        │ A NixOS module.
│        └─ default.nix
│
├─ overlays/ (optional overlays)
│  │
│  │ Any (nestable) directory name.
│  └─ **/
│     │
│     │ A custom overlay. This file should contain a function that takes three arguments:
│     │   - An attribute set of your flake's inputs and a `channels` attribute containing
│     │     all of your available channels (eg. nixpkgs, unstable).
│     │   - The final set of `pkgs`.
│     │   - The previous set of `pkgs`.
│     │
│     │ This function should return an attribute set to merge onto `pkgs`.
│     └─ default.nix
│
├─ systems/ (optional system configurations)
│  │
│  │ A directory named after the `system` type that will be used for all machines within.
│  │
│  │ The architecture is any supported architecture of NixPkgs, for example:
│  │  - x86_64
│  │  - aarch64
│  │  - i686
│  │
│  │ The format is any supported NixPkgs format *or* a format provided by either nix-darwin
│  │ or nixos-generators. However, in order to build systems with nix-darwin or nixos-generators,
│  │ you must add `darwin` and `nixos-generators` inputs to your flake respectively. Here
│  │ are some example formats:
│  │  - linux
│  │  - darwin
│  │  - iso
│  │  - install-iso
│  │  - do
│  │  - vmware
│  │
│  │ With the architecture and format together (joined by a hyphen), you get the name of the
│  │ directory for the system type.
│  └─ <architecture>-<format>/
│     │
│     │ A directory that contains a single system's configuration. The directory name
│     │ will be the name of the system.
│     └─ <system-name>/
│        │
│        │ A NixOS module for your system's configuration.
│        └─ default.nix
│
├─ homes/ (optional homes configurations)
│  │
│  │ A directory named after the `home` type that will be used for all homes within.
│  │
│  │ The architecture is any supported architecture of NixPkgs, for example:
│  │  - x86_64
│  │  - aarch64
│  │  - i686
│  │
│  │ The format is any supported NixPkgs format *or* a format provided by either nix-darwin
│  │ or nixos-generators. However, in order to build systems with nix-darwin or nixos-generators,
│  │ you must add `darwin` and `nixos-generators` inputs to your flake respectively. Here
│  │ are some example formats:
│  │  - linux
│  │  - darwin
│  │  - iso
│  │  - install-iso
│  │  - do
│  │  - vmware
│  │
│  │ With the architecture and format together (joined by a hyphen), you get the name of the
│  │ directory for the home type.
│  └─ <architecture>-<format>/
│     │
│     │ A directory that contains a single home's configuration. The directory name
│     │ will be the name of the home.
│     └─ <home-name>/
│        │
│        │ A NixOS module for your home's configuration.
│        └─ default.nix
```
