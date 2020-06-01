# author: Ethosa
# ----- CORE ----- #
import asyncdispatch
import asynchttpserver
import macros

# ----- SUPPORT ----- #
import asyncfile  # loadtemplate
import strutils  # startsWith, endsWith
import strtabs
import cookies
import tables
import json  # urlParams
import uri  # decodeUrl
import std/sha1  # sha1 passwords.
import os
import re  # regex

# ----- EXPORT -----
export asyncdispatch
export asynchttpserver
export strutils
export cookies
export strtabs
export json
export uri
export re


when defined(debug):
  import logging

  var console_logger = newConsoleLogger(fmtStr="[$time]::$levelname - ")
  addHandler(console_logger)

  when not defined(android):
    var file_logger = newFileLogger("logs.log", fmtStr="[$date at $time]::$levelname - ")
    addHandler(file_logger)

  info("Compiled in debug mode.")


## ## Simple usage
## .. code-block:: nim
##
##    let my_server = newServer("127.0.0.1", 8080)  # starts server at https://127.0.0.1:8080
##
##    my_sever.pages:
##      "/":
##        echo "Index page"
##        await request.answer("Hello, world!")
##      notfound:
##        echo "oops :("
##        await request.error("404 Page not found.")



type
  ServerRef* = ref object
    port*: uint16
    address*: string
    server*: AsyncHttpServer


# ---------- PRIVATE ---------- #
proc toStr(node: JsonNode): Future[string] {.async.} =
  if node.kind == JString:
    return node.getStr
  else:
    return $node


# ---------- PUBLIC ---------- #
proc newServer*(address: string = "127.0.0.1", port: uint16 = 5000): ServerRef =
  ## Creates a new ServerRef object.
  ##
  ## Arguments:
  ## - `address` - server address, e.g. "127.0.0.1"
  ## - `port` - server port, e.g. 5000
  ##
  ## ## Example
  ## .. code-block:: nim
  ##
  ##    let server = newServer("127.0.0.1", 5000)
  if not existsDir("templates"):
    createDir("templates")
    when defined(debug):
      debug("directory \"templates\" was created.")
  ServerRef(address: address, port: port, server: newAsyncHttpServer())


proc loadtemplate*(name: string, json: JsonNode = %*{}): Future[string] {.async, inline.} =
  ## Loads HTML template from `templates` folder.
  ##
  ## Arguments:
  ## - `name` - template's name, e.g. "index", "api", etc.
  ## - `json` - Json data, which replaces in the template.
  ##
  ## Replaces:
  ## -  @key -> value
  ## -  if @key { ... } -> ... (if value is true)
  ## -  if not @key { ... } -> ... (if value is false)
  ## -  for i in 0..@key { ... } -> ........., etc
  ## -  @key[0] -> key[0]
  ##
  ## ## Example
  ## .. code-block:: nim
  ##
  ##    let template = loadtemplate("index.html", %*{"a": 5})
  var
    file = openAsync(("templates" / name) & ".html")
    readed = await file.readAll()
  file.close()
  for key, value in json.pairs:
    # ---- regex patterns ---- #
    let
      # variable statement, e.g.: $(variable)
      variable_stmt = re("(@" & key & ")")
      # if statement, e.g.: if $(variable) {......}
      if_stmt = re("if\\s*(@" & key & ")\\s*\\{\\s*([\\s\\S]+?)\\s*\\}")
      # if not statement, e.g.: if not $(variable) {......}
      if_notstmt = re("if\\s*not\\s*(@" & key & ")\\s*\\{\\s*([\\s\\S]+?)\\s*\\}")
      # for statement, e.g.: for i in 0..$(variable) {hello, $variable[i]}
      forstmt = re(
        "for\\s*([\\S]+)\\s*in\\s*(\\d+)\\.\\.(@" & key & ")\\s*\\{\\s*([\\s\\S]+?)\\s*\\}")
    var
      matches: array[20, string]
      now = 0

    # ---- converts value to bool ---- #
    var value_bool =
      case value.kind:
      of JBool:
        value.getBool
      of JInt:
        value.getInt != 0
      of JFloat:
        value.getFloat != 0.0
      of JString:
        value.getStr.len > 0
      of JArray:
        value.len > 0
      of JObject:
        value.getFields.len > 0
      else: false

    # ---- replace ----- #
    if readed.contains(if_stmt):
      if value_bool:
        readed = readed.replacef(if_stmt, "$2")
      else:
        readed = readed.replacef(if_stmt, "")
    if readed.contains(if_notstmt):
      if value_bool:
        readed = readed.replacef(if_notstmt, "")
      else:
        readed = readed.replacef(if_notstmt, "$2")
    while readed.contains(forstmt):
      let
        (start, stop) = readed.findBounds(forstmt, matches, now)
        elem = re("(" & key & "\\[" & matches[0] & "\\])")
      var output = ""
      for i in parseInt(matches[1])..<value.len:
        output &= matches[3].replacef(elem, await value[i].toStr)
      readed = readed[0..start-1] & output & readed[stop+1..^1]
      now += stop
    readed = readed.replacef(variable_stmt, await value.toStr)
  return readed


