#!/bin/bash
set -e

INSTALL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "=== DWIN T5UIC1 LCD Installer ==="
echo "Install directory: $INSTALL_DIR"
echo ""

read -p "Serial port [/dev/ttyAMA0]: " SERIAL_PORT
SERIAL_PORT="${SERIAL_PORT:-/dev/ttyAMA0}"

read -p "Moonraker URL [127.0.0.1]: " MOONRAKER_URL
MOONRAKER_URL="${MOONRAKER_URL:-127.0.0.1}"

read -p "Moonraker API Key (leave empty if none): " MOONRAKER_API_KEY

# Auto-detect Klippy socket from common locations
KLIPPY_SOCKET_DEFAULT=""
for candidate in \
    "$HOME/printer_data/comms/klippy.sock" \
    "/tmp/klippy_uds" \
    "/run/klipper/klippy.sock"; do
    if [ -S "$candidate" ]; then
        KLIPPY_SOCKET_DEFAULT="$candidate"
        break
    fi
done

if [ -n "$KLIPPY_SOCKET_DEFAULT" ]; then
    read -p "Klippy socket path [$KLIPPY_SOCKET_DEFAULT]: " KLIPPY_SOCKET
    KLIPPY_SOCKET="${KLIPPY_SOCKET:-$KLIPPY_SOCKET_DEFAULT}"
else
    read -p "Klippy socket path (not auto-detected, enter manually): " KLIPPY_SOCKET
fi

read -p "Reverse encoder direction? (Voxelab Aquila) [y/N]: " REVERSE_ENCODER
ENCODER_REVERSED="false"
[[ "$REVERSE_ENCODER" =~ ^[Yy]$ ]] && ENCODER_REVERSED="true"

# Write env file
sudo tee /etc/simpleLCD.env > /dev/null << EOF
INSTALL_DIR=$INSTALL_DIR
LCD_SERIAL_PORT=$SERIAL_PORT
MOONRAKER_URL=$MOONRAKER_URL
MOONRAKER_API_KEY=$MOONRAKER_API_KEY
KLIPPY_SOCKET=$KLIPPY_SOCKET
ENCODER_REVERSED=$ENCODER_REVERSED
EOF
echo "Written /etc/simpleLCD.env"

# Make scripts executable
chmod +x "$INSTALL_DIR/run.sh" "$INSTALL_DIR/restart.sh"

# Create shim at fixed path so systemd ExecStart can use an absolute path
sudo tee /usr/local/bin/simpleLCD > /dev/null << 'SHIM'
#!/bin/bash
source /etc/simpleLCD.env
exec "$INSTALL_DIR/run.sh"
SHIM
sudo chmod +x /usr/local/bin/simpleLCD
echo "Written /usr/local/bin/simpleLCD"

# Symlink service file
sudo ln -sf "$INSTALL_DIR/simpleLCD.service" /lib/systemd/system/simpleLCD.service
echo "Symlinked simpleLCD.service -> /lib/systemd/system/simpleLCD.service"

sudo systemctl daemon-reload
sudo systemctl enable simpleLCD.service

echo ""
echo "Installation complete!"
echo "Start with:     sudo systemctl start simpleLCD.service"
echo "View logs with: journalctl -u simpleLCD.service -f"
