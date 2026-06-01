# NovaSector 开发 shell：覆盖 DM 构建、TGUI 前端、以及全量汉化 (i18n) 工具链所需的一切。
#
#   nix develop
#
# 之后 `tools/build/build.sh`、`bun run tgui:*`、以及 `cargo`（用于 tools/i18n 抽取工具）
# 均可直接使用；DreamMaker / DreamDaemon 也在 PATH 上。
{
  mkShell,
  rust-bin,
  bun,
  nodejs_22,
  python311,
  git,
  pkg-config,
  openssl,
  unzip,
  curl,
  byond,
}:

let
  # 建 tools/i18n 抽取工具，并可选地从源码编译 rust_g / dreamluau。
  rust = rust-bin.stable.latest.default.override {
    extensions = [
      "rust-src"
      "clippy"
      "rustfmt"
    ];
  };
in
mkShell {
  packages = [
    rust
    bun
    nodejs_22
    python311
    git
    pkg-config
    openssl
    unzip
    curl
    byond
  ];

  # tools/build/lib/byond.ts 在 Linux 上回退到 PATH 上的裸命令即可；这里再显式指一份
  # DM_EXE 作为兜底，避免命名版本文件干扰。
  DM_EXE = "${byond}/bin/DreamMaker";
  BYOND_SYSTEM = byond.passthru.home;

  shellHook = ''
    echo "NovaSector dev shell — DM/TGUI + i18n 工具链已就绪"
    echo "  DreamMaker : $(command -v DreamMaker || echo '未找到')"
    echo "  bun        : $(bun --version 2>/dev/null || echo '未找到')"
    echo "  cargo      : $(cargo --version 2>/dev/null || echo '未找到')"
  '';
}
