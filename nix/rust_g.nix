# rust-g —— SS13 的 Rust 原生扩展库（日志、文件 IO、Aho-Corasick、JSON 等）。
#
# 仓库只带了 Windows 的 rust_g.dll；Linux 服务端需要 32 位 librust_g.so（i686，
# 与 32 位 DreamDaemon 匹配）。这里取 tgstation/rust-g 的预编译 release 并 autoPatchelf
# 到 Nix 的 32 位库（否则在 NixOS 上 dlopen 会因找不到 ld-linux.so.2/libgcc 而失败，
# 表现为 DreamDaemon 启动时狂刷 "libbyond.so: undefined symbol: file_write" 之类，卡住启动）。
#
# 版本与 dependencies.sh 的 RUST_G_VERSION 对齐。
{
  lib,
  pkgsi686Linux,
  autoPatchelfHook,
  fetchurl,
}:

pkgsi686Linux.stdenv.mkDerivation {
  pname = "rust-g";
  version = "4.2.0";

  src = fetchurl {
    url = "https://github.com/tgstation/rust-g/releases/download/4.2.0/librust_g.so";
    hash = "sha256-cswOy82w7xIIMhNIlDH/AaF5Zd+UYZfUrh4m3EYdVYI=";
  };

  dontUnpack = true;

  nativeBuildInputs = [ autoPatchelfHook ];
  buildInputs = with pkgsi686Linux; [
    stdenv.cc.cc.lib # libgcc_s / libstdc++ / 经 glibc 提供 libm/libc/loader
  ];

  installPhase = ''
    runHook preInstall
    mkdir -p "$out/lib"
    cp "$src" "$out/lib/librust_g.so"
    chmod +w "$out/lib/librust_g.so"
    runHook postInstall
  '';

  meta = {
    description = "rust-g：SS13 的 Rust 原生扩展库（i686）";
    homepage = "https://github.com/tgstation/rust-g";
    license = lib.licenses.mit;
    platforms = [ "i686-linux" "x86_64-linux" ];
  };
}
