# Complete LXD-Ansible-Guacamole Integration

# 1. Create directory structure
mkdir -p lxd-ansible-guacamole/{ansible,templates}
cd lxd-ansible-guacamole

# 2. Create Packer template
cat > packer-lxd-ansible.pkr.hcl << 'EOF'
packer {
  required_plugins {
    lxd = {
      version = ">= 1.0.0"
      source  = "github.com/hashicorp/lxd"
    }
  }
}

source "lxd" "ubuntu" {
  image = "ubuntu:20.04"
  output_image = "lxd-ansible-server"
  publish_properties = {
    description = "LXD server with Ansible and Guacamole integration"
  }
}

build {
  sources = ["source.lxd.ubuntu"]

  provisioner "shell" {
    inline = [
      "apt-get update",
      "apt-get install -y python3 python3-pip openssh-server sudo curl wget",
      "pip3 install ansible",
      "mkdir -p /etc/ansible /etc/guacamole"
    ]
  }

  provisioner "file" {
    source      = "./ansible/"
    destination = "/etc/ansible/"
  }

  provisioner "file" {
    source      = "./templates/"
    destination = "/tmp/"
  }

  provisioner "shell" {
    inline = [
      "cd /etc/ansible",
      "ansible-playbook -c local -i localhost, playbook.yml",
      "echo 'export GUACAMOLE_HOME=/etc/guacamole' >> /etc/environment",
      "mv /tmp/launch-lxd.sh /usr/local/bin/",
      "chmod +x /usr/local/bin/launch-lxd.sh",
      "mv /tmp/user-mapping.xml /etc/guacamole/",
      "mv /tmp/guacamole.properties /etc/guacamole/",
      "systemctl enable ssh guacd tomcat9"
    ]
  }
}
EOF

# 3. Create Ansible playbook
cat > ansible/playbook.yml << 'EOF'
---
- hosts: localhost
  become: yes
  tasks:
    - name: Install dependencies
      apt:
        name:
          - guacd
          - libguac-client-ssh0
          - libguac-client-rdp0
          - tomcat9
          - nginx
        state: present
        update_cache: yes

    - name: Download Guacamole WAR file
      get_url:
        url: https://downloads.apache.org/guacamole/1.4.0/binary/guacamole-1.4.0.war
        dest: /var/lib/tomcat9/webapps/guacamole.war
        mode: '0644'

    - name: Create Guacamole directories
      file:
        path: "{{ item }}"
        state: directory
        mode: '0755'
      with_items:
        - /etc/guacamole
        - /usr/share/tomcat9/.guacamole

    - name: Configure Tomcat for Guacamole
      lineinfile:
        path: /etc/default/tomcat9
        line: 'GUACAMOLE_HOME=/etc/guacamole'
        state: present

    - name: Install LXD
      snap:
        name: lxd
        state: present

    - name: Initialize LXD with default settings
      command: lxd init --auto
      args:
        creates: /var/snap/lxd/common/lxd/unix.socket

    - name: Set up SSH for Guacamole access
      user:
        name: guacamole
        shell: /bin/bash
        home: /home/guacamole
        createhome: yes
        password: "{{ 'guacamole' | password_hash('sha512') }}"

    - name: Add guacamole user to lxd group
      user:
        name: guacamole
        groups: lxd
        append: yes
EOF

# 4. Create Guacamole properties file
cat > templates/guacamole.properties << 'EOF'
guacd-hostname: localhost
guacd-port:     4822
user-mapping:   /etc/guacamole/user-mapping.xml
auth-provider:  net.sourceforge.guacamole.net.basic.BasicFileAuthenticationProvider
EOF

# 5. Create user mapping XML
cat > templates/user-mapping.xml << 'EOF'
<user-mapping>
    <authorize username="admin" password="$5$rounds=535000$IquZHXPCh9NpHtMy$GDZPb5.g.BgHcIZB/Jn8z8JIwLzmIdVlvFvSrPUyoq7">
        <connection name="Launch LXD Server">
            <protocol>ssh</protocol>
            <param name="hostname">localhost</param>
            <param name="port">22</param>
            <param name="username">guacamole</param>
            <param name="command">/usr/local/bin/launch-lxd.sh lxd-server-$(date +%s)</param>
        </connection>
        <connection name="LXD Management Console">
            <protocol>ssh</protocol>
            <param name="hostname">localhost</param>
            <param name="port">22</param>
            <param name="username">guacamole</param>
        </connection>
    </authorize>
</user-mapping>
EOF

# 6. Create LXD launch script
cat > templates/launch-lxd.sh << 'EOF'
#!/bin/bash
CONTAINER_NAME=$1

if [ -z "$CONTAINER_NAME" ]; then
  echo "Container name required"
  exit 1
fi

# Launch the container
lxc launch lxd-ansible-server $CONTAINER_NAME

# Wait for container to be ready
sleep 5

# Get container IP
CONTAINER_IP=$(lxc list $CONTAINER_NAME -c 4 --format csv | cut -d' ' -f1)

# Add new connection to Guacamole
cat >> /etc/guacamole/user-mapping.xml <