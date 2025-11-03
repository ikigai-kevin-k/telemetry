#!/usr/bin/env python3
"""
eBPF Exporter for Prometheus
Monitors CPU usage, network speed, and system temperature
"""

import os
import sys
import time
import json
from http.server import HTTPServer, BaseHTTPRequestHandler
from prometheus_client import Counter, Gauge, generate_latest, CONTENT_TYPE_LATEST
import psutil

# Try to import BCC, but fallback gracefully if not available
try:
    from bcc import BPF
    BCC_AVAILABLE = True
except ImportError:
    BCC_AVAILABLE = False
    print("Warning: BCC not available. Using standard monitoring only.")

# Prometheus metrics
cpu_usage = Gauge('ebpf_cpu_usage_percent', 'CPU usage percentage per core', ['cpu'])
cpu_temperature = Gauge('ebpf_cpu_temperature_celsius', 'CPU temperature in Celsius', ['core'])
network_bytes_sent = Counter('ebpf_network_bytes_sent', 'Network bytes sent', ['interface'])
network_bytes_recv = Counter('ebpf_network_bytes_recv', 'Network bytes received', ['interface'])
network_speed_sent = Gauge('ebpf_network_speed_sent_bps', 'Network send speed in bytes per second', ['interface'])
network_speed_recv = Gauge('ebpf_network_speed_recv_bps', 'Network receive speed in bytes per second', ['interface'])
system_load = Gauge('ebpf_system_load', 'System load average', ['type'])

class MetricsHandler(BaseHTTPRequestHandler):
    """HTTP handler for Prometheus metrics endpoint"""
    
    def do_GET(self):
        if self.path == '/metrics':
            self.send_response(200)
            self.send_header('Content-Type', CONTENT_TYPE_LATEST)
            self.end_headers()
            self.wfile.write(generate_latest())
        elif self.path == '/health':
            self.send_response(200)
            self.send_header('Content-Type', 'application/json')
            self.end_headers()
            self.wfile.write(json.dumps({'status': 'healthy'}).encode())
        else:
            self.send_response(404)
            self.end_headers()
    
    def log_message(self, format, *args):
        # Suppress default log messages
        pass

class eBPFExporter:
    """Main eBPF exporter class"""
    
    def __init__(self):
        self.bpf = None
        self.running = True
        self.network_stats_prev = {}
        self.last_collection_time = time.time()
        
    def init_ebpf(self):
        """Initialize eBPF programs"""
        if not BCC_AVAILABLE:
            print("BCC not available. Using standard psutil-based monitoring.")
            return False
        
        try:
            # Load eBPF programs
            # For now, we use psutil as the primary monitoring method
            # eBPF programs can be loaded here for advanced monitoring in the future
            print("eBPF exporter initialized (using psutil-based monitoring)")
            return True
        except Exception as e:
            print(f"Warning: Could not initialize eBPF: {e}")
            print("Falling back to standard monitoring")
            return False
    
    def collect_cpu_metrics(self):
        """Collect CPU usage metrics"""
        try:
            # Get per-CPU usage
            cpu_percent = psutil.cpu_percent(interval=1, percpu=True)
            for idx, usage in enumerate(cpu_percent):
                cpu_usage.labels(cpu=str(idx)).set(usage)
            
            # Get system load
            load_avg = os.getloadavg()
            system_load.labels(type='1min').set(load_avg[0])
            system_load.labels(type='5min').set(load_avg[1])
            system_load.labels(type='15min').set(load_avg[2])
        except Exception as e:
            print(f"Error collecting CPU metrics: {e}")
    
    def collect_temperature_metrics(self):
        """Collect CPU temperature metrics"""
        try:
            if hasattr(psutil, "sensors_temperatures"):
                temps = psutil.sensors_temperatures()
                core_idx = 0
                
                for name, entries in temps.items():
                    if 'core' in name.lower() or 'cpu' in name.lower():
                        for entry in entries:
                            if entry.current is not None:
                                cpu_temperature.labels(core=f'core{core_idx}').set(entry.current)
                                core_idx += 1
            else:
                # Try reading from /sys/class/thermal
                thermal_path = "/sys/class/thermal"
                if os.path.exists(thermal_path):
                    for idx, thermal_zone in enumerate(os.listdir(thermal_path)):
                        temp_file = os.path.join(thermal_path, thermal_zone, "temp")
                        if os.path.exists(temp_file):
                            try:
                                with open(temp_file, 'r') as f:
                                    temp_millidegrees = int(f.read().strip())
                                    temp_celsius = temp_millidegrees / 1000.0
                                    cpu_temperature.labels(core=f'thermal_zone{idx}').set(temp_celsius)
                            except Exception:
                                pass
        except Exception as e:
            print(f"Error collecting temperature metrics: {e}")
    
    def collect_network_metrics(self):
        """Collect network speed metrics"""
        try:
            current_time = time.time()
            time_delta = current_time - self.last_collection_time
            
            if time_delta <= 0:
                return
            
            net_io = psutil.net_io_counters(pernic=True)
            
            for interface, stats in net_io.items():
                # Calculate speed
                if interface in self.network_stats_prev:
                    prev_stats = self.network_stats_prev[interface]
                    bytes_sent_delta = stats.bytes_sent - prev_stats['bytes_sent']
                    bytes_recv_delta = stats.bytes_recv - prev_stats['bytes_recv']
                    
                    speed_sent = bytes_sent_delta / time_delta
                    speed_recv = bytes_recv_delta / time_delta
                    
                    network_speed_sent.labels(interface=interface).set(speed_sent)
                    network_speed_recv.labels(interface=interface).set(speed_recv)
                else:
                    network_speed_sent.labels(interface=interface).set(0)
                    network_speed_recv.labels(interface=interface).set(0)
                
                # Update counters
                network_bytes_sent.labels(interface=interface)._value._value = stats.bytes_sent
                network_bytes_recv.labels(interface=interface)._value._value = stats.bytes_recv
                
                # Store current stats for next iteration
                self.network_stats_prev[interface] = {
                    'bytes_sent': stats.bytes_sent,
                    'bytes_recv': stats.bytes_recv
                }
            
            self.last_collection_time = current_time
            
        except Exception as e:
            print(f"Error collecting network metrics: {e}")
    
    def collect_metrics(self):
        """Main metrics collection loop"""
        while self.running:
            try:
                self.collect_cpu_metrics()
                self.collect_temperature_metrics()
                self.collect_network_metrics()
                time.sleep(5)  # Collect every 5 seconds
            except KeyboardInterrupt:
                self.running = False
                break
            except Exception as e:
                print(f"Error in metrics collection: {e}")
                time.sleep(5)
    
    def run(self, port=9300):
        """Run the exporter"""
        # Start metrics collection thread
        import threading
        collector_thread = threading.Thread(target=self.collect_metrics, daemon=True)
        collector_thread.start()
        
        # Start HTTP server
        server = HTTPServer(('0.0.0.0', port), MetricsHandler)
        print(f"eBPF Exporter running on port {port}")
        print(f"Metrics endpoint: http://0.0.0.0:{port}/metrics")
        
        try:
            server.serve_forever()
        except KeyboardInterrupt:
            print("\nShutting down...")
            self.running = False
            server.shutdown()

def main():
    """Main entry point"""
    exporter = eBPFExporter()
    exporter.init_ebpf()
    
    port = int(os.environ.get('EXPORTER_PORT', '9300'))
    exporter.run(port)

if __name__ == '__main__':
    main()

