# BYOND 在 NixOS 上的封装。
#
# BYOND 是 Dantom 发布的闭源预编译 Linux 二进制，且为 **32 位 i386**
# （解释器 /lib/ld-linux.so.2），无法直接在 NixOS 上运行。这里：
#   1. 用 fetchzip 拉取与 dependencies.sh 对齐的版本 (516.1659)；
#   2. 用 i686 包集 + autoPatchelfHook 把二进制的解释器与 RPATH 重写到 Nix 的 32 位库
#      （比 buildFHSEnv 的 multiarch 更确定，且产出可直接运行的真实二进制）；
#   3. 暴露 DreamMaker / DreamDaemon 到 PATH —— tools/build/lib/byond.ts 在 Linux 上会
#      回退到 PATH 上的裸 `DreamMaker`/`DreamDaemon`（见其 L56/L236）。
{
  lib,
  pkgsi686Linux,
  autoPatchelfHook,
  fetchzip,
  writeShellScriptBin,
  symlinkJoin,
}:

let
  # 与 dependencies.sh 的 BYOND_MAJOR / BYOND_MINOR 保持一致。
  major = "516";
  minor = "1659";
  version = "${major}.${minor}";

  # 解包 + autoPatchelf 后的 BYOND 树（byond/bin/{DreamDaemon,DreamMaker,*.so,...}）。
  # autoPatchelf 会自动把同一输出内的 libbyond.so / libext.so 加入依赖二进制的 RPATH。
  byondUnpacked = pkgsi686Linux.stdenv.mkDerivation {
    pname = "byond";
    inherit version;

    src = fetchzip {
      url = "https://www.byond.com/download/build/${major}/${version}_byond_linux.zip";
      # 516.1659_byond_linux.zip 解包后（stripRoot=false）的 NAR 哈希。
      hash = "sha256-eclavAUYr3y/A9Uz0l9NECsS7exmOLVVLKc8XSlbeDA=";
      stripRoot = false;
    };

    nativeBuildInputs = [ autoPatchelfHook ];
    buildInputs = with pkgsi686Linux; [
      stdenv.cc.cc.lib # libstdc++ / libgcc_s
      zlib
      curl
      openssl
      libpng
    ];

    dontConfigure = true;
    dontBuild = true;

    installPhase = ''
      runHook preInstall
      mkdir -p "$out/opt"
      cp -r byond "$out/opt/byond"
      runHook postInstall
    '';

    meta = {
      description = "BYOND 引擎（DreamMaker / DreamDaemon），32 位 i386";
      homepage = "https://www.byond.com/";
      license = lib.licenses.unfree;
      # 二进制为 i386，故经由 pkgsi686Linux 构建（hostPlatform = i686-linux）。
      platforms = [ "i686-linux" "x86_64-linux" ];
    };
  };

  mkTool =
    name:
    writeShellScriptBin name ''
      export BYOND_SYSTEM="${byondUnpacked}/opt/byond"
      export LD_LIBRARY_PATH="$BYOND_SYSTEM/bin''${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
      exec "$BYOND_SYSTEM/bin/${name}" "$@"
    '';
in
symlinkJoin {
  name = "byond-${version}";
  paths = [
    (mkTool "DreamMaker")
    (mkTool "DreamDaemon")
  ];
  passthru = {
    inherit version byondUnpacked;
    home = "${byondUnpacked}/opt/byond";
  };
}
