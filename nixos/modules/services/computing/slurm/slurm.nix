{ config, lib, pkgs, ... }:

with lib;

let

  cfg = config.services.slurm;
  # configuration file can be generated by http://slurm.schedmd.com/configurator.html
  configFile = pkgs.writeText "slurm.conf" 
    ''
      ${optionalString (cfg.controlMachine != null) ''controlMachine=${cfg.controlMachine}''}
      ${optionalString (cfg.controlAddr != null) ''controlAddr=${cfg.controlAddr}''}
      ${optionalString (cfg.nodeName != null) ''nodeName=${cfg.nodeName}''}
      ${optionalString (cfg.partitionName != null) ''partitionName=${cfg.partitionName}''}
      ${cfg.extraConfig}
    '';
in

{

  ###### interface

  options = {

    services.slurm = {

      server = {
        enable = mkEnableOption "slurm control daemon";

      };
      
      client = {
        enable = mkEnableOption "slurm rlient daemon";

      };

      package = mkOption {
        type = types.package;
        default = pkgs.slurm-llnl;
        defaultText = "pkgs.slurm-llnl";
        example = literalExample "pkgs.slurm-llnl-full";
        description = ''
          The package to use for slurm binaries.
        '';
      };

      controlMachine = mkOption {
        type = types.nullOr types.str;
        default = null;
        example = null;
        description = ''
          The short hostname of the machine where SLURM control functions are
          executed (i.e. the name returned by the command "hostname -s", use "tux001"
          rather than "tux001.my.com").
        '';
      };

      controlAddr = mkOption {
        type = types.nullOr types.str;
        default = cfg.controlMachine;
        example = null;
        description = ''
          Name that ControlMachine should be referred to in establishing a
          communications path.
        '';
      };

      nodeName = mkOption {
        type = types.nullOr types.str;
        default = null;
        example = "linux[1-32] CPUs=1 State=UNKNOWN";
        description = ''
          Name that SLURM uses to refer to a node (or base partition for BlueGene
          systems). Typically this would be the string that "/bin/hostname -s"
          returns. Note that now you have to write node's parameters after the name.
        '';
      };

      partitionName = mkOption {
        type = types.nullOr types.str;
        default = null;
        example = "debug Nodes=linux[1-32] Default=YES MaxTime=INFINITE State=UP";
        description = ''
          Name by which the partition may be referenced. Note that now you have
          to write patrition's parameters after the name.
        '';
      };

      extraConfig = mkOption {
        default = ""; 
        type = types.lines;
        description = ''
          Extra configuration options that will be added verbatim at
          the end of the slurm configuration file.
        '';
      };
    };

  };


  ###### implementation

  config =
    let
      wrappedSlurm = pkgs.stdenv.mkDerivation {
        name = "wrappedSlurm";

        propagatedBuildInputs = [ cfg.package configFile ];

        builder = pkgs.writeText "builder.sh" ''
          source $stdenv/setup
          mkdir -p $out/bin
          find  ${cfg.package}/bin -type f -executable | while read EXE
          do
            exename="$(basename $EXE)"
            wrappername="$out/bin/$exename"
            cat > "$wrappername" <<EOT
          #!/bin/sh
          if [ -z "$SLURM_CONF" ]
          then
            SLURM_CONF="${configFile}" "$EXE" "\$@"
          else
            "$EXE" "\$0"
          fi
          EOT
            chmod +x "$wrappername"
          done
        '';
      };

  in mkIf (cfg.client.enable || cfg.server.enable) {

    environment.systemPackages = [ wrappedSlurm ];

    systemd.services.slurmd = mkIf (cfg.client.enable) {
      path = with pkgs; [ wrappedSlurm coreutils ];

      wantedBy = [ "multi-user.target" ];
      after = [ "systemd-tmpfiles-clean.service" ];

      serviceConfig = {
        Type = "forking";
        ExecStart = "${wrappedSlurm}/bin/slurmd";
        PIDFile = "/run/slurmd.pid";
        ExecReload = "${pkgs.coreutils}/bin/kill -HUP $MAINPID";
      };

      preStart = ''
        mkdir -p /var/spool
      '';
    };

    systemd.services.slurmctld = mkIf (cfg.server.enable) {
      path = with pkgs; [ wrappedSlurm munge coreutils ];
      
      wantedBy = [ "multi-user.target" ];
      after = [ "network.target" "munged.service" ];
      requires = [ "munged.service" ];

      serviceConfig = {
        Type = "forking";
        ExecStart = "${wrappedSlurm}/bin/slurmctld";
        PIDFile = "/run/slurmctld.pid";
        ExecReload = "${pkgs.coreutils}/bin/kill -HUP $MAINPID";
      };
    };

  };

}
