const express = require('express');
const app = express();
const PORT = process.env.PORT || 3001;

app.get('/api/health', (req, res) => {
  res.json({ status: 'ok', service: 'micro-api' });
});

app.get('/api/data', (req, res) => {
  // simulate business API
  res.json({ msg: 'Here is some business data', timestamp: Date.now() });
});

app.get('/', (req, res) => {
  res.json({ service: 'micro-api', routes: ['/api/health', '/api/data']});
});

app.listen(PORT, () => console.log(`micro-api listening on ${PORT}`));
