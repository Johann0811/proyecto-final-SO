# -*- mode: ruby -*-
# vi: set ft=ruby :

Vagrant.configure("2") do |config|
  
  config.vm.box = "ubuntu/focal64"
  
  # Servidor Web con Nginx y Node Exporter
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
    
    web.vm.provision "shell", inline: <<-SHELL
      #!/usr/bin/env bash
      set -e
      export DEBIAN_FRONTEND=noninteractive

      echo "--- provisionando Servidor Web ---"
      echo "--- actualizando paquetes ---"
      apt-get update -y
      apt-get upgrade -y

      echo "Instalando dependencias..."
      apt-get install -y --no-install-recommends nginx wget curl net-tools

      echo "--- configurando Nginx ---"
      cat > /var/www/html/index.html <<'EOF'
<!DOCTYPE html>
<html lang="es">
<head>
    <meta charset="UTF-8">
    <title>DataExplorer - Servidor Web</title>
</head>
<body>
    <h1>Proyecto DataExplorer</h1>
    <p>Servidor Web - Sistema de Monitoreo</p>
    
    <h2>Informacion del Servidor</h2>
    <ul>
        <li>Hostname: web</li>
        <li>IP: 192.168.56.22</li>
        <li>Servidor Web: Nginx</li>
        <li>Puerto: 80</li>
        <li>Sistema Operativo: Ubuntu 20.04 LTS</li>
    </ul>
    
    <h2>Metricas del Sistema</h2>
    <ul>
        <li>Node Exporter: Puerto 9100</li>
        <li>Endpoint: <a href="http://localhost:9100/metrics">http://localhost:9100/metrics</a></li>
    </ul>
    
    <p>Proyecto Final - Administracion de Sistemas Operativos</p>
</body>
</html>
EOF

      echo "--- reiniciando Nginx ---"
      systemctl enable nginx
      systemctl restart nginx

      echo "--- instalando Node Exporter ---"
      NODE_VERSION="1.7.0"
      NODE_TARBALL="node_exporter-\${NODE_VERSION}.linux-amd64.tar.gz"
      NODE_URL="https://github.com/prometheus/node_exporter/releases/download/v\${NODE_VERSION}/\${NODE_TARBALL}"

      cd /tmp
      if [ ! -f "\${NODE_TARBALL}" ]; then
          wget -q \${NODE_URL} -O \${NODE_TARBALL}
      fi

      tar xzf \${NODE_TARBALL}
      NODE_DIR=\$(tar -tf \${NODE_TARBALL} | head -1 | cut -f1 -d"/")
      cp \${NODE_DIR}/node_exporter /usr/local/bin/
      chmod +x /usr/local/bin/node_exporter

      useradd --no-create-home --shell /usr/sbin/nologin node_exporter || true

      cat > /etc/systemd/system/node_exporter.service <<'EOF'
[Unit]
Description=Node Exporter
Wants=network-online.target
After=network-online.target

[Service]
User=node_exporter
Group=node_exporter
Type=simple
Restart=on-failure
ExecStart=/usr/local/bin/node_exporter

