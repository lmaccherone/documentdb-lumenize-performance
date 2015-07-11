restify = require("restify")

run = require('./src/run')

port = process.env.PORT or 1338

server = restify.createServer()
server.get("/", run.run)

server.listen(port, () ->
  console.log("%s listening at %s", server.name, server.url)
)

