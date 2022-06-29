{ config, lib, pkgs, ... }: let
  baseSystem = pkgs.nixos ../base.nix;
in {
  users.users.root.password = "a";
  services.getty.autologinUser = lib.mkForce "root";

  # Use same the hostid as the final system so that the zfs pool
  # can be automatically imported
  networking.hostId = baseSystem.config.networking.hostId;
  boot.supportedFilesystems = [ "zfs" ];

  environment.systemPackages = with pkgs; [
    gptfdisk
    zfs
  ];

  services.openssh = {
    enable = true;
    passwordAuthentication = false;
  };
  users.users.root.openssh.authorizedKeys.keys =
    baseSystem.config.users.users.root.openssh.authorizedKeys.keys;

  system.stateVersion = config.system.nixos.release;
}
