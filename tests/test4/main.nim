# author: Ethosa
# Working with templates.
import akane


proc main =  # main proc for gcsafe
  var
    server = newServer(debug=true)
    data: JsonNode = %{
      "myvariable": %0,
      "can_place": %false,
      "test": %2
    }

  server.pages:
    equals("/"):  # when url is "domain/"
      let index = await loadtemplate("index", data)
      # all "$(myvariable)" in template file replaces at data["myvariable"]
      data["myvariable"] = %(data["myvariable"].num + 1)
      if data["myvariable"].num > 3:
        data["can_place"] = %true
      await request.answer(index)
    notfound:
      await request.error("<h1 align='center'>Sorry, but page not found :(</h1>")

  server.start()  # Starts server.

main()
