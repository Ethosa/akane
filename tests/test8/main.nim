# --- Test 8. Example for https://github.com/the-benchmarker/web-frameworks. --- #
import akane


proc main {.gcsafe.} =
  let server = newServer("127.0.0.1", 5000)  # will be run at http://127.0.0.1:5000

  server.pages:
    equals("/", HttpGet):  # http://127.0.0.1:5000/
      await request.send("")

    "/user":  # http://127.0.0.1:5000/user
      await request.send("")

    regex(re"\A/user/id(\d+)\Z", HttpPost):  # http://127.0.0.1:5000/user/id123456 -> {"id": 123456}
      await request.send(%*{"id": url[0]})

  server.start()

main()
