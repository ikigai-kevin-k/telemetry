const express = require('express');
const { register, Gauge, Counter } = require('prom-client');

const app = express();
const PORT = 8080;

// Create Prometheus metrics
const videoStutterGauge = new Gauge({
  name: 'videostutter',
  help: 'Video stutter metric for studio web player',
  labelNames: ['table_id', 'cdn_id', 'quality']
});

const videoPlayCounter = new Counter({
  name: 'video_play_total',
  help: 'Total number of video plays',
  labelNames: ['table_id', 'cdn_id']
});

// Register metrics
register.registerMetric(videoStutterGauge);
register.registerMetric(videoPlayCounter);

// Metrics endpoint
app.get('/metrics', async (req, res) => {
  try {
    res.set('Content-Type', register.contentType);
    res.end(await register.metrics());
  } catch (err) {
    res.status(500).end(err);
  }
});

// Health check endpoint
app.get('/health', (req, res) => {
  res.json({ status: 'OK', timestamp: new Date().toISOString() });
});

// Simulate video stutter metrics
function simulateVideoStutter() {
  // Simulate different tables
  const tables = ['ARO-001', 'ARO-002', 'SBO-001'];
  const cdns = ['byteplus', 'tencent'];
  const qualities = ['HD', 'Hi', 'Me', 'Lo'];

  tables.forEach(tableId => {
    cdns.forEach(cdnId => {
      qualities.forEach(quality => {
        // Generate random stutter value between 0-20 (integer)
        const stutterValue = Math.floor(Math.random() * 21);
        videoStutterGauge.labels(tableId, cdnId, quality).set(stutterValue);
        
        // Increment play counter
        videoPlayCounter.labels(tableId, cdnId).inc();
      });
    });
  });
}

// Update metrics every 30 seconds
setInterval(simulateVideoStutter, 30000);

// Initial metrics
simulateVideoStutter();

app.listen(PORT, () => {
  console.log(`Metrics server running on port ${PORT}`);
  console.log(`Metrics available at: http://localhost:${PORT}/metrics`);
  console.log(`Health check at: http://localhost:${PORT}/health`);
});
