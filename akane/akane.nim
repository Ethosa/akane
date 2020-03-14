# author: Ethosa
# ----- CORE ----- #
import asyncdispatch
import asynchttpserver

# ----- SUPPORT ----- #
import asyncfile  # loadtemplate
import strutils  # startsWith, endsWith
import tables
import macros
import times
import json  # urlParams
import uri  # decodeUrl
import os
import re  # regex

# ----- EXPORT -----
export asyncdispatch
export asynchttpserver
export strutils
export json
export uri
export re


type
  ServerRef* = ref object
    port*: uint16
    address*: string
    server*: AsyncHttpServer


var AKANE_DEBUG_MODE*: bool = false


proc newServer*(address: string = "127.0.0.1",
                port: uint16 = 5000, debug: bool = false): ServerRef =
  ## Creates a new ServerRef object.
  ##
  ## Arguments:
  ## -   ``address`` - server address, e.g. "127.0.0.1"
  ## -   ``port`` - server port, e.g. 5000
  ## -   ``debug`` - debug mode
  if not existsDir("templates"):
    createDir("templates")
  AKANE_DEBUG_MODE = debug
  return ServerRef(
    address: address, port: port,
    server: newAsyncHttpServer()
  )


proc loadtemplate*(name: string, json: JsonNode = %*{}): Future[string] {.async, inline.} =
  ## Loads HTML template from `templates` folder.
  ##
  ## Arguments:
  ## -   ``name`` - template's name, e.g. "index", "api", etc.
  var
    file = openAsync(("templates" / name) & ".html")
    readed = await file.readAll()
  file.close()
  for key, value in json.pairs:
    let
      # if statment, e.g.: if $(variable) {......}
      if_stmt = re("if\\s*(\\$\\(" & key & "\\))\\s*\\{\\s*([\\s\\S]+?)\\s*\\}")
      # variable statment, e.g.: $(variable)
      variable_stmt = re("(\\$\\s*\\(" & key & "\\))")
    if readed.contains(if_stmt):
      var canplace: bool = false
      case value.kind:
      of JBool:
        if value.getBool:
          canplace = true
      of JInt:
        if value.getInt != 0:
          canplace = true
      of JFloat:
        if value.getFloat != 0.0:
          canplace = true
      of JString:
        if value.getStr.len > 0:
          canplace = true
      of JArray:
        if value.len > 0:
          canplace = true
      of JObject:
        if value.getFields.len > 0:
          canplace = true
      else: discard
      if canplace:
        readed = readed.replacef(if_stmt, "$2")
      else:
        readed = readed.replacef(if_stmt, "")
    readed = readed.replacef(variable_stmt, $value)
  return readed


proc parseQuery*(request: Request): Future[JsonNode] {.async.} =
  ## Decodes query.
  ## e.g.:
  ##   "a=5&b=10" -> {"a": "5", "b": "10"}
  ##
  ## This also have debug output, if AKANE_DEBUG_MODE is true.
  var data = request.url.query.split("&")
  result = %*{}
  for i in data:
    let timed = i.split("=")
    if timed.len > 1:
      result[decodeUrl(timed[0])] = %decodeUrl(timed[1])
  if AKANE_DEBUG_MODE:
    let
      now = times.local(times.getTime())
      timed_month = ord(now.month)
      month = if timed_month > 9: $timed_month else: "0" & $timed_month
      day = if now.monthday > 9: $now.monthday else: "0" & $now.monthday
      hour = if now.hour > 9: $now.hour else: "0" & $now.hour
      minute = if now.minute > 9: $now.minute else: "0" & $now.minute
      second = if now.second > 9: $now.second else: "0" & $now.second
      host =
        if request.headers.hasKey("host") and request.headers["host"].len > 1:
          request.headers["host"] & " "
        else:
          "new "
    echo(
      host, request.reqMethod,
      " at ", now.year, ".", month, ".", day,
      " ", hour, ":", minute, ":", second,
      " Request from ", request.hostname,
      " to url \"", decodeUrl(request.url.path), "\".")


