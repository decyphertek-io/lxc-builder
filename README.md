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