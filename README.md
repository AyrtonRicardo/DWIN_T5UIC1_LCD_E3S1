# DWIN_T5UIC1_LCD_E3S1

## Python class for the Ender 3 V2 and Ender 3 S1 LCD runing klipper3d with Moonraker 

https://www.klipper3d.org

https://octoprint.org/

https://github.com/arksine/moonraker


## Setup:

### [Disable Linux serial console](https://www.raspberrypi.org/documentation/configuration/uart.md)
  By default, the primary UART is assigned to the Linux console. If you wish to use the primary UART for other purposes, you must reconfigure Raspberry Pi OS. This can be done by using raspi-config:

  * Start raspi-config: `sudo raspi-config.`
  * Select option 3 - Interface Options.
  * Select option P6 - Serial Port.
  * At the prompt Would you like a login shell to be accessible over serial? answer 'No'
  * At the prompt Would you like the serial port hardware to be enabled? answer 'Yes'
  * Exit raspi-config and reboot the Pi for changes to take effect.
  
  For full instructions on how to use Device Tree overlays see [this page](https://www.raspberrypi.org/documentation/configuration/device-tree.md). 
  
  In brief, add a line to the `/boot/config.txt` file to apply a Device Tree overlay.
    
    dtoverlay=disable-bt

### Check if Klipper's Application Programmer Interface (API) is enabled

Open klipper.service and check ([Service]... ExecStart=...) if klipper.py is started with the -a parameter

```
sudo nano /etc/systemd/system/klipper.service
```

If not, add it and reboot your pi.

Example of my klipper.service:

```bash
#Systemd service file for klipper

[Unit]
Description=Starts klipper on startup
After=network.target

[Install]
WantedBy=multi-user.target

[Service]
Type=simple
User=pi
RemainAfterExit=yes
ExecStart=/home/pi/klippy-env/bin/python /home/pi/klipper/klippy/klippy.py /home/pi/klipper_config/printer.cfg -l /home/pi/klipper_logs/klippy.log -a /tmp/klippy_uds
Restart=always
RestartSec=10
```

### Library requirements 

  Thanks to [wolfstlkr](https://www.reddit.com/r/ender3v2/comments/mdtjvk/octoprint_klipper_v2_lcd/gspae7y)

  `sudo apt-get install python3-pip python3-gpiozero python3-serial git`

  `sudo pip3 install multitimer`

  `git clone https://github.com/RobRobM/DWIN_T5UIC1_LCD_E3S1.git`


### Wire the display 

<img src ="images/Raspberry_Pi_GPIO.png?raw=true" width="800" height="572">

  * Display <-> Raspberry Pi GPIO BCM
  * Rx  =   GPIO14  (Tx)
  * Tx  =   GPIO15  (Rx)
  * Ent =   GPIO13
  * A   =   GPIO19
  * B   =   GPIO26
  * Vcc =   2   (5v)
  * Gnd =   6   (GND)

<img src ="images/GPIO.png?raw=true" width="325" height="75">

Here's a diagram based on my color selection:

<img src ="images/GPIO.png?raw=true" width="325" height="75">

I tried to take some images to help out with this: You don't have to use the color of wiring that I used:

<img src ="images/wire1.jpg?raw=true" width="492" height="208"> 
<img src ="images/wire2.jpg?raw=true" width="492" height="208">


<img src ="images/wire3.png?raw=true" width="400" height="200">

<img src ="images/wire4.png?raw=true" width="400" height="300">

I have added some Ender 3S1 specific images:

<img src ="images/Ender3S1_LCD_Board.JPG?raw=true" width="325" height="200">
<img src ="images/Ender3S1_LCD_plug.jpg?raw=true" width="325" height="220">

### Install

Enter the downloaded DWIN_T5UIC1_LCD_E3S1 folder and run the install script:

```bash
chmod +x install.sh
./install.sh
```

The installer will prompt for:

| Prompt | Default | Description |
|---|---|---|
| Serial port | `/dev/ttyAMA0` | UART port the LCD is connected to |
| Moonraker URL | `127.0.0.1` | IP or hostname of your Moonraker instance |
| Moonraker API Key | *(none)* | Leave empty if your Moonraker doesn't require one |
| Klippy socket path | `~/printer_data/comms/klippy.sock` | Path to the Klipper Unix socket |
| Reverse encoder | `N` | Answer `y` for Voxelab Aquila (reversed control wheel) |

To get your Moonraker API key run:

```bash
~/moonraker/scripts/fetch-apikey.sh
```

The installer writes all configuration to `/etc/simpleLCD.env`:

```ini
INSTALL_DIR=/path/to/DWIN_T5UIC1_LCD_E3S1
LCD_SERIAL_PORT=/dev/ttyAMA0
MOONRAKER_URL=127.0.0.1
MOONRAKER_API_KEY=your_key_here
KLIPPY_SOCKET=~/printer_data/comms/klippy.sock
ENCODER_REVERSED=false
```

To change any setting later, edit `/etc/simpleLCD.env` and restart the service:

```bash
sudo nano /etc/simpleLCD.env
sudo systemctl restart simpleLCD.service
```

### Run manually

```bash
source /etc/simpleLCD.env
python3 run.py
```

Expected output:

```
DWIN handshake
DWIN OK.
http://127.0.0.1:80
Waiting for connect to ~/printer_data/comms/klippy.sock

Connection.

Boot looks good
Testing Web-services
Web site exists
```

Press `Ctrl+C` to exit.

# Run at boot

The install script registers `simpleLCD.service` as a systemd service via a symlink to the repo file — no copy is made, so changes to the service file take effect after a `daemon-reload`.

The service loads `/etc/simpleLCD.env` via `EnvironmentFile=` and waits 20 s after boot before starting to allow Moonraker to settle. `run.sh` will re-launch `run.py` up to 5 times if it crashes within 30 seconds (e.g. on a Klipper firmware restart).

```bash
sudo systemctl start simpleLCD.service   # start now
sudo systemctl status simpleLCD.service  # check status
journalctl -u simpleLCD.service -f       # follow logs
```

# Status:

## Working:

 Print Menu:
 
    * List / Print jobs from OctoPrint / Moonraker
    * Auto swiching from to Print Menu on job start / end.
    * Display Print time, Progress, Temps, and Job name.
    * Pause / Resume / Cancle Job
    * Tune Menu: Print speed & Temps

 Perpare Menu:
 
    * Move / Jog toolhead
    * Disable stepper
    * Auto Home
    * Z offset (PROBE_CALIBRATE)
    * Preheat
    * cooldown
 
 Info Menu

    * Shows printer info.
    * Trigger bed mesh calibration (BED_MESH_CALIBRATE).

## Notworking:
    * Save / Loding Preheat setting, hardcode on start can be changed in menu but will not retane on restart.
    * The Control: Motion Menu
