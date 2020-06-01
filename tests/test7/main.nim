# author: Ethosa
# work with cookies.
import akane


proc main =
  var server = newServer()

  server.pages:
    "/":
      echo cookies
      await request.answer("hello", headers=server.newCookie("one", "world ._."))

  server.start()

main()
