FROM ubuntu:22.04

# Avoid interactive prompts during build
ENV DEBIAN_FRONTEND=noninteractive

# Install dependencies
RUN apt-get update && apt-get install -y \
    python3 \
    python3-pip \
    python3-dev \
    bpfcc-tools \
    python3-bpfcc \
    libbpfcc \
    linux-headers-generic \
    curl \
    && rm -rf /var/lib/apt/lists/*

# Set working directory
WORKDIR /app

# Copy requirements and install Python packages
COPY requirements.txt .
RUN pip3 install --no-cache-dir -r requirements.txt

# Copy application files
COPY ebpf_exporter.py .
COPY ebpf_cpu_monitor.c .
COPY ebpf_network_monitor.c .

# Make script executable
RUN chmod +x ebpf_exporter.py

# Expose metrics port
EXPOSE 9300

# Run the exporter
CMD ["python3", "ebpf_exporter.py"]

