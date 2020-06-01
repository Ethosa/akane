# --- Test6. `for` template --- #
import akane


proc main =
  var
    server = newServer()
    data = %*{
      "fruits": %["apple", "banana"]
    }

  server.pages:
    "/":
      let index = await loadtemplate("index", data)
      await request.answer(index)

  server.start()

main()
