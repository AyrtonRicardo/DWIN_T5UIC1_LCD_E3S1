#!/usr/bin/env python3
import os
from dwinlcd import DWIN_LCD

encoder_Pins = (19, 26) if os.environ.get('ENCODER_REVERSED', 'false').lower() == 'true' else (26, 19)
button_Pin = 13
LCD_COM_Port = os.environ['LCD_SERIAL_PORT']
API_Key = os.environ.get('MOONRAKER_API_KEY', '')
MOONRAKER_URL = os.environ.get('MOONRAKER_URL', '127.0.0.1')
KLIPPY_SOCK = os.environ.get('KLIPPY_SOCKET', '~/printer_data/comms/klippy.sock')

DWINLCD = DWIN_LCD(LCD_COM_Port, encoder_Pins, button_Pin, API_Key, MOONRAKER_URL, KLIPPY_SOCK)
