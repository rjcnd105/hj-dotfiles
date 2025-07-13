# hj-dotfiles
My mac flake, template, dev configs

## Install
1. nix install (recomended determinate.systems)
```bash
curl --proto '=https' --tlsv1.2 -sSf -L https://install.determinate.systems/nix | sh -s -- install
```

2. [mise](https://mise.jdx.dev/installing-mise.html) install
2. build
```bash
nix build github:rjcnd105/hj-dotfiles#darwinConfigurations.workspace_hj.system --impure --fallback
```
3. darwin switch
```bash
./result/sw/bin/darwin-rebuild switch --flake .#workspace_hj
```

## System
Uses catppuccin theme

### Support
- aarch46-darwin

### Preview
![CleanShot 2024-12-08 at 18 46 53@2x](https://github.com/user-attachments/assets/fb76c014-0b20-42bd-8401-37af9287f856)


### Features

#### Shell
- [alacritty](https://github.com/alacritty/alacritty)<br/>
gui
- [fish](https://github.com/fish-shell/fish-shell)<br/>
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

[https://github.com/rjcnd105/hj-dotfiles/tree/main/templates/phoenix](https://github.com/rjcnd105/hj-dotfiles/tree/main/templates/phoenix)
