const http = require('http');
const port = process.env.PORT || 8080;

const server = http.createServer((req, res) => {
  res.writeHead(200, {'Content-Type': 'text/plain'});
  res.end('Hello World from Elastic Beanstalk!\n');
});

server.listen(port, () => {
  console.log(`Server running on port ${port}`);
});

