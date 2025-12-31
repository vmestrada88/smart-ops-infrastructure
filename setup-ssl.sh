#!/bin/bash

# Script para configurar SSL con Let's Encrypt
# Dominio: smartsolutionfl.com

DOMAIN="smartsolutionfl.com"
EMAIL="vmestrada88@gmail.com"  # Cambia esto a tu email

echo "=========================================="
echo "Configurando SSL para $DOMAIN"
echo "=========================================="

# Verificar que el dominio resuelva correctamente
echo ""
echo "Verificando DNS..."
RESOLVED_IP=$(dig +short $DOMAIN | tail -n1)
CURRENT_IP=$(curl -s ifconfig.me)

echo "Dominio $DOMAIN resuelve a: $RESOLVED_IP"
echo "IP actual del servidor: $CURRENT_IP"

if [ "$RESOLVED_IP" != "$CURRENT_IP" ]; then
    echo "⚠️  ADVERTENCIA: El DNS aún no está propagado correctamente"
    echo "Espera a que el dominio resuelva a la IP correcta antes de continuar"
    read -p "¿Deseas continuar de todos modos? (y/n) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

# Instalar certbot si no está instalado
if ! command -v certbot &> /dev/null; then
    echo ""
    echo "Instalando certbot..."
    sudo apt update
    sudo apt install -y certbot python3-certbot-nginx
fi

# Obtener certificado SSL
echo ""
echo "Obteniendo certificado SSL..."
sudo certbot --nginx \
    -d $DOMAIN \
    -d www.$DOMAIN \
    --non-interactive \
    --agree-tos \
    --email $EMAIL \
    --redirect

if [ $? -eq 0 ]; then
    echo ""
    echo "✅ SSL configurado correctamente"
    echo ""
    echo "Tu sitio ahora está disponible en:"
    echo "  https://$DOMAIN"
    echo "  https://www.$DOMAIN"
    echo ""
    echo "Certbot configurará la renovación automática"
else
    echo ""
    echo "❌ Error al configurar SSL"
    echo "Verifica que:"
    echo "  1. El DNS está propagado correctamente"
    echo "  2. Los puertos 80 y 443 están abiertos en el firewall"
    echo "  3. Nginx está corriendo correctamente"
    exit 1
fi

# Verificar renovación automática
echo ""
echo "Verificando renovación automática..."
sudo certbot renew --dry-run

echo ""
echo "=========================================="
echo "¡SSL configurado exitosamente!"
echo "=========================================="
