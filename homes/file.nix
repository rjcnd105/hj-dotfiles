{
  config,
  lib,
  pkgs,
  myOptions,
  ...
}:
let
  # Nix path — store로 복사되어 pure evaluation에서 builtins.readDir 가능
  storeBasePath = ../files + "/${myOptions.filesHost}";
  # String path — 실제 파일시스템 경로, mkOutOfStoreSymlink 대상 (GitOps 호스트는 null)
  outOfStoreBasePath =
    if myOptions.absoluteProjectPath == null then
      null
    else
      myOptions.absoluteProjectPath + "/files/${myOptions.filesHost}";

  mkOutOfStoreLinkTree =
    {
      storeScanPath,
      outOfStoreLinkPath,
      relPath ? null,
    }:
    let
      currentScanPath = if relPath == null then storeScanPath else storeScanPath + "/${relPath}";
    in
    lib.foldlAttrs (
      acc: entryName: entryType:
      let
        childPath = if relPath == null then entryName else "${relPath}/${entryName}";
        scanEntry = storeScanPath + "/${childPath}";
        linkTarget = "${outOfStoreLinkPath}/${childPath}";
        isWholeDirLink = entryType == "directory" && builtins.pathExists (scanEntry + "/.manual-link");
      in
      if entryType == "symlink" then
        acc
      else if isWholeDirLink then
        acc
        // {
          "${childPath}" = {
            source = config.lib.file.mkOutOfStoreSymlink linkTarget;
            # 충돌 검사만 건너뜀. 실제 디렉토리는 backupFileExtension이 옮긴 뒤 링크로 대체
            force = true;
          };
        }
      else if entryType == "directory" then
        acc
        // mkOutOfStoreLinkTree {
          inherit storeScanPath outOfStoreLinkPath;
          relPath = childPath;
        }
      else
        acc
        // {
          "${childPath}" = {
            source = config.lib.file.mkOutOfStoreSymlink linkTarget;
            force = true;
          };
        }
    ) { } (builtins.readDir currentScanPath);

  # 로그인 직후 macOS가 Ghostty를 다시 열 때 암호화된 Nix Store 볼륨은 아직 마운트 전일 수 있다.
  # home.file 링크는 /nix/store를 거치므로 그 순간 끊겨 Ghostty가 설정 없이 기본 셸(zsh)로 뜬다.
  # Ghostty가 읽는 설정과 command wrapper만 store를 거치지 않고 repo 파일을 직접 가리키게 한다.
  ghosttyDirectLinks =
    lib.optionals
      (
        pkgs.stdenv.hostPlatform.isDarwin
        && outOfStoreBasePath != null
        && builtins.pathExists (storeBasePath + "/.config/ghostty/config.ghostty")
      )
      [
        ".config/ghostty/config.ghostty"
        ".config/ghostty/ghostty-nix-env.sh"
      ];

  # GitOps 호스트(projectPath == null)는 /etc/nixos 체크아웃 대신 store 링크를 쓴다.
  # Claude/Codex가 런타임에 덮어쓰는 settings.json·config.toml은 읽기 전용 링크에서 뺀다.
  gitopsStorePaths = [
    ".bashrc"
    ".config/git/.gitignore_global"
    ".config/helix/config.toml"
    ".config/jj/config.toml"
    ".config/lazygit/config.yml"
    ".config/fish/user-functions.fish"
    ".claude/agents"
    ".claude/hooks"
    ".claude/rules"
    ".claude/skills"
    ".agents/pstack-models.md"
    ".agents/skills"
    ".codex/AGENTS.md"
  ];

  mkGitopsStoreFiles = builtins.listToAttrs (
    map (relPath: {
      name = relPath;
      value = {
        source = storeBasePath + "/${relPath}";
        force = true;
      };
    }) (builtins.filter (relPath: builtins.pathExists (storeBasePath + "/${relPath}")) gitopsStorePaths)
  );
in
{
  home.preferXdgDirectories = true;
  xdg.enable = true;

  # .skillshare/는 files/workspace를 루트로 쓰는 skillshare 프로젝트다. ~/에 링크하면
  # ~에서 실행한 skillshare가 ~를 두 번째 프로젝트로 잡는다.
  # .pi/는 skillshare가 쓰는 Pi project 출력이다. homes/workspace/pi.nix가
  # ~/.pi/agent/로 연결하므로 ~/.pi/에 프로젝트 설정으로 다시 링크하지 않는다.
  home.file =
    if outOfStoreBasePath == null then
      mkGitopsStoreFiles
    else
      lib.filterAttrs
        (
          name: _:
          !lib.hasPrefix ".skillshare/" name
          && !lib.hasPrefix ".pi/" name
          && !lib.hasPrefix ".config/pi/" name
          && name != ".gitignore"
        )
        (
          removeAttrs (mkOutOfStoreLinkTree {
            storeScanPath = storeBasePath;
            outOfStoreLinkPath = outOfStoreBasePath;
          }) ghosttyDirectLinks
        );

  home.activation.linkGhosttyDirect = lib.mkIf (ghosttyDirectLinks != [ ]) (
    lib.hm.dag.entryAfter [ "linkGeneration" ] (
      lib.concatMapStrings (
        relPath:
        let
          targetPath = "${config.home.homeDirectory}/${relPath}";
        in
        ''
          run mkdir -p ${lib.escapeShellArg (dirOf targetPath)}
          run ln -sfn ${lib.escapeShellArg "${outOfStoreBasePath}/${relPath}"} ${lib.escapeShellArg targetPath}
        ''
      ) ghosttyDirectLinks
    )
  );
}
