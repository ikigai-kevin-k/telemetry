#!/usr/bin/env python3
"""
Mock Sicbo Main Application
This is a temporary replacement for main_sicbo.py that only includes logging functionality
"""

import logging
import sys
import time
from datetime import datetime


# Configure logging
def setup_logger():
    """Setup logger configuration for the application"""
    logger = logging.getLogger("mock_sicbo")
    logger.setLevel(logging.INFO)

    # Create formatter
    formatter = logging.Formatter(
        "%(asctime)s - %(name)s - %(levelname)s - %(message)s",
        datefmt="%Y-%m-%d %H:%M:%S",
    )

    # Create console handler
    console_handler = logging.StreamHandler(sys.stdout)
    console_handler.setLevel(logging.INFO)
    console_handler.setFormatter(formatter)

    # Create file handler
    file_handler = logging.FileHandler("mock_sicbo.log")
    file_handler.setLevel(logging.INFO)
    file_handler.setFormatter(formatter)

    # Add handlers to logger
    logger.addHandler(console_handler)
    logger.addHandler(file_handler)

    return logger


def main():
    """Main function that simulates the sicbo application with logging"""
    logger = setup_logger()

    logger.info("Mock Sicbo application started")
    logger.info("This is a temporary replacement for main_sicbo.py")

    try:
        # Simulate some application logic
        logger.info("Initializing application components...")
        time.sleep(1)

        logger.info("Loading configuration...")
        time.sleep(0.5)

        logger.info("Starting mock game server...")
        time.sleep(1)

        # Simulate periodic logging
        for i in range(5):
            logger.info(f"Mock game round {i+1} completed")
            logger.debug(f"Round {i+1} statistics: wins=3, losses=2, draws=1")
            time.sleep(2)

        logger.info("Mock Sicbo application completed successfully")

    except Exception as e:
        logger.error(f"Error occurred in mock application: {str(e)}")
        sys.exit(1)


if __name__ == "__main__":
    main()
