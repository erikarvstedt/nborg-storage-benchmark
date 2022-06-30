{ pkgs, lib, ... }:
with lib;
{
  imports = [
    ./1-installer-system-kexec.nix
  ];

  networking.hostName = "benchmark";

  services.postgresql = {
    enable = true;
    initialScript = pkgs.writeText "synapse-init.sql" ''
      CREATE ROLE "matrix-synapse" WITH LOGIN PASSWORD 'synapse';
    '';
  };
  systemd.services.postgresql.wantedBy = mkForce [];

  users.users.root.openssh.authorizedKeys.keys = mkForce [
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAICW0rZHTE+/gRpbPVw0Q6Wr3csEgU7P+Q8Kw6V2xxDsG" # Erik Arvstedt
    # "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIIBQTTNni8/ryWHfHtdoFSJhO2243K5+G9YaVjbF8WgW none" # tmp
  ];
}
