{
  # Deps
  lib,
  stdenv,
  makeWrapper,
  retroarch-bare,
  unstableGitUpdater,
  zlib,
  # Params
  core,
  makefile ? "Makefile.libretro",
  extraBuildInputs ? [ ],
  extraNativeBuildInputs ? [ ],
  ## Location of resulting RetroArch core on $out
  libretroCore ? "/lib/retroarch/cores",
  ## The core filename is derived from the core name
  ## Setting `normalizeCore` to `true` will convert `-` to `_` on the core filename
  normalizeCore ? true,
  ...
}@args:

let
  d2u = if normalizeCore then (lib.replaceStrings [ "-" ] [ "_" ]) else (x: x);
  coreDir = placeholder "out" + libretroCore;
  coreFilename = "${d2u core}_libretro${stdenv.hostPlatform.extensions.sharedLibrary}";
  mainProgram = "retroarch-${core}";
  extraArgs = builtins.removeAttrs args [
    "lib"
    "stdenv"
    "makeWrapper"
    "retroarch-bare"
    "unstableGitUpdater"
    "zlib"

    "core"
    "extraBuildInputs"
    "extraNativeBuildInputs"
    "libretroCore"
    "makefile"
    "normalizeCore"
    "passthru"
    "meta"
  ];
in
stdenv.mkDerivation (
  {
    pname = "libretro-${core}";

    buildInputs = [ zlib ] ++ extraBuildInputs;
    nativeBuildInputs = [ makeWrapper ] ++ extraNativeBuildInputs;

    inherit makefile;

    makeFlags = [
      "platform=${
        {
          linux = "unix";
          darwin = "osx";
          windows = "win";
        }
        .${stdenv.hostPlatform.parsed.kernel.name} or stdenv.hostPlatform.parsed.kernel.name
      }"
      "ARCH=${
        {
          armv7l = "arm";
          armv6l = "arm";
          aarch64 = "arm64";
          i686 = "x86";
        }
        .${stdenv.hostPlatform.parsed.cpu.name} or stdenv.hostPlatform.parsed.cpu.name
      }"
    ] ++ (args.makeFlags or [ ]);

    installPhase = ''
      runHook preInstall

      install -Dt ${coreDir} ${coreFilename}
      makeWrapper ${retroarch-bare}/bin/retroarch $out/bin/${mainProgram} \
        --add-flags "-L ${coreDir}/${coreFilename}"

      runHook postInstall
    '';

    enableParallelBuilding = true;

    passthru = {
      inherit core libretroCore;
      # libretro repos sometimes has a fake tag like "Current", ignore
      # it by setting hardcodeZeroVersion
      updateScript = unstableGitUpdater { hardcodeZeroVersion = true; };
    } // (args.passthru or { });

    meta = {
      inherit mainProgram;
      inherit (retroarch-bare.meta) platforms;
      homepage = "https://www.libretro.com/";
      teams = [ lib.teams.libretro ];
    } // (args.meta or { });
  }
  // extraArgs
)
