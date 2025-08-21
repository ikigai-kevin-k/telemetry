// Test script for Pushgateway
const fetch = (...args) => import('node-fetch').then(({default: fetch}) => fetch(...args));

class PrometheusClient {
  constructor(pushgatewayUrl = 'http://localhost:9091') {
    this.pushgatewayUrl = pushgatewayUrl;
    this.jobName = 'studio-web-player';
  }

  async sendMetric(metricName, value, labels = {}) {
    const metricData = this.formatMetric(metricName, value, labels);
    const url = `${this.pushgatewayUrl}/metrics/job/${this.jobName}`;
    
    try {
      const response = await fetch(url, {
        method: 'POST',
        headers: {
          'Content-Type': 'text/plain',
        },
        body: metricData
      });
      
      if (response.ok) {
        console.log(`✅ Metric sent successfully: ${metricName} = ${value}`);
        return true;
      } else {
        console.error(`❌ Failed to send metric: ${response.status} ${response.statusText}`);
        return false;
      }
    } catch (error) {
      console.error(`❌ Error sending metric:`, error);
      return false;
    }
  }

  async sendVideoStutter(tableId, cdnId, quality, value) {
    const labels = {
      table_id: tableId,
      cdn_id: cdnId,
      quality: quality
    };
    
    return await this.sendMetric('videostutter', value, labels);
  }

  formatMetric(name, value, labels = {}) {
    let metricLine = name;
    
    if (Object.keys(labels).length > 0) {
      const labelPairs = Object.entries(labels)
        .map(([key, value]) => `${key}="${value}"`)
        .join(',');
      metricLine += `{${labelPairs}}`;
    }
    
    metricLine += ` ${value}`;
    
    return metricLine;
  }
}

async function testPushgateway() {
  console.log('🚀 Testing Pushgateway with multiple metrics...');
  
  const client = new PrometheusClient();
  
  // Send multiple videostutter metrics
  const metrics = [
    { tableId: 'ARO-001', cdnId: 'byteplus', quality: 'HD', value: 8 },
    { tableId: 'ARO-002', cdnId: 'tencent', quality: 'Hi', value: 12 },
    { tableId: 'SBO-001', cdnId: 'cdnnetwork', quality: 'Me', value: 15 },
    { tableId: 'BCR-001', cdnId: 'byteplus', quality: 'Lo', value: 3 },
    { tableId: 'ARO-001', cdnId: 'tencent', quality: 'HD', value: 18 },
    { tableId: 'ARO-002', cdnId: 'cdnnetwork', quality: 'Hi', value: 7 }
  ];
  
  let successCount = 0;
  
  for (const metric of metrics) {
    const success = await client.sendVideoStutter(
      metric.tableId, 
      metric.cdnId, 
      metric.quality, 
      metric.value
    );
    if (success) successCount++;
    
    // Wait a bit between requests
    await new Promise(resolve => setTimeout(resolve, 100));
  }
  
  console.log(`\n📊 Results: ${successCount}/${metrics.length} metrics sent successfully`);
  
  if (successCount === metrics.length) {
    console.log('🎉 All metrics sent successfully!');
    console.log('🔍 Check Prometheus in a few seconds to see the new metrics');
  } else {
    console.log('⚠️ Some metrics failed to send');
  }
}

// Run the test
testPushgateway().catch(console.error);
