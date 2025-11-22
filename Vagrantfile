# -- mode: ruby --
# vi: set ft=ruby :

Vagrant.configure("2") do |config|
  config.vm.box = "ubuntu/focal64"
  
  # --- Servidor Web ---
  config.vm.define "web" do |web|
    web.vm.hostname = "web"
    web.vm.network "private_network", ip: "192.168.56.22"
    web.vm.network "forwarded_port", guest: 80, host: 8080
    web.vm.network "forwarded_port", guest: 9100, host: 9100
    
    web.vm.provider "virtualbox" do |vb|
      vb.name = "DataExplorer-Web"
      vb.memory = "2048"
      vb.cpus = 2
      vb.gui = false
    end

    #Se Fuerza la autenticación por contraseña
    web.vm.provision "shell", inline: <<-SHELL
      # Crear un archivo de configuración que sobrescribe a los demás
      echo "PasswordAuthentication yes" > /etc/ssh/sshd_config.d/99-force-auth.conf
      echo "PermitRootLogin yes" >> /etc/ssh/sshd_config.d/99-force-auth.conf
      
      #Se asegura el archivo principal
      sed -i 's/^PasswordAuthentication no/PasswordAuthentication yes/' /etc/ssh/sshd_config
      sed -i 's/^KbdInteractiveAuthentication no/KbdInteractiveAuthentication yes/' /etc/ssh/sshd_config
      
      # Reiniciar servicio
      systemctl restart sshd
      
      # Asegurar usuario y contraseña vagrant
      echo "vagrant:vagrant" | chpasswd
    SHELL
  end
  
  # --- Servidor de Monitoreo ---
  config.vm.define "monitoreo" do |mon|
    mon.vm.hostname = "monitoreo"
    mon.vm.network "private_network", ip: "192.168.56.23"
    mon.vm.network "forwarded_port", guest: 9090, host: 9090
    mon.vm.network "forwarded_port", guest: 3000, host: 3000
    
    mon.vm.provider "virtualbox" do |vb|
      vb.name = "DataExplorer-Monitoreo"
      vb.memory = "4096"
      vb.cpus = 2
      vb.gui = false
    end
    
    # Configuración de Swap
    mon.vm.provision "shell", inline: <<-SHELL
      #!/usr/bin/env bash
      set -e
      export DEBIAN_FRONTEND=noninteractive
      
      # Swap
      if ! swapon --show | grep -q '/swapfile'; then
          if command -v fallocate >/dev/null 2>&1; then
              fallocate -l 2G /swapfile || dd if=/dev/zero of=/swapfile bs=1M count=2048
          else
              dd if=/dev/zero of=/swapfile bs=1M count=2048
          fi
          chmod 600 /swapfile
          mkswap /swapfile
          swapon /swapfile
          echo '/swapfile none swap sw 0 0' >> /etc/fstab
      fi

      echo "PasswordAuthentication yes" > /etc/ssh/sshd_config.d/99-force-auth.conf
      echo "PermitRootLogin yes" >> /etc/ssh/sshd_config.d/99-force-auth.conf
      sed -i 's/^PasswordAuthentication no/PasswordAuthentication yes/' /etc/ssh/sshd_config
      systemctl restart sshd
      echo "vagrant:vagrant" | chpasswd
    SHELL
  end
  
  # --- Nodo de Control ---
  config.vm.define "control" do |control|
    control.vm.hostname = "control"
    control.vm.network "private_network", ip: "192.168.56.24"
    
    control.vm.provider "virtualbox" do |vb|
      vb.name = "DataExplorer-Control"
      vb.memory = "1024"
      vb.cpus = 1
      vb.gui = false
    end
    
    control.vm.provision "shell", inline: <<-SHELL
      #!/usr/bin/env bash
      set -e
      export DEBIAN_FRONTEND=noninteractive
      
      apt-get update -y
      apt-get install -y software-properties-common sshpass
      apt-add-repository --yes --update ppa:ansible/ansible
      apt-get update -y
      apt-get install -y ansible
      
      if [ ! -f /home/vagrant/.ssh/id_rsa ]; then
        sudo -u vagrant ssh-keygen -t rsa -N "" -f /home/vagrant/.ssh/id_rsa
      fi
      chown -R vagrant:vagrant /home/vagrant/.ssh
      
      mkdir -p /home/vagrant/ansible
      
      cat > /home/vagrant/ansible/inventory.ini <<'EOF'
[web]
192.168.56.22

[monitoreo]
192.168.56.23

[all:vars]
ansible_user=vagrant
ansible_ssh_pass=vagrant
ansible_become=yes
ansible_become_method=sudo
ansible_become_pass=vagrant
ansible_ssh_common_args='-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null'
ansible_python_interpreter=/usr/bin/python3
EOF
      chown -R vagrant:vagrant /home/vagrant/ansible
    SHELL
  end
end