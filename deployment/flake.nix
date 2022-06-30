{
  inputs.nix-bitcoin.url = "github:fort-nix/nix-bitcoin/release";
  inputs.nixpkgs.follows = "nix-bitcoin/nixpkgs";
  inputs.flake-utils.follows = "nix-bitcoin/flake-utils";

  # The installer system requires NixOS 22.05 for automatic initrd-secrets support
  # https://github.com/NixOS/nixpkgs/pull/176796
  inputs.nixpkgs-kexec.url = "github:erikarvstedt/nixpkgs/improve-netboot-initrd";

  outputs = { self, nixpkgs, nixpkgs-kexec, flake-utils, ... }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = nixpkgs.legacyPackages.${system};

        installerSystem = nixpkgs-kexec.lib.nixosSystem {
          inherit system;
          modules = [ ./1-installer-system-kexec.nix ];
        };

        mkBenchmarkSystem = description: config:
          (nixpkgs-kexec.lib.nixosSystem {
            inherit system;
            modules = [
              ./benchmark-system.nix
              config
            ];
          }).config.system.build.toplevel // {
            inherit description;
          };
      in {
        packages = {

          installerSystemVM = (nixpkgs.lib.nixosSystem {
            inherit system;
            modules = [
              ({ lib, modulesPath, ...}: {
                imports = [
                  ./1-installer-system.nix
                  "${modulesPath}/virtualisation/qemu-vm.nix"
                ];
                users.users.root.password = "a";
                services.getty.autologinUser = lib.mkForce "root";
                virtualisation.graphics = false;
                environment.etc.base-system.source = self.packages.${system}.baseSystem;
              })
            ];
          }).config.system.build.vm;

          installerSystemKexec = installerSystem.config.system.build.kexecBoot;

          installerSystem = installerSystem.config.system.build.toplevel;

          baseSystem = (nixpkgs.lib.nixosSystem {
            inherit system;
            modules = [ ../base.nix ];
          }).config.system.build.toplevel;
        }
        // (with nixpkgs-kexec.lib; {
          benchmark1 = mkBenchmarkSystem "postgresql 11, shared_buffers: default (128 MiB) [the current setup on nixbitcoin.org]" {
            system.stateVersion = mkForce "20.09";
          };
          benchmark2 = mkBenchmarkSystem "postgresql 11, shared_buffers: 8 GiB" {
            services.postgresql.settings.shared_buffers = "8GB";
            system.stateVersion = mkForce "20.09";
          };
          benchmark3 = mkBenchmarkSystem "postgresql 14, shared_buffers: 8 GiB" {
            services.postgresql.settings.shared_buffers = "8GB";
            system.stateVersion = mkForce "22.05";
          };
        });
      });
}
