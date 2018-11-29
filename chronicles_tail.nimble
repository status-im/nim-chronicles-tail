mode = ScriptMode.Verbose

packageName   = "chronicles_tail"
version       = "0.1.0"
author        = "Status Research & Development GmbH"
description   = "Interactive filtering and visualization tool for Chronicles' JSON outputs"
license       = "Apache License 2.0"
skipDirs      = @["tests"]
installDirs   = @["chronicles_tail"]
bin           = @["ctail"]

requires "nim >= 0.18.1",
         "asynctools",
         "chronicles",
         "ranges",
         "prompt",
         "karax",
         "websocket",
         "jswebsockets"
