#!/usr/bin/env python3
"""
Test script to run mock_main_sicbo.py and generate logs
"""

import subprocess
import time
import os


def main():
    """Run the mock application and generate logs"""
    print("Starting mock sicbo application...")

    # Check if mock_main_sicbo.py exists
    if not os.path.exists("mock_main_sicbo.py"):
        print("Error: mock_main_sicbo.py not found!")
        return

    try:
        # Run the mock application
        process = subprocess.Popen(
            ["python3", "mock_main_sicbo.py"],
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True,
        )

        print("Mock application is running...")
        print("Logs will be written to mock_sicbo.log")
        print("Press Ctrl+C to stop")

        # Wait for the process to complete
        stdout, stderr = process.communicate()

        if process.returncode == 0:
            print("Mock application completed successfully")
        else:
            print(f"Mock application failed with return code: {process.returncode}")
            if stderr:
                print(f"Error output: {stderr}")

    except KeyboardInterrupt:
        print("\nStopping mock application...")
        process.terminate()
        process.wait()
        print("Mock application stopped")
    except Exception as e:
        print(f"Error running mock application: {str(e)}")


if __name__ == "__main__":
    main()
