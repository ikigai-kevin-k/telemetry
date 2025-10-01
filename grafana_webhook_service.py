#!/usr/bin/env python3
"""
Grafana Webhook Service for SRS Log Monitoring
Receives alerts from Grafana and triggers API calls when okbps=0,0,0 is detected
"""

from flask import Flask, request, jsonify
import requests
import logging
import json
from datetime import datetime

app = Flask(__name__)

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
    handlers=[
        logging.StreamHandler()
    ]
)
logger = logging.getLogger(__name__)

# Configuration
API_ENDPOINT = "http://localhost:8085/v1/service/status"
API_SIGNATURE = "rgs-local-signature"


@app.route('/health', methods=['GET'])
def health_check():
    """Health check endpoint"""
    return jsonify({"status": "healthy", "timestamp": datetime.now().isoformat()}), 200


@app.route('/webhook/grafana', methods=['POST'])
def grafana_webhook():
    """
    Receive Grafana alert webhook and trigger API call
    """
    try:
        # Log incoming webhook
        alert_data = request.json
        logger.info(f"Received Grafana alert: {json.dumps(alert_data, indent=2)}")
        
        # Extract alert information
        if not alert_data:
            logger.error("No alert data received")
            return jsonify({"error": "No alert data received"}), 400
        
        # Get alert status
        status = alert_data.get('status', '')
        alerts = alert_data.get('alerts', [])
        
        logger.info(f"Alert status: {status}")
        logger.info(f"Number of alerts: {len(alerts)}")
        
        # Process firing alerts
        if status == 'firing':
            for alert in alerts:
                alert_name = alert.get('labels', {}).get('alertname', 'Unknown')
                logger.info(f"Processing alert: {alert_name}")
                
                # Check if it's the SRS alert (check rulename or service label)
                rule_name = alert.get('labels', {}).get('rulename', '')
                service = alert.get('labels', {}).get('service', '')
                
                if 'okbps' in alert_name.lower() or 'okbps' in rule_name.lower() or service == 'srs':
                    # Extract table ID from annotations or labels
                    table_id = alert.get('annotations', {}).get('table_id', 'ARO-001')
                    
                    logger.info(f"Triggering API call for SRS alert - table: {table_id}")
                    
                    # Send API request
                    success = send_status_update(table_id, 'down')
                    
                    if success:
                        logger.info(f"Successfully sent status update for table {table_id}")
                    else:
                        logger.error(f"Failed to send status update for table {table_id}")
        
        elif status == 'resolved':
            # Optional: Handle resolved alerts (set status to 'up')
            for alert in alerts:
                alert_name = alert.get('labels', {}).get('alertname', 'Unknown')
                logger.info(f"Alert resolved: {alert_name}")
                
                if 'okbps' in alert_name.lower() or alert_name == 'SRSNoDataAlert':
                    table_id = alert.get('annotations', {}).get('table_id', 'ARO-001')
                    # Optionally send 'up' status when resolved
                    # send_status_update(table_id, 'up')
        
        return jsonify({"status": "success", "message": "Alert processed"}), 200
    
    except Exception as e:
        logger.error(f"Error processing webhook: {str(e)}", exc_info=True)
        return jsonify({"error": str(e)}), 500


def send_status_update(table_id: str, status: str) -> bool:
    """
    Send PATCH request to update service status
    
    Args:
        table_id: Table identifier (e.g., 'ARO-001')
        status: Status to set ('up' or 'down')
    
    Returns:
        bool: True if successful, False otherwise
    """
    try:
        headers = {
            'accept': 'application/json',
            'x-signature': API_SIGNATURE,
            'Content-Type': 'application/json'
        }
        
        payload = {
            "tableId": table_id,
            "zCam": status
        }
        
        logger.info(f"Sending API request to {API_ENDPOINT}")
        logger.info(f"Payload: {json.dumps(payload, indent=2)}")
        
        response = requests.patch(
            API_ENDPOINT,
            headers=headers,
            json=payload,
            timeout=10
        )
        
        logger.info(f"API Response Status: {response.status_code}")
        logger.info(f"API Response Body: {response.text}")
        
        if response.status_code in [200, 201, 204]:
            return True
        else:
            logger.error(f"API request failed with status {response.status_code}")
            return False
            
    except requests.exceptions.RequestException as e:
        logger.error(f"API request error: {str(e)}", exc_info=True)
        return False
    except Exception as e:
        logger.error(f"Unexpected error in send_status_update: {str(e)}", exc_info=True)
        return False


@app.route('/test', methods=['POST'])
def test_endpoint():
    """
    Test endpoint to manually trigger status update
    Usage: curl -X POST http://localhost:5000/test -H "Content-Type: application/json" -d '{"tableId": "ARO-001", "status": "down"}'
    """
    try:
        data = request.json
        table_id = data.get('tableId', 'ARO-001')
        status = data.get('status', 'down')
        
        success = send_status_update(table_id, status)
        
        if success:
            return jsonify({"status": "success", "message": f"Status update sent for {table_id}"}), 200
        else:
            return jsonify({"status": "error", "message": "Failed to send status update"}), 500
            
    except Exception as e:
        logger.error(f"Test endpoint error: {str(e)}", exc_info=True)
        return jsonify({"error": str(e)}), 500


if __name__ == '__main__':
    logger.info("Starting Grafana Webhook Service...")
    logger.info(f"API Endpoint: {API_ENDPOINT}")
    logger.info(f"Listening on http://0.0.0.0:5000")
    
    # Run Flask app
    app.run(host='0.0.0.0', port=5000, debug=False)

