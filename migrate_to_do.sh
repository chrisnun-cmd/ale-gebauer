#!/bin/bash
set -e

echo "=== Migrando alegebauer.com a DigitalOcean ==="

# 1. Clonar repo
cd /var/www
if [ -d "ale-gebauer" ]; then
    echo "Directorio existe, actualizando..."
    cd ale-gebauer && git pull
else
    git clone https://github.com/chrisnun-cmd/ale-gebauer.git
    cd ale-gebauer
fi

# 2. Crear venv e instalar
python3 -m venv venv
source venv/bin/activate
pip install -q Flask gunicorn

# 3. Crear servicio systemd
cat > /etc/systemd/system/ale-gebauer.service << 'SVC'
[Unit]
Description=Ale Gebauer Landing
After=network.target

[Service]
User=root
WorkingDirectory=/var/www/ale-gebauer
ExecStart=/var/www/ale-gebauer/venv/bin/gunicorn -w 2 -b 127.0.0.1:8004 main:app
Restart=always

[Install]
WantedBy=multi-user.target
SVC

# 4. Crear config nginx
cat > /etc/nginx/sites-available/ale-gebauer << 'NGX'
server {
    listen 80;
    server_name alegebauer.com www.alegebauer.com;

    location / {
        proxy_pass http://127.0.0.1:8004;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
NGX

# 5. Activar site
ln -sf /etc/nginx/sites-available/ale-gebauer /etc/nginx/sites-enabled/

# 6. Arrancar todo
systemctl daemon-reload
systemctl enable ale-gebauer
systemctl start ale-gebauer
nginx -t && systemctl reload nginx

# 7. Verificar
sleep 3
CODE=$(curl -s -o /dev/null -w "%{http_code}" http://127.0.0.1:8004/)
echo "App status: $CODE"

if [ "$CODE" = "200" ]; then
    echo ""
    echo "=== OK - App corriendo en puerto 8004 ==="
    echo ""
    echo "PASO MANUAL:"
    echo "1. Ve al panel DNS de alegebauer.com"
    echo "2. Cambia el registro A de @ a 192.81.217.216"
    echo "3. Cambia el registro A de www a 192.81.217.216"
    echo "4. Espera 5-10 min a que propague"
    echo "5. Corre: certbot --nginx -d alegebauer.com -d www.alegebauer.com"
    echo "6. Borra el proyecto de Railway"
else
    echo "ERROR - revisar logs: journalctl -u ale-gebauer -n 20"
fi
