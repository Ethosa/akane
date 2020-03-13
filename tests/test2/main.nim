# author: Ethosa
# Templates.
import akane

var server = newServer()


server.pages:
  equals("/"):  # when url is "domain/"
    var index = await loadtemplate("index")
    await request.answer(index)


server.start()  # Starts server.
