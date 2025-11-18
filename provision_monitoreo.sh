#!/usr/bin/env bash
# script de provisión para el servidor de monitoreo
set -e
export DEBIAN_FRONTEND=noninteractive

echo "--- Iniciando la provisión del servidor de monitoreo ---"

# Crear SWAP de 2GB para evitar OOM
echo "--- configuración de swap ---"
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
    echo "Swap de 2GB configurado"
else
    echo "Ya existe swap configurado"
fi

# se actualiza el sistema
echo "--- Actualizando paquetes ---"
apt-get update -y
apt-get upgrade -y

# Instalar dependencias
echo "--- Instalando dependencias ---"
apt-get install -y --no-install-recommends \
    wget \
    curl \
    tar \
    gnupg \
    apt-transport-https \
    software-properties-common \
    net-tools

# instalación de Prometheus

echo "--- Instalando Prometheus ---"

PROM_VERSION="2.48.0"
PROM_TARBALL="prometheus-${PROM_VERSION}.linux-amd64.tar.gz"
PROM_URL="https://github.com/prometheus/prometheus/releases/download/v${PROM_VERSION}/${PROM_TARBALL}"

# se crea un usuario
useradd --no-create-home --shell /usr/sbin/nologin prometheus || true

# creación dde directorios
mkdir -p /etc/prometheus /var/lib/prometheus

# se descargan y extraen
cd /tmp
if [ ! -f "${PROM_TARBALL}" ]; then
    echo "--- Descargando Prometheus ${PROM_VERSION} ---"
    wget -q --show-progress ${PROM_URL} -O ${PROM_TARBALL}
fi

echo "--- Extrayendo Prometheus ---"
tar xzf ${PROM_TARBALL}
PROM_DIR=$(tar -tf ${PROM_TARBALL} | head -1 | cut -f1 -d"/")

# para copiar los binarios
cp ${PROM_DIR}/prometheus /usr/local/bin/
cp ${PROM_DIR}/promtool /usr/local/bin/
chmod +x /usr/local/bin/prometheus /usr/local/bin/promtool

# se copian los archivos de configuración
cp -r ${PROM_DIR}/consoles /etc/prometheus/
cp -r ${PROM_DIR}/console_libraries /etc/prometheus/

# configuración de Prometheus
echo "--- Configurando Prometheus ---"
cat > /etc/prometheus/prometheus.yml <<'EOF'
global:
  scrape_interval: 15s
  evaluation_interval: 15s
  external_labels:
    monitor: 'dataexplorer'

scrape_configs:
  # Monitoreo de Prometheus mismo
  - job_name: 'prometheus'
    static_configs:
      - targets: ['localhost:9090']
        labels:
          instance: 'prometheus'
          environment: 'production'
  
  # Monitoreo del Servidor Web
  - job_name: 'webserver'
    static_configs:
      - targets: ['192.168.56.22:9100']
        labels:
          instance: 'web'
          environment: 'production'
          role: 'nginx'
EOF

# permisos
chown -R prometheus:prometheus /etc/prometheus /var/lib/prometheus

# creación del servicio systemd
cat > /etc/systemd/system/prometheus.service <<'EOF'
[Unit]
Description=Prometheus Monitoring System
Documentation=https://prometheus.io/docs/introduction/overview/
Wants=network-online.target
After=network-online.target

[Service]
User=prometheus
Group=prometheus
Type=simple
Restart=on-failure
RestartSec=5s
ExecStart=/usr/local/bin/prometheus \
  --config.file=/etc/prometheus/prometheus.yml \
  --storage.tsdb.path=/var/lib/prometheus/ \
  --web.console.templates=/etc/prometheus/consoles \
  --web.console.libraries=/etc/prometheus/console_libraries \
  --web.listen-address=0.0.0.0:9090

[Install]
WantedBy=multi-user.target
EOF

# se iniciar Prometheus
echo "--- Iniciando Prometheus ---"
systemctl daemon-reload
systemctl enable prometheus
systemctl start prometheus

# esperar a que Prometheus inicie
sleep 5

# instalación de Grafana

echo "--- Instalando Grafana ---"

# repositorio de Grafana
echo "--- Agregando el repositorio de Grafana ---"
wget -q -O - https://apt.grafana.com/gpg.key | apt-key add -
echo "deb https://apt.grafana.com stable main" > /etc/apt/sources.list.d/grafana.list

# actualizar e instalar
apt-get update -y
apt-get install -y --no-install-recommends grafana

# configuración de Grafana
echo "---  Configurando Grafana ---"
cat > /etc/grafana/grafana.ini <<'EOF'
[server]
protocol = http
http_port = 3000
domain = 192.168.56.23
root_url = http://192.168.56.23:3000

[security]
admin_user = admin
admin_password = admin
disable_gravatar = true

[users]
allow_sign_up = false
allow_org_create = false

[auth.anonymous]
enabled = false

[analytics]
reporting_enabled = false
check_for_updates = false

[log]
mode = console
level = info
EOF

chown root:grafana /etc/grafana/grafana.ini
chmod 640 /etc/grafana/grafana.ini

# inicar Grafana
echo "--- Iniciando Grafana ---"
systemctl daemon-reload
systemctl enable grafana-server
systemctl start grafana-server

# Esperar a que Grafana este disponible
echo "--- Esperando a que Grafana inicie ---"
for i in {1..30}; do
    if curl -s http://localhost:3000/api/health > /dev/null 2>&1; then
        echo "✅ Grafana está listo"
        break
    fi
    sleep 2
done

# configuracion de Prometheus y Grafana
echo "--- Configurando datasource de Prometheus en Grafana ---"
sleep 5

curl -s -X POST http://admin:admin@localhost:3000/api/datasources \
  -H "Content-Type: application/json" \
  -d '{
    "name": "Prometheus",
    "type": "prometheus",
    "url": "http://localhost:9090",
    "access": "proxy",
    "isDefault": true,
    "jsonData": {
      "httpMethod": "POST",
      "timeInterval": "15s"
    }
  }' > /dev/null 2>&1 || echo "--- Datasource ya existe o se configurará manualmente ---"

# verificar estado de los servicios
echo "--- Provisión Completada ---"

echo "--- Estado de los servicios ---"
systemctl status prometheus --no-pager | grep "Active:"
systemctl status grafana-server --no-pager | grep "Active:"

echo "--- URLs de acceso ---"
echo "   Prometheus: http://192.168.56.23:9090 (desde host: http://localhost:9090)"
echo "   Grafana:    http://192.168.56.23:3000 (desde host: http://localhost:3000)"
echo "Credenciales de Grafana:"
echo "   Usuario: admin"
echo "   Contraseña: admin"