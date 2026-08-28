const http = require("http");
const os = require("os");

const port = process.env.PORT || 8080;
const version = process.env.APP_VERSION || "dev";
const platform = process.env.PLATFORM || "local";

const server = http.createServer((request, response) => {
  const url = new URL(request.url, `http://${request.headers.host}`);

  if (url.pathname === "/health") {
    response.writeHead(200, { "Content-Type": "application/json" });
    response.end(JSON.stringify({ status: "ok" }));
    return;
  }

  if (url.pathname === "/cpu") {
    const end = Date.now() + 500;

    while (Date.now() < end) {
      Math.sqrt(Math.random() * 100000);
    }

    response.writeHead(200, { "Content-Type": "application/json" });
    response.end(JSON.stringify({ message: "CPU load generated" }));
    return;
  }

  response.writeHead(200, { "Content-Type": "application/json" });
  response.end(
    JSON.stringify({
      application: "orchestration-demo",
      version: version,
      platform: platform,
      instance: os.hostname()
    })
  );
});

server.listen(port, "0.0.0.0", () => {
  console.log(`Application started on port ${port}`);
});