[Install]
WantedBy=multi-user.target
EOF

      echo "--- iniciando Node Exporter ---"
      systemctl daemon-reload
      systemctl enable node_exporter
      systemctl start node_exporter

      echo "Provision completada - Servidor Web"
      systemctl status nginx --no-pager | grep "Active:"
      systemctl status node_exporter --no-pager | grep "Active:"
    SHELL
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
    
    mon.vm.provision "shell", inline: <<-SHELL
      #!/usr/bin/env bash
      set -e
      export DEBIAN_FRONTEND=noninteractive

      echo "--- provisionando Servidor de Monitoreo ---"
      
      echo "--- configurando Swap ---"
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

      echo "--- actualizando paquetes ---"
      apt-get update -y
      apt-get upgrade -y

      echo "Instalando dependencias..."
      apt-get install -y --no-install-recommends wget curl tar gnupg apt-transport-https software-properties-common net-tools

      echo "--- instalando Prometheus ---"
      PROM_VERSION="2.48.0"
      PROM_TARBALL="prometheus-\${PROM_VERSION}.linux-amd64.tar.gz"
      PROM_URL="https://github.com/prometheus/prometheus/releases/download/v\${PROM_VERSION}/\${PROM_TARBALL}"

      useradd --no-create-home --shell /usr/sbin/nologin prometheus || true
      mkdir -p /etc/prometheus /var/lib/prometheus

      cd /tmp
      if [ ! -f "\${PROM_TARBALL}" ]; then
          wget -q --show-progress \${PROM_URL} -O \${PROM_TARBALL}
      fi

      tar xzf \${PROM_TARBALL}
      PROM_DIR=\$(tar -tf \${PROM_TARBALL} | head -1 | cut -f1 -d"/")

      cp \${PROM_DIR}/prometheus /usr/local/bin/
      cp \${PROM_DIR}/promtool /usr/local/bin/
      chmod +x /usr/local/bin/prometheus /usr/local/bin/promtool

      cp -r \${PROM_DIR}/consoles /etc/prometheus/
      cp -r \${PROM_DIR}/console_libraries /etc/prometheus/

      cat > /etc/prometheus/prometheus.yml <<'EOF'
global:
  scrape_interval: 15s
  evaluation_interval: 15s

scrape_configs:
  - job_name: 'prometheus'
    static_configs:
      - targets: ['localhost:9090']
  
  - job_name: 'webserver'
    static_configs:
      - targets: ['192.168.56.22:9100']
EOF

      chown -R prometheus:prometheus /etc/prometheus /var/lib/prometheus

      cat > /etc/systemd/system/prometheus.service <<'EOF'
[Unit]
Description=Prometheus Monitoring System
Wants=network-online.target
After=network-online.target

[Service]
User=prometheus
Group=prometheus
Type=simple
Restart=on-failure
RestartSec=5s
ExecStart=/usr/local/bin/prometheus --config.file=/etc/prometheus/prometheus.yml --storage.tsdb.path=/var/lib/prometheus/ --web.console.templates=/etc/prometheus/consoles --web.console.libraries=/etc/prometheus/console_libraries --web.listen-address=0.0.0.0:9090

[Install]
WantedBy=multi-user.target
EOF

      systemctl daemon-reload
      systemctl enable prometheus
      systemctl start prometheus

      echo "--- instalando Grafana ---"
      wget -q -O - https://apt.grafana.com/gpg.key | apt-key add -
      echo "deb https://apt.grafana.com stable main" > /etc/apt/sources.list.d/grafana.list

      apt-get update -y
      apt-get install -y --no-install-recommends grafana

      cat > /etc/grafana/grafana.ini <<'EOF'
[server]
protocol = http
http_port = 3000
domain = 192.168.56.23

[security]
admin_user = admin
admin_password = admin

[users]
allow_sign_up = false

[analytics]
reporting_enabled = false
check_for_updates = false
EOF

      chown root:grafana /etc/grafana/grafana.ini
      chmod 640 /etc/grafana/grafana.ini

      systemctl daemon-reload
      systemctl enable grafana-server
      systemctl start grafana-server

      echo "Esperando a que Grafana inicie..."
      for i in {1..30}; do
          if curl -s http://localhost:3000/api/health > /dev/null 2>&1; then
              break
          fi
          sleep 2
      done

      curl -s -X POST http://admin:admin@localhost:3000/api/datasources -H "Content-Type: application/json" -d '{"name":"Prometheus","type":"prometheus","url":"http://localhost:9090","access":"proxy","isDefault":true}' > /dev/null 2>&1 || true

      echo "Provision completada - Servidor de Monitoreo"
      systemctl status prometheus --no-pager | grep "Active:"
      systemctl status grafana-server --no-pager | grep "Active:"
    SHELL
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
      
      echo "--- Provisionando Nodo de Control ---"
      
      apt-get update -y
      apt-get install -y software-properties-common sshpass
      
      echo "--- instalando Ansible ---"
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
ansible_ssh_common_args='-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null'
EOF
      
      chown -R vagrant:vagrant /home/vagrant/ansible
      
      echo "Provision completada - Nodo de Control"
    SHELL
  end
  
end