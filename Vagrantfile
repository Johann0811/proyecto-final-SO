# -*- mode: ruby -*-
# vi: set ft=ruby :

Vagrant.configure("2") do |config|
  
  config.vm.box = "ubuntu/focal64"
  
  # Servidor Web  con Nginx y Node Exporter
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
    
    web.vm.provision "shell", path: "scripts/provision_webserver.sh"
  end
  
  # Servidor de Monitoreo con Prometheus y Grafana
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
    
    mon.vm.provision "shell", path: "scripts/provision_monitoring.sh"
  end
  
  # Nodo de Control con Ansible
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
      
      echo "==================================="
      echo "Provisionando Nodo de Control"
      echo "==================================="
      
      apt-get update -y
      apt-get install -y software-properties-common sshpass
      
      echo "📦 Instalando Ansible..."
      apt-add-repository --yes --update ppa:ansible/ansible
      apt-get update -y
      apt-get install -y ansible
      
      echo "🔑 Configurando SSH keys..."
      if [ ! -f /home/vagrant/.ssh/id_rsa ]; then
        sudo -u vagrant ssh-keygen -t rsa -N "" -f /home/vagrant/.ssh/id_rsa
      fi
      chown -R vagrant:vagrant /home/vagrant/.ssh
      
      echo "📝 Creando inventario de Ansible..."
      mkdir -p /home/vagrant/ansible
      cat > /home/vagrant/ansible/inventory.ini <<'EOF'
[webserver]
192.168.56.10

[monitoring]
192.168.56.11

[all:vars]
ansible_user=vagrant
ansible_ssh_common_args='-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null'
EOF
      
      chown -R vagrant:vagrant /home/vagrant/ansible
      
      echo ""
      echo "==================================="
      echo "      Nodo de Control Listo        "
      echo "==================================="
      echo ""
      echo "Para usar Ansible desde esta VM:"
      echo "  1. vagrant ssh control"
      echo "  2. cd ~/ansible"
      echo "  3. ansible all -i inventory.ini -m ping"
      echo ""
    SHELL
  end
  
end