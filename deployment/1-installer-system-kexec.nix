{ lib, modulesPath, ... }:
with lib;
{
  imports = [
    ./1-installer-system.nix
    "${modulesPath}/installer/kexec/kexec-boot.nix"
  ];

  # Undo settings of `profiles/installation-device.nix` that allow
  # login with keyboard access
  services.getty.autologinUser = mkForce null;
  users.users.root.initialHashedPassword = mkForce null;
  users.users.nixos.initialHashedPassword = mkForce null;

  # Speed up build
  documentation.nixos.enable = mkOverride 0 false;
  documentation.enable = mkOverride 0 false;

  services.openssh.hostKeys = lib.mkForce [
    {
      path = "/run/keys/ssh-host-key";
      type = "ed25519";
    }
  ];
  boot.kernelParams = [
    # Allows certain forms of remote access, if the hardware is setup right
    "console=ttyS0,115200"
    # Reboot the machine upon fatal boot issues
    "panic=30"
    "boot.panic_on_fail"
  ];
}
