#!/bin/bash

# Wrapper de despliegue para EC2
# Uso: ./deploy.sh

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"

if [ ! -f "ec2-update.sh" ]; then
	echo "❌ No se encontró ec2-update.sh en $SCRIPT_DIR"
	exit 1
fi

chmod +x ec2-update.sh
./ec2-update.sh
