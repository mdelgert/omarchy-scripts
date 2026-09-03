#!/usr/bin/env bash
set -Eeuo pipefail

# @script.id hostname-info
# @script.title Hostname & network info
# @script.description Prints hostname, IP addresses, default route, and DNS resolvers.
# @script.category Diagnostics
# @script.tags network,diagnostics

echo "Hostname: $(hostname)"
echo

echo "IP addresses:"
ip -brief address show | awk '{print "  " $1 ": " $3}'
echo

echo "Default route:"
ip route show default 2>/dev/null | sed 's/^/  /' || echo "  none"
echo

echo "DNS resolvers:"
if [[ -r /etc/resolv.conf ]]; then
  awk '/^nameserver/ {print "  " $2}' /etc/resolv.conf
else
  echo "  /etc/resolv.conf not readable"
fi
