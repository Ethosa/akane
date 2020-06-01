# --- Test 1. Hello world prorgam. --- #
import akane

let server = newServer("127.0.0.1", 5000)  # default params


server.pages:
  equals("/helloworld"):  # when url is "domain/helloworld"
    await request.answer "Hello, World!"  # sends utf-8 encoded message.


server.start()  # Starts server.
