#!/usr/bin/env bash
# Script de provisionamiento del Servidor Web
set -e
export DEBIAN_FRONTEND=noninteractive

echo "--- provisionando Servidor Web ---"

# Actualizar sistema
echo "--- actualizando paquetes ---"
apt-get update -y
apt-get upgrade -y

# Instalar dependencias básicas
echo "--- instalando dependencias ---"
apt-get install -y --no-install-recommends \
    nginx \
    wget \
    curl \
    net-tools

# Configuración de la página web
echo "--- configurando Nginx ---"
cat > /var/www/html/index.html <<'EOF'
<!DOCTYPE html>
<html lang="es">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>DataExplorer - Servidor Web</title>
</head>
<body>
    <h1>Proyecto DataExplorer</h1>
    <p>Servidor Web - Sistema de Monitoreo</p>
    
    <h2>Información del Servidor</h2>
    <ul>
        <li><strong>Hostname:</strong> web</li>
        <li><strong>IP:</strong> 192.168.56.22</li>
        <li><strong>Servidor Web:</strong> Nginx</li>
        <li><strong>Puerto:</strong> 80</li>
        <li><strong>Sistema Operativo:</strong> Ubuntu 20.04 LTS</li>
        <li><strong>Provisionado con:</strong> Vagrant + Shell Script</li>
    </ul>
    
    <h2>Métricas del Sistema</h2>
    <ul>
        <li><strong>Node Exporter:</strong> Puerto 9100</li>
        <li><strong>Endpoint:</strong> <a href="http://localhost:9100/metrics">http://localhost:9100/metrics</a></li>
    </ul>
    
    <hr>
    <p>Proyecto Final - Administración de Sistemas Operativos</p>
</body>
</html>
EOF

# Reiniciar Nginx
echo "--- reiniciando Nginx ---"
systemctl enable nginx
systemctl restart nginx

# Instalar Node Exporter
echo "--- instalando Node Exporter ---"
NODE_VERSION="1.7.0"
NODE_TARBALL="node_exporter-${NODE_VERSION}.linux-amd64.tar.gz"
NODE_URL="https://github.com/prometheus/node_exporter/releases/download/v${NODE_VERSION}/${NODE_TARBALL}"

cd /tmp
if [ ! -f "${NODE_TARBALL}" ]; then
    wget -q ${NODE_URL} -O ${NODE_TARBALL}
fi

tar xzf ${NODE_TARBALL}
NODE_DIR=$(tar -tf ${NODE_TARBALL} | head -1 | cut -f1 -d"/")
cp ${NODE_DIR}/node_exporter /usr/local/bin/
chmod +x /usr/local/bin/node_exporter

# Crear usuario para Node Exporter
useradd --no-create-home --shell /usr/sbin/nologin node_exporter || true

# Crear servicio systemd
cat > /etc/systemd/system/node_exporter.service <<'EOF'
[Unit]
Description=Node Exporter
Documentation=https://github.com/prometheus/node_exporter
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

# Iniciar Node Exporter
echo "--- iniciando Node Exporter ---"
systemctl daemon-reload
systemctl enable node_exporter
systemctl start node_exporter

# Verificación del estado de servicios
echo "--- Provisión Completada ---"
echo "Estado de los servicios:"
systemctl status nginx --no-pager | grep "Active:"
systemctl status node_exporter --no-pager | grep "Active:"
echo "Acceso web: http://192.168.56.22 (desde host: http://localhost:8080)"
echo "Métricas: http://192.168.56.22:9100/metrics (desde host: http://localhost:9100/metrics)"