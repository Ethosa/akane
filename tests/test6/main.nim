# author: Ethosa
# templates for
import akane


proc main =
  var
    server = newServer(debug=true)
    data = %*{
      "fruits": %["apple", "banana"]
    }

  server.pages:
    "/":
      let index = await loadtemplate("index", data)
      await request.answer(index)

  server.start()

main()
