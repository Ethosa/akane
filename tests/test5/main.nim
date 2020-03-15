# author: Ethosa
# password shashing.
import akane


proc main {.async.} =  # main proc for gcsafe
  var
    server = newServer(debug=true)
    hashpassword = await password2hash("Hello world")

  server.pages:
    "/login":  # try "domain/login?password=Hello%20World"
      if urlParams.hasKey("password"):
        if await validatePassword(urlParams["password"].getStr, hashpassword):
          await request.sendJson(%*{"response": %true})
        else:
          await request.sendJson(%*{"error": %"password is not correct."})
      else:
        await request.sendJson(%*{"error": %"password param not found."})
    notfound:
      await request.error("<h1 align='center'>Sorry, but page not found :(</h1>")

  server.start()  # Starts server.

waitFor main()
