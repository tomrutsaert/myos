#!/usr/bin/env bash
set -euo pipefail

# Modify firewalld's persistent configuration without contacting a running daemon.
# With no --zone argument, firewall-offline-cmd targets the configured default zone.
firewall-offline-cmd --add-service=mosh