proc parseQuery*(request: Request): Future[JsonNode] {.async.} =
  ## Decodes query.
  ## e.g.:
  ##   "a=5&b=10" -> {"a": "5", "b": "10"}
  ##
  ## This also have debug output, if compiled in debug mode.
  var data = request.url.query.split("&")
  result = %*{}
  for i in data:
    let timed = i.split("=")
    if timed.len > 1:
      result[decodeUrl(timed[0])] = %decodeUrl(timed[1])
  when defined(debug):
    let host =
      if request.headers.hasKey("host") and request.headers["host"].len > 1:
        request.headers["host"] & " "
      else:
        "new "
    debug(host, request.reqMethod, " Request from ", request.hostname, " to url \"", decodeUrl(request.url.path), "\".")
    debug(request)


proc password2hash*(password: string): Future[string] {.async, inline.} =
  ## Generates a sha1 from `password`.
  ##
  ## Arguments:
  ## - `password` is an user password.
  return $secureHash(password)


proc validatePassword*(password, hashpassword: string): Future[bool] {.async, inline.} =
  ## Validates the password and returns true, if the password is valid.
  ##
  ## Arguments:
  ## - `password` is a got password from user input.
  ## - `hashpassword` is a response from `password2hash proc <#password2hash,string>`_
  return secureHash(password) == parseSecureHash(hashpassword)


proc newCookie*(server: ServerRef, key, value: string, domain = ""): HttpHeaders {.inline.} =
  ## Creates a new cookies
  ##
  ## Arguments:
  ## - `key` is a cookie key.
  ## - `value` is a new cookie value.
  ## - `domain` is a cookie doomain.
  let d = if domain != "": domain else: server.address
  return newHttpHeaders([("Set-Cookie", setCookie(key, value, d, noName=true))])


