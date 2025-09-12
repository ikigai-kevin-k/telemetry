#!/usr/bin/env python3
from datetime import datetime

def generate_simple_sdp_log():
    """Generate a simple single-line SDP error log"""
    
    # Simple single-line format
    current_time = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    log_entry = f"{current_time} - SDP - ERROR - SPEED_ROULETTE - Speed Roulette - SENSOR_STUCK - SENSOR ERROR - Detected warning_flag=4 in *X;6 message"
    
    # Write to file
    with open("sdp.log", "a") as f:
        f.write(log_entry + "\n")
    
    print("✅ Generated simple SDP error log:")
    print(log_entry)
    print("\n📝 Log written to sdp.log")

if __name__ == "__main__":
    generate_simple_sdp_log()
