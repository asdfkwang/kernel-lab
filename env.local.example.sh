#!/usr/bin/env bash
# Template — copy to env.local.sh (gitignored) and fill in real values:
#   cp env.local.example.sh env.local.sh
# ${VAR:-...} form keeps an explicitly exported variable winning over
# both this file and the built-in defaults in env.sh.

export RPI_SSH_HOST="${RPI_SSH_HOST:-192.168.0.10}"  # Pi's LAN IP
export RPI_SSH_USER="${RPI_SSH_USER:-pi}"            # SSH user on the Pi
export RPI_SERVER_IP="${RPI_SERVER_IP:-192.168.0.27}" # this PC (build host + NFS server)
