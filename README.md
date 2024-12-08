# hj-dotfiles
my mac flake, template, dev configs 

## Install
1. nix install (recomended determinate.systems)
```bash
curl --proto '=https' --tlsv1.2 -sSf -L https://install.determinate.systems/nix | sh -s -- install
```
2. build
```bash
nix build github:rjcnd105/hj-dotfiles#darwinConfigurations.workspace_hj.system --impure --fallback
```
3. darwin switch
```bash
./result/sw/bin/darwin-rebuild switch --flake .#workspace_hj
```

## System
use catppuccin theme

### Support
- aarch46-darwin

### Preview
![CleanShot 2024-12-08 at 17 18 06@2x](https://github.com/user-attachments/assets/0cc24de1-5116-4f6a-bf4a-1598fa92e647)


### Features

#### Shell
- [rio](https://github.com/raphamorim/rio)<br/>
gui
- [nushell](https://github.com/nushell/nushell)<br/>
better shell
- [sharship](https://github.com/starship/starship)<br/>
Shell customize, look pretty
- [zellij](https://github.com/zellij-org/zellij)<br/>
shell splitting
- [yazi](https://github.com/sxyazi/yazi)<br/>
Tree-based explorer
- [carapace](https://github.com/carapace-sh/carapace)<br/>
Command argument completion
- [atuin](https://github.com/atuinsh/atuin)<br/>
SQLite database shell history

#### Dev
- git
- gh
- lazygit
- direnv
- docker, docker-compose
- lazydocker
- devenv
- mise

#### Fonts
d2 coding nerd, jetbrains-mono nerd, lilex nerd

#### see also
- System Packages<br/>
https://github.com/rjcnd105/hj-dotfiles/blob/main/systems/workspace/default.nix
- User packages<br/>
https://github.com/rjcnd105/hj-dotfiles/blob/main/homes/workspace/default.nix


## Templates
devenv base.

### phoenix
TODO.

