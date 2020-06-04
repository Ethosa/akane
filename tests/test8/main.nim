# --- Test 8. Example for https://github.com/the-benchmarker/web-frameworks. --- #
import akane


proc main {.gcsafe.} =
  let server = newServer("127.0.0.1", 5000)  # will be run at http://127.0.0.1:5000

  server.pages:
    "/":  # http://127.0.0.1:5000/
      if request.reqMethod == HttpGet:
        await request.sendPlaintext("")
      else:
        await request.error("not GET :(")

    "/user":  # http://127.0.0.1:5000/user
      if request.reqMethod == HttpGet:
        await request.sendPlaintext("")
      else:
        await request.error("not GET :(")

    regex(re"\A/user/id(\d+)\Z"):  # http://127.0.0.1:5000/user/id123456 -> {"id": 123456}
      if request.reqMethod == HttpPost:
        await request.sendPlaintext(%*{"id": url[0]})
      else:
        await request.error("not POST :(")

  server.start()

main()
