#!/bin/bash
# LXD Container Traffic Through VPN - Auto-detection version

# Detect VPN interface (prioritizing WireGuard, then OpenVPN, then others)
VPN_IF=$(ip link | grep -E 'wg[0-9]+' | awk -F: '{print $2}' | tr -d ' ' | head -n 1)
[ -z "$VPN_IF" ] && VPN_IF=$(ip link | grep -E 'tun[0-9]+' | awk -F: '{print $2}' | tr -d ' ' | head -n 1)
[ -z "$VPN_IF" ] && VPN_IF=$(ip link | grep -E 'vpn|tap' | awk -F: '{print $2}' | tr -d ' ' | head -n 1)

# Exit if no VPN interface found
[ -z "$VPN_IF" ] && echo "No VPN interface detected. Exiting." && exit 1

# Get VPN interface MTU
VPN_MTU=$(ip link show $VPN_IF | grep -oP 'mtu \K\d+')

# Enable IP forwarding
sudo sysctl -w net.ipv4.ip_forward=1
echo "net.ipv4.ip_forward=1" | sudo tee -a /etc/sysctl.conf

# Get LXD bridge subnet
LXD_SUBNET=$(lxc network get lxdbr0 ipv4.address)
echo "LXD subnet detected as: $LXD_SUBNET"
echo "VPN interface detected as: $VPN_IF with MTU $VPN_MTU"

# Allow traffic from LXD subnet to VPN interface
sudo ufw route allow from $LXD_SUBNET out on $VPN_IF

# Create LXD profile for VPN access
lxc profile create vpn-access 2>/dev/null || echo "Profile already exists"
lxc profile device remove vpn-access eth0 2>/dev/null || true
lxc profile device add vpn-access eth0 nic nictype=macvlan parent=$VPN_IF
lxc profile device set vpn-access eth0 mtu $VPN_MTU

# Display instructions
echo "========================================================"
echo "VPN routing for LXD containers has been configured."
echo "To use with a container:"
echo "lxc profile assign your-container-name default,vpn-access"
echo ""
echo "To test if it's working:"
echo "lxc exec your-container-name -- curl ifconfig.me"
echo "========================================================"