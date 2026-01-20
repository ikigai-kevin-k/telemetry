#!/usr/bin/env python3
import re

def test_sdp_regex():
    """Test the SDP regex pattern"""
    
    # The log entry
    log_entry = """:rotating_light: SDP Error in SPEED_ROULETTE
Table: Speed Roulette
Error Code: SENSOR_STUCK
Error: SENSOR ERROR - Detected warning_flag=4 in *X;6 message
Time: 2025-09-12 08:43:13"""
    
    # The regex pattern from promtail config
    pattern = r'^:rotating_light: SDP Error in (?P<game_type>\w+)\s*Table: (?P<table_name>.*?)\s*Error Code: (?P<error_code>\w+)\s*Error: (?P<error_message>.*?)\s*Time: (?P<timestamp>\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2})'
    
    print("Testing SDP regex pattern...")
    print(f"Pattern: {pattern}")
    print(f"Log entry:\n{log_entry}")
    print("-" * 50)
    
    # Test the regex
    match = re.search(pattern, log_entry, re.MULTILINE | re.DOTALL)
    
    if match:
        print("✅ Regex match successful!")
        print(f"Game Type: {match.group('game_type')}")
        print(f"Table Name: {match.group('table_name')}")
        print(f"Error Code: {match.group('error_code')}")
        print(f"Error Message: {match.group('error_message')}")
        print(f"Timestamp: {match.group('timestamp')}")
    else:
        print("❌ Regex match failed!")
        print("The pattern doesn't match the log format.")
        
        # Try a simpler pattern
        simple_pattern = r':rotating_light: SDP Error in (?P<game_type>\w+)'
        simple_match = re.search(simple_pattern, log_entry)
        if simple_match:
            print(f"✅ Simple pattern works: {simple_match.group('game_type')}")
        else:
            print("❌ Even simple pattern fails")

if __name__ == "__main__":
    test_sdp_regex()
