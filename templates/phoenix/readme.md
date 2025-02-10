# my phoenix template

### Required
- [nix](https://determinate.systems/posts/determinate-nix-installer/)
- [direnv](https://direnv.net/docs/installation.html)
- [mise](https://mise.jdx.dev/getting-started.html)


### Use template
```sh
nix flake new --template github:rjcnd105/hj-dotfiles#phoenix ./my-app
cd my-app
direnv allow .
mise install
```

### Commands
https://github.com/rjcnd105/hj-dotfiles/blob/main/templates/phoenix/justfile
