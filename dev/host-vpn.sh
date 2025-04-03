# 1. Create a new profile for VPN access
lxc profile create wireguard-vpn

# 2. Option A: Give the container direct access to the host network namespace
# This is the simplest approach but less isolated
lxc profile device add wireguard-vpn eth0 nic nictype=macvlan parent=wgpia0
lxc profile device set wireguard-vpn eth0 mtu 1414

# 3. Apply this profile to your container
lxc profile assign my-container default,wireguard-vpn

# 4. Option B: For routing all container traffic through the VPN
# Enable IP forwarding on the host
sudo sysctl -w net.ipv4.ip_forward=1

# 5. Add iptables rules to route container traffic
sudo iptables -t nat -A POSTROUTING -s $(lxc network get lxdbr0 ipv4.address) -o wgpia0 -j MASQUERADE

# 6. Make the change permanent
echo "net.ipv4.ip_forward=1" | sudo tee -a /etc/sysctl.conf