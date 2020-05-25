import
  jsffi, dom, strformat, jsconsole, jscore

proc indexOf*(a, b: cstring): int {.importcpp, nodecl.}
proc slice*(s: cstring; istart: int): cstring {.importcpp, nodecl.}
proc slice*(s: cstring; istart, iend: int): cstring {.importcpp, nodecl.}
proc split*(s, sep: cstring): seq[cstring] {.importcpp, nodecl.}
proc split*(s, sep: cstring; max: int): seq[cstring] {.importcpp, nodecl.}
proc replace*(s: cstring, pattern: auto,
              replacement: cstring): cstring {.importcpp, nodecl.}
proc toLowerCase*(s: cstring): cstring {.importcpp, nodecl.}
proc toCString*(s: js): cstring {.importcpp: "#.toString()".}

type
  js = JsObject

var
  bs = require("browser-sync").create()
  p = require "path"
  child_process = require "child_process"

var options = js{
  host: cstring "127.0.0.1",
  port: 9700,
  ui: js{ port: 9701 },
  localOnly: true,
  plugins: []
}

var
  RegExp* {.importc.}: proc (source: cstring, flag: cstring): js

template len(o: js): int = cast[int](o.length)

{.push stackTrace:off.}
proc browserCode(bs: js) =

  proc splitUrl(url: cstring): js =
    var url = url
    var hash, params: cstring

    let hashtagIdx = url.indexOf("#")
    if hashtagIdx >= 0:
      hash = url.slice(hashtagIdx)
      url = url.slice(0, hashtagIdx)
    else:
      hash = ""

    let paramIdx = url.indexOf("?")
    if paramIdx >= 0:
      params = url.slice(paramIdx)
      url = url.slice(0, paramIdx)
    else:
      params = ""

    return js{
      url: url,
      params: params,
      hash: hash
    }

  proc pathFromUrl(url: cstring): cstring =
    var url = cast[cstring](splitUrl(url).url)
    var path: cstring
    if url.indexOf("file://") == 0:
      path = url.replace(jsnew RegExp("^file://(localhost)?", ""), "")
    else:
      #                                 http:  // hostname:8080 /
      path = url.replace(jsnew RegExp("^([^:]+:)?//([^:/]+)(:\\d*)?", ""), "/")

    # decodeURI has special handling of characters such as
    # semicolons, so use decodeURIComponent:
    return decodeURIComponent(path)

  proc numberOfMatchingSegments(path1, path2: cstring): int =
    # get rid of leading slashes and normalize to lower case
    var path1 = path1.replace(jsnew RegExp("^\\/+", ""), "").toLowerCase()
    var path2 = path2.replace(jsnew RegExp("^\\/+", ""), "").toLowerCase()

    if path1 == path2:
      return 10000

    var p1dirs = path1.split("/").toJs
    var p2dirs = path2.split("/").toJs
    var len = Math.min(p1dirs.len, p2dirs.len)

    var eqCount = 0
    while eqCount <= len and
          p1dirs[<p1dirs.len - eqCount] == p2dirs[<p2dirs.len - eqCount]:
      inc eqCount

    return eqCount

  proc pathsMatch(path1, path2: cstring): bool =
    var res = numberOfMatchingSegments(path1, path2)
    return res > 0

  proc valid(path: cstring): bool =
    not path.isNil and path.indexOf(cstring"monaco") == -1

  bs.socket.on("symbiosis-view-reloaded") do (ev: js):
    console.log ev
    var scripts = document.querySelectorAll("script")
    for existingScript in scripts:
      let
        changedFile = cast[cstring](ev.path)
        scriptTagSrc = existingScript.getAttribute("src")

      if valid(scriptTagSrc) and pathsMatch(changedFile, pathFromUrl(scriptTagSrc)):
        var newScript = document.createElement("script")
        newScript.setAttribute("type", "text/javascript")
        newScript.setAttribute("src", scriptTagSrc)

        console.log "[BS] Reloading:", newScript
        document.head.appendChild(newScript)

        var parentTag = existingScript.parentNode.toJs
        if cast[bool](parentTag):
          parentTag.removeChild existingScript
        return
{.pop.}

let browserCodeText = $(browserCode.toJs.toCString)

proc noop = discard

options.plugins.push js{
  plugin: noop,
  hooks: js{
    "client:js": cstring(fmt";({browserCodeText})(___browserSync___);")
  }
}

bs.init(options) do (err, instance: js):
  echo "BS"
  var watchedFiles = @[
    cstring("*.js"),
    "styles/*",
    "media/*",
    "fonts/*"
  ]

  bs.watch(watchedFiles) do (event, path: cstring):
    echo event, path

    if event != "add" and event != "change":
      return

    let p =

    case cast[string](cast[cstring](p.extname(path)))
    of ".js":
      console.log "[BS] View changed:", path
      instance.io.sockets.emit "symbiosis-view-reloaded", js{path: path}
    of ".css", ".jpg", ".png", ".gif", ".html", ".svg", ".ttf", ".woff":
      console.log "[BS] Static file changed:", path
      bs.reload p.basename(path)

