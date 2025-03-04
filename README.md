Requirements:
=============
* LXC & Distrobuilder
```
#Debian Based
sudo apt install lxc bridge-utils distrobuilder

#Red Hat Based
sudo yum install lxc bridge-utils distrobuilder

#Arch Linux Based
sudo pacman -S lxc bridge-utils distrobuilder

# Configure LXC networking
sudo mkdir -p /etc/lxc
cat << EOF | sudo tee /etc/lxc/default.conf
lxc.net.0.type = veth
lxc.net.0.link = lxcbr0
lxc.net.0.flags = up
lxc.net.0.hwaddr = 00:16:3e:xx:xx:xx
EOF

# Setup LXC bridge
sudo systemctl enable lxc-net
sudo systemctl start lxc-net

# Verify bridge is created
ip a show lxcbr0
```
* How to use Distrobuilder with lxc-build repo
```
# Clone and build Redroid LXC image
git clone https://github.com/decyphertek-io/lxc-builder.git
cd lxc-builder
sudo distrobuilder build-lxc example.yml
# This can take 15 minutes to build
sudo lxc launch ./example.tar.gz example-container
```

References:
-----------
* https://linuxcontainers.org/distrobuilder/docs/latest/reference/