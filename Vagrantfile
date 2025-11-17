# -*- mode: ruby -*-
# vi: set ft=ruby :

Vagrant.configure("2") do |config|
  
  # Configuración de la máquina virtual para Nginx (Servidor Web)
  config.vm.define "webserver" do |web|
    web.vm.box = "ubuntu/jammy64"
    web.vm.hostname = "webserver"
    
    # Configuración de red
    web.vm.network "private_network", ip: "192.168.56.10"
    
    # Reenvío de puertos
    web.vm.network "forwarded_port", guest: 80, host: 8080
    web.vm.network "forwarded_port", guest: 9100, host: 9100
    
    # Asignación de recursos
    web.vm.provider "virtualbox" do |vb|
      vb.name = "DataExplorer-WebServer"
      vb.memory = "1024"
      vb.cpus = 2
    end
    
    # Provisionamiento con Ansible
    web.vm.provision "ansible" do |ansible|
      ansible.playbook = "ansible/playbook.yml"
      ansible.inventory_path = "ansible/inventory.ini"
      ansible.limit = "webserver"
      ansible.verbose = "v"
    end
  end
  
  # Configuración de la máquina virtual para Prometheus y Grafana (Monitoreo)
  config.vm.define "monitoring" do |mon|
    mon.vm.box = "ubuntu/jammy64"
    mon.vm.hostname = "monitoring"
    
    # Configuración de red
    mon.vm.network "private_network", ip: "192.168.56.11"
    
    # Reenvío de puertos
    mon.vm.network "forwarded_port", guest: 9090, host: 9090  # Prometheus
    mon.vm.network "forwarded_port", guest: 3000, host: 3000  # Grafana
    
    # Asignación de recursos (más recursos para monitoreo)
    mon.vm.provider "virtualbox" do |vb|
      vb.name = "DataExplorer-Monitoring"
      vb.memory = "2048"
      vb.cpus = 2
    end
    
    # Provisionamiento con Ansible
    mon.vm.provision "ansible" do |ansible|
      ansible.playbook = "ansible/playbook.yml"
      ansible.inventory_path = "ansible/inventory.ini"
      ansible.limit = "monitoring"
      ansible.verbose = "v"
    end
  end
  
end