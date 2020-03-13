# author: Ethosa
# equals, startswith, endswith, notfound and regex.
import akane

var server = newServer()


server.pages:
  equals("/helloworld"):  # when url is "domain/helloworld"
    await request.answer("Hello, World!")
  startswith("/get"):  # when url is "domain/get...", try "domain/get100000"
    await request.answer("I see only \"" & url & "\"")  # url var, contains text after "/get".
  endswith("/info"):  # when url is ".../info", try "domain/user/info"
    await request.answer("I see only \"" & url & "\"")  # url var, contains text before "/info".
  regex(re"\A\/id(\d+)\z"):  # when url is re"domain/id\d+", try "domain/id123" and "domain/idNotNumber"
    await request.answer("Hello, user with ID" & url[0])  # url var contains array[20, string], matched from URL.
  notfound:  # `notfound` should be at the end of the remaining cases
    await request.answer("<h1 align='center'>Sorry, but page not found :(</h1>")


server.start()  # Starts server.
