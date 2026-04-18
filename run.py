#!/usr/bin/env python3
import sys
from dwinlcd import DWIN_LCD

encoder_Pins = (26, 19)
button_Pin = 13
LCD_COM_Port = sys.argv[0]
# '/dev/ttyAMA0'
API_Key = sys.argv[1]
#'eb56bb488d3143708656f60074f70af0'

DWINLCD = DWIN_LCD(
        LCD_COM_Port,
        encoder_Pins,
        button_Pin,
        API_Key
)