macro pages*(server: ServerRef, body: untyped): untyped =
  ## This macro provides convenient page adding.
  ##
  ## `body` should be StmtList.
  ## page type can be:
  ## -   ``equals``
  ## -   ``startswith``
  ## -   ``endswith``
  ## -   ``regex``
  ## -   ``notfound`` - this page uses without URL argument.
  ##
  ## ..code-block::Nim
  ##  server.pages:
  ##    equals("/home"):
  ##      echo url
  ##      echo urlParams
  var
    stmtlist = newStmtList()
    notfound_declaration = false
  stmtlist.add(
    newNimNode(nnkLetSection).add(  # let urlParams: JsonNode = await parseQuery(request)
      newNimNode(nnkIdentDefs).add(
        ident("urlParams"),
        ident("JsonNode"),
        newCall(
          "await",
          newCall(
            "parseQuery",
            ident("request")
          )
        )
      )
    ),
    newNimNode(nnkLetSection).add(  # let decode_url: string = decodeUrl(request.url.path)
      newNimNode(nnkIdentDefs).add(
        ident("decoded_url"),
        ident("string"),
        newCall(
          "decodeUrl",
          newNimNode(nnkDotExpr).add(
            newNimNode(nnkDotExpr).add(
              ident("request"), ident("url")
            ),
            ident("path")
          )
        )
      )
    )
  )
  stmtlist.add(newNimNode(nnkIfStmt))
  var ifstmtlist = stmtlist[2]

  for i in body:  # for each page in statment list.
    let
      current = $i[0]
      path = if i.len == 3: i[1] else: newEmptyNode()
      slist = if i.len == 3: i[2] else: i[1]
    if (i.kind == nnkCall and i[0].kind == nnkIdent and
        (path.kind == nnkStrLit or path.kind == nnkCallStrLit or path.kind == nnkEmpty) and
        slist.kind == nnkStmtList):
      if current == "equals":
        slist.insert(0,  # let url: string = `path`
            newNimNode(nnkLetSection).add(
              newNimNode(nnkIdentDefs).add(
                ident("url"),
                ident("string"),
                path
              )
            )
          )
        ifstmtlist.add(  # request.path.url == i[1]
          newNimNode(nnkElifBranch).add(
            newCall("==", path, ident("decoded_url")),
            slist))
      elif current == "startswith":
        slist.insert(0,  # let url = decoded_url[`path`.len..^1]
          newNimNode(nnkLetSection).add(
            newNimNode(nnkIdentDefs).add(
              ident("url"),
              ident("string"),
              newCall(
                "[]",
                ident("decoded_url"),
                newCall(
                  "..^",
                  newCall("len", path),
                  newLit(1))
              )
            )
          )
        )
        ifstmtlist.add(  # decode_url.startsWith(`path`)
          newNimNode(nnkElifBranch).add(
            newCall(
              "startsWith",
              ident("decoded_url"),
              path),
            slist))
      elif current == "endswith":
        slist.insert(0,  # let url: string = decoded_url[0..^`path`.len]
          newNimNode(nnkLetSection).add(
            newNimNode(nnkIdentDefs).add(
              ident("url"),
              ident("string"),
              newCall(
                "[]",
                ident("decoded_url"),
                newCall(
                  "..^",
                  newLit(0),
                  newCall("+", newLit(1), newCall("len", path))
                )
              )
            )
          )
          )
        ifstmtlist.add(  # decode_url.endsWith(`path`)
          newNimNode(nnkElifBranch).add(
            newCall(
              "endsWith",
              ident("decoded_url"),
              path),
            slist))
      elif current == "regex":
        slist.insert(0,  # discard match(decoded_url, `path`, url)
            newNimNode(nnkDiscardStmt).add(
              newCall("match", ident("decoded_url"), path, ident("url"))
            )
          )
        slist.insert(0,  # var url: array[20, string]
          newNimNode(nnkVarSection).add(
            newNimNode(nnkIdentDefs).add(
              ident("url"),
              newNimNode(nnkBracketExpr).add(
                ident("array"), newLit(20), ident("string")
              ),
              newEmptyNode()
            )
          ))
        ifstmtlist.add(  # decode_url.match(`path`)
          newNimNode(nnkElifBranch).add(
            newCall("match", ident("decoded_url"), path),
            slist))
      elif current == "notfound":
        notfound_declaration = true
        ifstmtlist.add(newNimNode(nnkElse).add(slist))

  if not notfound_declaration:
    ifstmtlist.add(
      newNimNode(nnkElse).add(
        newCall(  # await request.respond(Http404, "Not found")
          "await",
          newCall(
            "respond",
            ident("request"),
            ident("Http404"),
            newLit("Not found"))
          )
        )
      )

  result = newNimNode(nnkProcDef).add(
    ident("receivepages"),  # procedure name.
    newEmptyNode(),  # for template and macros
    newEmptyNode(),  # generics
    newNimNode(nnkFormalParams).add(  # proc params
      newEmptyNode(),  # return type
      newNimNode(nnkIdentDefs).add(  # param
        ident("request"),  # param name
        ident("Request"),  # param type
        newEmptyNode()  # param default value
      )
    ),
    newNimNode(nnkPragma).add(  # pragma declaration
      ident("async"),
      ident("gcsafe")
    ),
    newEmptyNode(),
    stmtlist)


macro answer*(request, message: untyped, http_code = Http200): untyped =
  ## Responds from server with utf-8.
  ##
  ## Translates to:
  ##   await request.respond(Http200, "<head><meta charset='utf-8'></head>" & message)
  result = newCall(
    "respond",
    request,
    http_code,
    newCall("&", newLit("<head><meta charset='utf-8'></head>"), message)
  )


macro error*(request, message: untyped, http_code = Http404): untyped =
  ## Responds from server with utf-8.
  ##
  ## Translates to:
  ##   await request.respond(Http404, "<head><meta charset='utf-8'></head>" & message)
  result = newCall(
    "respond",
    request,
    http_code,
    newCall("&", newLit("<head><meta charset='utf-8'></head>"), message)
  )


macro start*(server: ServerRef): untyped =
  ## Starts server.
  result = quote do:
    if AKANE_DEBUG_MODE:
      echo "Server starts on http://", `server`.address, ":", `server`.port
    waitFor `server`.server.serve(Port(`server`.port), receivepages)
