#!/usr/bin/env python3
import time
import random
from datetime import datetime

def generate_sdp_error_log():
    """Generate SDP error log in the specified format"""
    
    # SDP error templates
    game_types = ["SPEED_ROULETTE", "BACCARAT", "BLACKJACK", "SIC_BO"]
    error_codes = ["SENSOR_STUCK", "ZCAM_ERROR", "NETWORK_TIMEOUT", "HARDWARE_FAILURE"]
    table_names = ["Speed Roulette", "Baccarat Table", "Blackjack Table","Sic Bo Table"]
    
    # Generate random error
    game_type = random.choice(game_types)
    error_code = random.choice(error_codes)
    table_name = random.choice(table_names)
    
    # Generate error message based on error code
    error_messages = {
        "SENSOR_STUCK": f"SENSOR ERROR - Detected warning_flag={random.randint(1, 8)} in *X;{random.randint(1, 10)} message",
        "ZCAM_ERROR": f"ZCAM ERROR - Frame capture failed, retry count: {random.randint(1, 5)}",
        "NETWORK_TIMEOUT": f"NETWORK ERROR - Connection timeout after {random.randint(5, 30)}s",
        "HARDWARE_FAILURE": f"HARDWARE ERROR - Component {random.choice(['A', 'B', 'C'])} failed self-test",
    }
    
    error_message = error_messages.get(error_code, "Unknown error occurred")
    current_time = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    
    # Format the log entry
    log_entry = f""":rotating_light: SDP Error in {game_type}
Table: {table_name}
Error Code: {error_code}
Error: {error_message}
Time: {current_time}"""
    
    return log_entry

def write_sdp_logs():
    """Write SDP error logs to file"""
    print("🚀 Generating SDP error logs...")
    print("📝 Writing to sdp.log")
    print("⏰ Generating logs every 10 seconds...")
    print("🛑 Press Ctrl+C to stop")
    print("-" * 50)
    
    try:
        counter = 1
        while True:
            log_entry = generate_sdp_error_log()
            
            # Write to file
            with open("sdp.log", "a") as f:
                f.write(log_entry + "\n\n")
            
            print(f"✅ [{counter:03d}] Generated SDP error log")
            print(f"   Game: {log_entry.split('SDP Error in ')[1].split()[0]}")
            print(f"   Error: {log_entry.split('Error Code: ')[1].split()[0]}")
            print(f"   Time: {log_entry.split('Time: ')[1].strip()}")
            print()
            
            counter += 1
            time.sleep(10)  # Wait 10 seconds between logs
            
    except KeyboardInterrupt:
        print(f"\n🛑 Stopped by user")
        print(f"📊 Total SDP logs generated: {counter - 1}")

if __name__ == "__main__":
    write_sdp_logs()
