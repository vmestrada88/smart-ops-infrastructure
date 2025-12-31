#!/bin/bash

# Script para configurar nginx + SSL para Smart Ops
# Dominio: smartsolutionfl.com

DOMAIN="smartsolutionfl.com"
EMAIL="vmestrada88@gmail.com"  # Cambia esto a tu email

echo "=========================================="
echo "Configurando nginx para $DOMAIN"
echo "=========================================="

# Paso 1: Crear configuración de nginx
sudo tee /etc/nginx/sites-available/smart-ops << 'NGINX_CONFIG'
server {
    listen 80;
    listen [::]:80;
    server_name smartsolutionfl.com www.smartsolutionfl.com;

    # Logs
    access_log /var/log/nginx/smart-ops-access.log;
    error_log /var/log/nginx/smart-ops-error.log;

    # Frontend - Proxy pass al contenedor
    location / {
        proxy_pass http://localhost:8080;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_cache_bypass $http_upgrade;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }

    # Backend API
    location /api {
        proxy_pass http://localhost:5000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_cache_bypass $http_upgrade;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
NGINX_CONFIG

# Paso 2: Habilitar el sitio
sudo ln -sf /etc/nginx/sites-available/smart-ops /etc/nginx/sites-enabled/

# Paso 3: Remover default si existe
sudo rm -f /etc/nginx/sites-enabled/default

# Paso 4: Verificar configuración
echo ""
echo "Verificando configuración de nginx..."
sudo nginx -t

# Paso 5: Reiniciar nginx
if [ $? -eq 0 ]; then
    echo ""
    echo "Reiniciando nginx..."
    sudo systemctl restart nginx
    sudo systemctl enable nginx
    echo "✅ Nginx configurado correctamente"
else
    echo "❌ Error en la configuración de nginx"
    exit 1
fi

# Paso 6: Mostrar status
echo ""
echo "Estado de nginx:"
sudo systemctl status nginx --no-pager -l

echo ""
echo "=========================================="
echo "Configuración completada!"
echo "=========================================="
echo ""
echo "Próximos pasos:"
echo "1. Configura los registros DNS A para apuntar a esta IP"
echo "2. Espera la propagación DNS (1-24 horas)"
echo "3. Ejecuta el script de SSL: ./setup-ssl.sh"
echo ""
