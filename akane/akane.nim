# author: Ethosa
# ----- CORE ----- #
import asyncdispatch
import asynchttpserver
export asyncdispatch
export asynchttpserver

# ----- SUPPORT ----- #
import asyncfile  # loadtemplate
import strutils  # startsWith, endsWith
export strutils
import macros
import json  # urlParams
export json
import uri  # decodeUri
export uri
import os
import re  # regex
export re


type
  ServerRef* = ref object
    debug*: bool
    port*: uint16
    address*: string
    server*: AsyncHttpServer


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
  return ServerRef(
    address: address, port: port,
    server: newAsyncHttpServer(), debug: debug
  )


proc loadtemplate*(name: string): Future[string] {.async, inline.} =
  ## Loads HTML template from `templates` folder.
  ##
  ## Arguments:
  ## -   ``name`` - template's name, e.g. "index", "api", etc.
  var
    file = openAsync(("templates" / name) & ".html")
    readed = await file.readAll()
  file.close()
  return readed


proc parseQuery*(request: Request): Future[JsonNode] {.async.} =
  ## Decodes query.
  ## e.g.:
  ##   "a=5&b=10" -> {"a": "5", "b": "10"}
  var data = request.url.query.split("&")
  result = %*{}
  for i in data:
    var timed = i.split("=")
    if timed.len > 1:
      result[decodeUrl(timed[0])] = %decodeUrl(timed[1])


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

  for i in body:  # for each page in statment list.
    let
      current = $i[0]
      path = if i.len == 3: i[1] else: newEmptyNode()
      slist = if i.len == 3: i[2] else: i[1]
    if (i.kind == nnkCall and i[0].kind == nnkIdent and
        (path.kind == nnkStrLit or path.kind == nnkCallStrLit or path.kind == nnkEmpty) and
        slist.kind == nnkStmtList):
      if current == "equals":
        slist.insert(0,
            newNimNode(nnkLetSection).add(
              newNimNode(nnkIdentDefs).add(
                ident("url"),
                ident("string"),
                path
              )
            )
          )
        stmtlist[2].add(  # request.path.url == i[1]
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
        stmtlist[2].add(
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
        stmtlist[2].add(
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
                ident("array"),
                newLit(20),
                ident("string")
              ),
              newEmptyNode()
            )
          ))
        stmtlist[2].add(
          newNimNode(nnkElifBranch).add(
            newCall(
              "match",
              ident("decoded_url"),
              path),
            slist))
      elif current == "notfound":
        notfound_declaration = true
        stmtlist[2].add(newNimNode(nnkElse).add(slist))

  if not notfound_declaration:
    stmtlist[2].add(
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
    newNimNode(nnkPostfix).add(
      ident("*"), ident("receivepages")  # procedure name.
    ),
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


macro answer*(request, message: untyped): untyped =
  ## Responds from server with utf-8.
  ##
  ## Translates to:
  ##   await request.respond(Http200, "<head><meta charset='utf-8'></head>" & message)
  result = newCall(
    "respond",
    request,
    ident("Http200"),
    newCall(
      "&",
      newLit("<head><meta charset='utf-8'></head>"),
      message
    )
  )


macro error*(request, message: untyped): untyped =
  ## Responds from server with utf-8.
  ##
  ## Translates to:
  ##   await request.respond(Http404, "<head><meta charset='utf-8'></head>" & message)
  result = newCall(
    "respond",
    request,
    ident("Http404"),
    newCall(
      "&",
      newLit("<head><meta charset='utf-8'></head>"),
      message
    )
  )


macro start*(server: ServerRef): untyped =
  ## Starts server.
  result = quote do:
    if `server`.debug:
      echo "Server starts on http://", `server`.address, ":", `server`.port
    waitFor `server`.server.serve(Port(`server`.port), receivepages)