macro pages*(server: ServerRef, body: untyped): untyped =
  ## This macro provides convenient page adding.
  ##
  ## `body` should be StmtList.
  ## page type can be:
  ## - `equals`
  ## - `startswith`
  ## - `endswith`
  ## - `regex` - match url via regex.
  ## - `notfound` - this page uses without URL argument.
  ##
  ## When a new request to the server is received, variables are automatically created:
  ## - `request` - new Request.
  ## - `url` - matched URL.
  ##   - `equals` - URL is request.url.path
  ##   - `startswith` - URL is text after `startswith`.
  ##   - `endswith` - URL is text before `endswith`.
  ##   - `regex` - URL is matched text.
  ##   - `notfound` - `url` param not created.
  ## - `urlParams` - query URL (in JSON).
  ## - `decoded_url` - URL always is request.url.path
  ## - `cookies` - StringTable of cookies.
  # ------ EXAMPLES ------ #
  runnableExamples:
    let server = newServer()
    server.pages:
      equals("/home"):
        echo url
        echo urlParams
        await request.answer("Home")
      # You can also not write `equals("/")`:
      "/helloworld":
        await request.answer("Hello, world")

  # ------ CODE ------ #
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
          newCall("parseQuery", ident("request"))
        )
      ),
      newNimNode(nnkIdentDefs).add(  # let decode_url: string = decodeUrl(request.url.path)
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
      ),
      newNimNode(nnkIdentDefs).add(  # let cookies: string = parseCookies(request.headers.cookie)
        ident("cookies"),
        ident("StringTableRef"),
        newNimNode(nnkIfExpr).add(
          newNimNode(nnkElifExpr).add(
            newCall("hasKey", newNimNode(nnkDotExpr).add(ident("request"), ident("headers")), newLit("cookie")),
            newCall(
              "parseCookies",
              newCall(
                "[]",
                newNimNode(nnkDotExpr).add(
                  ident("request"), ident("headers")
                ),
                newLit("cookie")
              )
            )
          ),
          newNimNode(nnkElseExpr).add(
            newCall("newStringTable", ident("modeCaseSensitive"))
          )
        )
      )
    )
  )
  stmtlist.add(newNimNode(nnkIfStmt))
  var ifstmtlist = stmtlist[1]

  for i in body:  # for each page in statment list.
    let
      current = if i.len == 3: $i[0] else: "equals"
      path = if i.len == 3: i[1] else: i[0]
      slist = if i.len == 3: i[2] else: i[1]
    if (i.kind == nnkCall and
        (path.kind == nnkStrLit or path.kind == nnkCallStrLit or path.kind == nnkEmpty) and
        slist.kind == nnkStmtList):
      if current == "equals":
        slist.insert(0,  # let url: string = `path`
          newNimNode(nnkLetSection).add(
            newNimNode(nnkIdentDefs).add(
              ident("url"), ident("string"), path
            )
          )
        )
        ifstmtlist.add(  # decoded_url == `path`
          newNimNode(nnkElifBranch).add(
            newCall("==", path, ident("decoded_url")),
            slist
          )
        )
      elif current == "startswith":
        slist.insert(0,  # let url = decoded_url[`path`.len..^1]
          newNimNode(nnkLetSection).add(
            newNimNode(nnkIdentDefs).add(
              ident("url"),
              ident("string"),
              newCall(
                "[]",
                ident("decoded_url"),
                newCall("..^", newCall("len", path), newLit(1))
              )
            )
          )
        )
        ifstmtlist.add(  # decode_url.startsWith(`path`)
          newNimNode(nnkElifBranch).add(
            newCall("startsWith", ident("decoded_url"), path),
            slist
            )
          )
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
                  "..^", newLit(0), newCall("+", newLit(1), newCall("len", path))
                )
              )
            )
          )
        )
        ifstmtlist.add(  # decode_url.endsWith(`path`)
          newNimNode(nnkElifBranch).add(
            newCall("endsWith", ident("decoded_url"), path),
            slist
          )
        )
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
          newCall("respond", ident("request"), ident("Http404"), newLit("Not found"))
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


macro answer*(request, message: untyped, http_code = Http200,
             headers: HttpHeaders = newHttpHeaders()): untyped =
  ## Responds from server with utf-8.
  ##
  ## Translates to
  ##
  ## .. code-block:: nim
  ##
  ##    request.respond(Http200, "<head><meta charset='utf-8'></head>" & message)
  ##
  ## ## Example
  ## .. code-block:: nim
  ##
  ##    await request.answer("hello!")
  result = newCall(
    "respond",
    request,
    http_code,
    newCall("&", newLit("<head><meta charset='utf-8'></head>"), message),
    headers
  )


macro error*(request, message: untyped, http_code = Http404,
             headers: HttpHeaders = newHttpHeaders()): untyped =
  ## Responds from server with utf-8.
  ##
  ## Translates to
  ##
  ## .. code-block:: nim
  ##
  ##    request.respond(Http404, "<head><meta charset='utf-8'></head>" & message)
  ##
  ## ## Example
  ## .. code-block:: nim
  ##
  ##    await request.error("Oops! :(")
  result = newCall(
    "respond",
    request,
    http_code,
    newCall("&", newLit("<head><meta charset='utf-8'></head>"), message),
    headers
  )


macro sendJson*(request, message: untyped, http_code = Http200): untyped =
  ## Sends JsonNode with "Content-Type": "application/json" in headers.
  ##
  ## Translates to
  ##
  ## .. code-block:: nim
  ##
  ##    request.respond(Http200, $message, newHttpHeaders([("Content-Type","application/json")]))
  ##
  ## ## Example
  ## .. code-block:: nim
  ##
  ##    await request.sendJson(%{"response": "error", "msg": "oops :("})
  result = newCall(
    "respond",
    request,
    http_code,
    newCall("$", message),
    newCall(
      "newHttpHeaders",
      newNimNode(nnkBracket).add(
        newNimNode(nnkPar).add(
          newLit("Content-Type"),
          newLit("application/json")
        )
      )
    )
  )


macro start*(server: ServerRef): untyped =
  ## Starts server.
  ##
  ## ## Example
  ## .. code-block:: nim
  ##
  ##    let server = newServer()
  ##    server.start()
  result = quote do:
    when defined(debug):
      debug("Server starts on http://", `server`.address, ":", `server`.port)
    waitFor `server`.server.serve(Port(`server`.port), receivepages, `server`.address)
