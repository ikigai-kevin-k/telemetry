const express = require('express');
const { register, Gauge, Counter } = require('prom-client');

const app = express();
const PORT = 8080;

// Create Prometheus metrics
const videoStutterGauge = new Gauge({
  name: 'videostutter',
  help: 'Video stutter metric for studio web player',
  labelNames: ['player_id', 'video_id', 'quality']
});

const videoPlayCounter = new Counter({
  name: 'video_play_total',
  help: 'Total number of video plays',
  labelNames: ['player_id', 'video_id']
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
  // Simulate different video players
  const players = ['player-001', 'player-002', 'player-003'];
  const videos = ['video-001', 'video-002', 'video-003'];
  const qualities = ['720p', '1080p', '4K'];

  players.forEach(playerId => {
    videos.forEach(videoId => {
      qualities.forEach(quality => {
        // Generate random stutter value between 0-20
        const stutterValue = Math.random() * 20;
        videoStutterGauge.labels(playerId, videoId, quality).set(stutterValue);
        
        // Increment play counter
        videoPlayCounter.labels(playerId, videoId).inc();
      });
    });
  });
}

// Update metrics every 5 seconds
setInterval(simulateVideoStutter, 5000);

// Initial metrics
simulateVideoStutter();

app.listen(PORT, () => {
  console.log(`Metrics server running on port ${PORT}`);
  console.log(`Metrics available at: http://localhost:${PORT}/metrics`);
  console.log(`Health check at: http://localhost:${PORT}/health`);
});
