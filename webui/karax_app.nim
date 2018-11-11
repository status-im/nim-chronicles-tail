include
  dom, karax/prelude

import
  jsconsole, jscore, jsffi, jswebsockets,
  tail_jsplugins

type
  ChroniclesPrompt = object
    text: string
    suggestions: seq[string]
    activeSuggestionIdx: int

  LogEvent = js

var
  chroniclesCredentials* {.importc, nodecl.}: js
  chroniclesPrompt: ChroniclesPrompt
  activeSectionIdx = 0
  logEvents = newSeq[LogEvent]()

proc activeOrInactive(idx, currentActiveIdx: int): cstring =
  if idx == currentActiveIdx: "active"
  else: "inactive"

proc promptKeyDown(ev: karax.Event; n: VNode) =
  console.log "KEY PRESS"
  console.log ev

proc logSectionContent: VNode =
  result = buildHtml(tdiv(id = "log_section")):
    tdiv(class = "controls"):
      input(class = "filter", onkeydown = promptKeyDown)
      if chroniclesPrompt.suggestions.len > 0:
        ul(class = "prompt_suggestions"):
          for i, s in chroniclesPrompt.suggestions:
            li(class = activeOrInactive(i, chroniclesPrompt.activeSuggestionIdx)):
              text s

    tdiv(class = "events"):
      table:
        thead:
          tr:
            th(class = "level"): text "LVL"
            th(class = "ts")   : text "Time"
            th(class = "msg")  : text "Event"
            th(class = "props"): text "Properties"

        tbody:
          for event in logEvents:
            let level = cast[cstring](event.level)
            tr(class = level):
              td(class = "level"): text level
              td(class = "ts")   : text cast[cstring](event.ts)
              td(class = "msg")  : text cast[cstring](event.msg)
              td(class = "props"): text cast[cstring](event.x)

addSection("Log", logSectionContent)

var chroniclesSocket = newWebSocket(cast[cstring](chroniclesCredentials.url))

chroniclesSocket.onOpen = proc (e: jswebsockets.Event) =
  chroniclesSocket.send(cast[cstring](chroniclesCredentials.accessToken))

chroniclesSocket.onMessage = proc (e: MessageEvent) =
  var msg = JSON.parse(e.data).js
  if msg.level == jsundefined:
    console.log msg
    return

  logEvents.add msg

  if activeSectionIdx == 0:
    var logsTable = cast[js](document.querySelector("#log_section table"))
    let logsAreTrailing = cast[int](logsTable.scrollTopMax - logsTable.scrollTop) < 30

    karax.redrawSync()

    if logsAreTrailing:
      logsTable.scrollTop = logsTable.scrollTopMax

proc activeSection: VNode =
  sections[activeSectionIdx].content()

proc pageContent(): VNode =
  proc selectSection(i: int): auto =
    return proc() =
      activeSectionIdx = i

  result = buildHtml(tdiv):
    tdiv(id = "header"):
      h1: text "Chronicles Tail 1.0"

      ul(id = "sections"):
        for i, s in sections:
          li(onclick = selectSection(i),
             class = activeOrInactive(i, activeSectionIdx)): text s.title

    tdiv(id = "content"):
      activeSection()

setRenderer pageContent

