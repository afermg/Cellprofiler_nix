{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-23.11";
    nixpkgs_master.url = "github:NixOS/nixpkgs/master";
    systems.url = "github:nix-systems/default";
    devenv.url = "github:cachix/devenv";
  };

  nixConfig = {
    extra-trusted-public-keys = "devenv.cachix.org-1:w1cLUi8dv3hnoSPGAuibQv+f9TZLr6cv/Hm9XgU50cw=";
    extra-substituters = "https://devenv.cachix.org";
  };

  outputs = { self, nixpkgs, devenv, systems, ... } @ inputs:
    let
      forEachSystem = nixpkgs.lib.genAttrs (import systems);
    in
    {
      packages = forEachSystem (system: {
        devenv-up = self.devShells.${system}.default.config.procfileScript;
      });

      devShells = forEachSystem
        (system:
          let
            pkgs = import nixpkgs {
              system = system;
              config.allowUnfree = true;
            };

            mpkgs = import inputs.nixpkgs_master {
              system = system;
              config.allowUnfree = true;
            };
          in
          {
            default = devenv.lib.mkShell {
              inherit inputs pkgs;
              modules = [
                {
                  env.NIX_LD = nixpkgs.lib.fileContents "${pkgs.stdenv.cc}/nix-support/dynamic-linker";
                  env.NIX_LD_LIBRARY_PATH = nixpkgs.lib.makeLibraryPath [
                    # Add needed packages here
                    pkgs.stdenv.cc.cc
                    pkgs.libGL
                    # pkgs.python39Packages.numpy
                  ];
                  # https://devenv.sh/reference/options/
                  packages = with pkgs; [
                    gcc
                    micromamba
                    poetry
                    libmysqlclient
                    jdk
                  ];
                  enterShell = ''
                    export LD_LIBRARY_PATH=$NIX_LD_LIBRARY_PATH
                    # export CC="gcc"
                    eval "$(micromamba shell hook -s bash)"
                    if [ ! -d ".venv/envs/cp" ]; then
                       micromamba create -r .venv -n cp -y -c conda-forge python=3.9 numpy python.app scikit-learn==0.24.2 scikit-image==0.18.3 h5py==3.6.0 cython jpype1
                    fi
                    micromamba activate .venv/envs/cp/

                    if [ ! -d "CellProfiler" ]; then
                       git clone git@github.com:CellProfiler/CellProfiler.git
                    fi

                    cd CellProfiler
                    git checkout ea6a2e6d001b10983301c10994e319abef41e618
                    cd ..

                    if ! hash pythonw; then
                      pip install -e CellProfiler/src/subpackages/library/
                      pip install -e CellProfiler/src/subpackages/core/
                      pip install -e CellProfiler/src/frontend/
                    fi
                  '';
                }
              ];
            };
          });
    };
}

  # Run with pythonw -m cellprofiler
