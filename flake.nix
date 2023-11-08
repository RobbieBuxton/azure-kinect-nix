{
  description = "A very basic flake";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/23.05";
  };

  outputs = { self, nixpkgs }: 
    let 
      system = "x86_64-linux";
      pkgs = nixpkgs.legacyPackages.${system};

      azure-kinect-sensor-sdk-src = builtins.fetchGit {
        url = "https://github.com/RobbieBuxton/Azure-Kinect-Sensor-SDK/";
        rev = "eb1e6ddca3952774c07a2a5bfcb55e1241968bda";
        submodules = true;
      };  

      libk4a-src = builtins.fetchurl {
        url = https://packages.microsoft.com/ubuntu/18.04/prod/pool/main/libk/libk4a1.4/libk4a1.4_1.4.1_amd64.deb;
        sha256 = "sha256:0ackdiakllmmvlnhpcmj2miix7i2znjyai3a2ck17v8ycj0kzin1";
      }; 

      libk4a-dev-src = builtins.fetchurl {
        url = https://packages.microsoft.com/ubuntu/18.04/prod/pool/main/libk/libk4a1.4-dev/libk4a1.4-dev_1.4.1_amd64.deb;
        sha256 = "sha256:1llw52i6bqgm5a7d32rfvmrmw1cp1javij4vq5sfldmdp6a30c08";
      };   

      libk4a-dev = pkgs.stdenv.mkDerivation {
        pname = "libk4a-dev";
        version = "1.4.1";

        src = ./.;

        nativeBuildInputs = [
          pkgs.dpkg
          pkgs.autoPatchelfHook
        ];

        buildInputs = [
          #Maybe need libs
          pkgs.glfw
          pkgs.xorg.libX11
          pkgs.udev
          pkgs.stdenv.cc.cc.libgcc
          pkgs.stdenv.cc.cc.lib
        ];

        buildPhase = ''
          dpkg -x ${libk4a-src} .
          dpkg -x ${libk4a-dev-src} .
        '';

        installPhase = ''
          mkdir -p $out
          cp -r usr/. $out
        '';
      };

      k4a-tools = pkgs.stdenv.mkDerivation {
        pname = "k4aviewer";
        version = "1.4.1";

        src = azure-kinect-sensor-sdk-src; 

        #Stops cmake killing itself
        dontUseCmakeConfigure = true;
        dontUseCmakeBuildDir = true; 

        ##Move stuff here after happy with functionality
        nativeBuildInputs = with pkgs; [];

        buildInputs = [
          libk4a-dev

          #Try and fix build libs
          pkgs.git
          pkgs.patchelf
          pkgs.gnused

          #needed bibs
          pkgs.cmake
          pkgs.pkg-config
          pkgs.ninja
          pkgs.doxygen
          pkgs.python312
          pkgs.nasm
          pkgs.dpkg

          #Maybe need libs
          pkgs.glfw
          pkgs.xorg.libX11
          pkgs.xorg.libXrandr
          pkgs.xorg.libXinerama
          pkgs.xorg.libXcursor
          pkgs.openssl_legacy
          pkgs.libsoundio
          pkgs.libusb1
          pkgs.libjpeg
          pkgs.libuuid
        ];

        configurePhase = ''
          mkdir -p build/bin 
          cp ${libk4a-dev}/lib/x86_64-linux-gnu/libk4a1.4/libdepthengine.so.2.0 build/bin/
          cd build
          cmake .. -GNinja
        '';

        buildPhase = ''
          ninja
          export BUILD=`pwd`
        '';

        installPhase = ''
          mkdir -p $out/bin
          cp -r bin $out
          mkdir -p $out/include
          cp -r ../include/k4a $out/include/
        '';
      
        #Removes any RPATH refrences to the temp build folder used during the configure and install phase
        fixupPhase = 
        let
          removeRPATH = file: path: "patchelf --set-rpath `patchelf --print-rpath ${file} | sed 's@'${path}'@@'` ${file}";
        in ''
          cd $out/bin
          for f in *; do if [[ "$f" =~ .*\..*  ]]; then : ignore;else ${removeRPATH "$f" "$BUILD/bin:"};fi; done
          ${removeRPATH "libk4arecord.so.1.4.0" "$BUILD/bin:"}
        '';
        };
    in
    {
    packages.${system} = { 
      default = k4a-tools;
      k4a-tools = k4a-tools;
      libk4a-dev = libk4a-dev;
    };
  };
}
