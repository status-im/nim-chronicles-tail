import
  jsffi, karax/[karax, vdom]

export
  karax, vdom

type
  SectionRenderer* = proc(): VNode

  Section* = object
    title*: cstring
    content*: SectionRenderer

  TailEvent* = object of js
    msg*: cstring
    level*: cstring
    ts*: cstring
    protocol*: cstring
    msgId*: int
    peer*: cstring
    port*: int
    data*: js
    topics*: cstring

  TailEventFilter* = proc(e: TailEvent): bool

when defined(createChroniclesTail):
  proc getKarax*: KaraxInstance {.exportc.} = kxi

  var
    sections* = newSeq[Section](0)
    filters* = newSeq[TailEventFilter]()

  proc addSection*(title: cstring, content: SectionRenderer) {.exportc.} =
    sections.add Section(title: title, content: content)
    redrawSync()

  proc addEventFilter*(f: TailEventFilter) {.exportc.} =
    filters.add f

  proc addEscaped*(result: var string, s: string) {.exportc.} =
    ## same as ``result.add(escape(s))``, but more efficient.
    for c in items(s):
      case c
      of '<': result.add("&lt;")
      of '>': result.add("&gt;")
      of '&': result.add("&amp;")
      of '"': result.add("&quot;")
      of '\'': result.add("&#x27;")
      of '/': result.add("&#x2F;")
      else: result.add(c)

  proc addAsHtml*(result: var string, obj: js) {.exportc.} =
    if jsTypeOf(obj) == "object":
      result.add "<table>"
      for key, value in obj:
        result.add """<tr><td class = "key">"""
        result.addEscaped $key
        result.add """</td><td class = "value">"""
        result.addAsHtml value
        result.add "</td></tr>"
      result.add "</table>"
    else:
      result.add cast[cstring](obj.toString())

  proc asHtml*(obj: js): string {.exportc.} =
    result = newStringOfCap(128)
    result.addAsHtml(obj)

else:
  proc addEscaped*(result: var string, s: string) {.importc.}
  proc addAsHtml*(result: var string, obj: js) {.importc.}
  proc asHtml*(obj: js): string {.importc.}

  proc getKarax*(): KaraxInstance {.importc.}
  proc addSection*(title: cstring, content: SectionRenderer) {.importc.}
  proc addEventFilter*(f: TailEventFilter) {.importc.}

