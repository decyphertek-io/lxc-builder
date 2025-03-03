Requirements:
=============
* lxc & Distrobuilder
```
#Debian Based
sudo apt install lxc distrobuilder
#Red Hat Based
sudo yum install lxc distrobuilder
#Arch Linux Based
sudo pacman -S lxc distrobuilder
```
* How to use Distrobuilder with lxc-build repo
```
# Clone and build Redroid LXC image
git clone https://github.com/decyphertek-io/lxc-builder.git
cd lxc-builder
distrobuilder build-lxc example.yml
lxc launch ./example.tar.gz example-container
```