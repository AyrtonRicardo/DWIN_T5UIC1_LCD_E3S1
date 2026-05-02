#!/bin/bash
set -e

INSTALL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "=== DWIN T5UIC1 LCD Installer ==="
echo "Install directory: $INSTALL_DIR"
echo ""

# Load existing config as defaults if present
if [ -f /etc/simpleLCD.env ]; then
    source /etc/simpleLCD.env
    echo "(Found existing /etc/simpleLCD.env — using its values as defaults)"
    echo ""
fi

read -p "Serial port [${LCD_SERIAL_PORT:-/dev/ttyAMA0}]: " INPUT
LCD_SERIAL_PORT="${INPUT:-${LCD_SERIAL_PORT:-/dev/ttyAMA0}}"

read -p "Moonraker URL [${MOONRAKER_URL:-127.0.0.1}]: " INPUT
MOONRAKER_URL="${INPUT:-${MOONRAKER_URL:-127.0.0.1}}"

read -p "Moonraker API Key [${MOONRAKER_API_KEY:-(none)}]: " INPUT
MOONRAKER_API_KEY="${INPUT:-${MOONRAKER_API_KEY:-}}"

# Auto-detect Klippy socket from common locations, fall back to existing value
KLIPPY_SOCKET_DEFAULT="${KLIPPY_SOCKET:-}"
for candidate in \
    "$HOME/printer_data/comms/klippy.sock" \
    "/tmp/klippy_uds" \
    "/run/klipper/klippy.sock"; do
    if [ -S "$candidate" ]; then
        KLIPPY_SOCKET_DEFAULT="$candidate"
        break
    fi
done

read -p "Klippy socket path [${KLIPPY_SOCKET_DEFAULT}]: " INPUT
KLIPPY_SOCKET="${INPUT:-${KLIPPY_SOCKET_DEFAULT}}"

ENCODER_REVERSED_DEFAULT="${ENCODER_REVERSED:-false}"
read -p "Reverse encoder direction? (Voxelab Aquila) [${ENCODER_REVERSED_DEFAULT}]: " INPUT
if [ -n "$INPUT" ]; then
    [[ "$INPUT" =~ ^[Yy]$ ]] && ENCODER_REVERSED="true" || ENCODER_REVERSED="false"
else
    ENCODER_REVERSED="$ENCODER_REVERSED_DEFAULT"
fi

# Check for an existing system-level service and offer to migrate
SYSTEM_SERVICE_FOUND=false
for f in /lib/systemd/system/simpleLCD.service /etc/systemd/system/simpleLCD.service; do
    [ -f "$f" ] && SYSTEM_SERVICE_FOUND=true && break
done

if $SYSTEM_SERVICE_FOUND; then
    echo ""
    echo "Found a system-level simpleLCD.service."
    read -p "Convert it to a user-level service (recommended for input shaper)? [Y/n]: " INPUT
    if [[ -z "$INPUT" || "$INPUT" =~ ^[Yy]$ ]]; then
        echo "Removing old system-level service..."
        sudo systemctl disable --now simpleLCD.service 2>/dev/null || true
        sudo rm -f /lib/systemd/system/simpleLCD.service /etc/systemd/system/simpleLCD.service
        sudo systemctl daemon-reload
        echo "Done."
    else
        echo "Keeping system-level service. Installer will still update env file and shim."
        echo "Note: you will need sudo to stop/start the service."
    fi
    echo ""
fi

# Write env file (system-wide so the shim and manual runs can both find it)
sudo tee /etc/simpleLCD.env > /dev/null << EOF
INSTALL_DIR=$INSTALL_DIR
LCD_SERIAL_PORT=$LCD_SERIAL_PORT
MOONRAKER_URL=$MOONRAKER_URL
MOONRAKER_API_KEY=$MOONRAKER_API_KEY
KLIPPY_SOCKET=$KLIPPY_SOCKET
ENCODER_REVERSED=$ENCODER_REVERSED
EOF
echo "Written /etc/simpleLCD.env"

# Make scripts executable
chmod +x "$INSTALL_DIR/run.sh" "$INSTALL_DIR/restart.sh"

# Create shim at fixed path so the service ExecStart is an absolute path
sudo tee /usr/local/bin/simpleLCD > /dev/null << 'SHIM'
#!/bin/bash
source /etc/simpleLCD.env
exec "$INSTALL_DIR/run.sh"
SHIM
sudo chmod +x /usr/local/bin/simpleLCD
echo "Written /usr/local/bin/simpleLCD"

# Install as a user-level service
mkdir -p "$HOME/.config/systemd/user"
ln -sf "$INSTALL_DIR/simpleLCD.service" "$HOME/.config/systemd/user/simpleLCD.service"
echo "Symlinked simpleLCD.service -> $HOME/.config/systemd/user/simpleLCD.service"

systemctl --user daemon-reload
systemctl --user enable simpleLCD.service

# Allow the user service to start at boot (without an interactive login session)
loginctl enable-linger "$USER"

echo ""
echo "Installation complete!"
echo "Start with:     systemctl --user start simpleLCD.service"
echo "Stop with:      systemctl --user stop simpleLCD.service"
echo "Restart with:   systemctl --user restart simpleLCD.service"
echo "View logs with: journalctl --user -u simpleLCD.service -f"
echo ""
echo "To stop the LCD before running input shaper from a shell:"
echo "  systemctl --user stop simpleLCD.service"
echo "  # run input shaper tests"
echo "  systemctl --user start simpleLCD.service"
