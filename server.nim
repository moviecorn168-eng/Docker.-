import jester
import routes

initStore()

before:
  setHeader(response, "Access-Control-Allow-Origin", "*")
  setHeader(response, "Access-Control-Allow-Methods", "GET, POST, OPTIONS")
  setHeader(response, "Access-Control-Allow-Headers", "Content-Type")

routes:
  options "/@path":
    resp Http200, ""

let settings = newSettings(port = Port(5000))
var jesterServer = initJester(settings)
jesterServer.serve()
