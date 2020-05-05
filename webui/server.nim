import
  macros, json, random, times, strutils, os,
  asynchttpserver, asyncnet, asyncdispatch, websocket,
  ../chronicles_tail/configuration

const
  indexFile = staticRead "karax_app.html"
  faviconBytes = staticRead "favicon.png"

template fileContents(file: string): string =
  when defined(debug):
    readFile("webui" / file)
  else:
    const contents = staticRead(file)
    contents

type
  WebuiServer* = ref object
    httpServer: AsyncHttpServer
    plugins*: seq[string]
    accessToken: string
    port: int
    clients: seq[AsyncWebSocket]
    logLines: seq[string]

proc newServer*(port: int): WebuiServer =
  new result
  result.port = port
  result.httpServer = newAsyncHttpServer()
  result.plugins = newSeq[string]()
  result.logLines = newSeq[string]()
  result.accessToken = newStringOfCap(32)
  for i in 0..31:
    result.accessToken.add char(rand(ord('a')..ord('z')))

proc serve*(s: WebuiServer): Future[void] =
  proc cb(req: Request) {.async, gcsafe.} =
    case req.url.path
    of "/chronicles-stream":
      let (ws, error) = await verifyWebsocketRequest(req)
      if ws.isNil:
        echo "WS negotiation failed: ", error
        await req.respond(Http400, "Websocket negotiation failed: " & $error)
        req.client.close()
      else:
        var userCredentials = await ws.readData()
        if userCredentials.opcode != Opcode.Text or
           userCredentials.data != s.accessToken:
          await ws.close()
          return

        var nextLineToSend = 0
        while nextLineToSend < s.logLines.len:
          await ws.sendText(s.logLines[nextLineToSend], maskingKey = "")
          inc nextLineToSend

        s.clients.add ws

    of "/":
      await req.respond(Http200, indexFile)

    of "/styles.css":
     await req.respond(Http200, fileContents("styles.css"),
                      newHttpHeaders({"Content-Type": "text/css"}))

    of "/eth_p2p_plugin.js":
      await req.respond(Http200, readFile("webui/eth_p2p_plugin.js"),
                        newHttpHeaders({"Content-Type": "application/javascript"}))

    of "/karax_app.js":
      var scripts = newStringOfCap(16000)

      scripts.add """
        var chroniclesCredentials = {
          "url": "ws://localhost:$1/chronicles-stream",
          "accessToken": "$2"
        };
      """ % [$s.port, s.accessToken]

      scripts.add compileJs("karax_app.nim", "-d:createChroniclesTail")

      # for plugin in s.plugins:
      #  scripts.add plugin

      await req.respond(Http200, scripts,
                        newHttpHeaders({"Content-Type": "application/javascript"}))

    of "/favicon.png":
      await req.respond(Http200, faviconBytes,
                        newHttpHeaders({"Content-Type": "image/png"}))

    else:
      echo "IGNORED REQUEST: ", req.url.path

  return s.httpServer.serve(Port(s.port), cb)

proc broadcastLine*(s: WebuiServer, jsonLine: string) =
  s.logLines.add jsonLine
  for ws in s.clients:
    let f = ws.sendText(jsonLine)
    f.callback = proc =
      if f.failed:
        let pos = s.clients.find(ws)
        if pos != -1: s.clients.delete(pos)
        asyncCheck ws.close()
