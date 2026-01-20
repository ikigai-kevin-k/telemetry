#!/usr/bin/env python3
import random
from datetime import datetime

def generate_single_sdp_log():
    """Generate a single SDP error log"""
    
    # Your specific SDP error
    log_entry = """:rotating_light: SDP Error in SPEED_ROULETTE
Table: Speed Roulette
Error Code: SENSOR_STUCK
Error: SENSOR ERROR - Detected warning_flag=4 in *X;6 message
Time: 2025-09-12 08:43:13"""
    
    # Write to file
    with open("sdp.log", "a") as f:
        f.write(log_entry + "\n\n")
    
    print("✅ Generated SDP error log:")
    print(log_entry)
    print("\n📝 Log written to sdp.log")

if __name__ == "__main__":
    generate_single_sdp_log()
