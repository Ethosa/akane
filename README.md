<h1 align="center">Akane</h1>
<div align="center">The Nim asynchronous web framework.

[![Open Source Love](https://badges.frapsoft.com/os/v1/open-source.png?v=103)](https://github.com/ellerbrock/open-source-badges/)
[![Nim language-plastic](https://github.com/Ethosa/yukiko/blob/master/nim-lang.svg)](https://github.com/Ethosa/yukiko/blob/master/nim-lang.svg)
[![License](https://img.shields.io/github/license/Ethosa/akane)](https://github.com/Ethosa/akane/blob/master/LICENSE)

<h4>Latest version - 0.0.2</h4>
<h4>Stable version - ?</h4>
</div>

# Install
-   `git`: `nimble install https://github.com/Ethosa/akane.git`


# Features
-   Pages with URL handling methods: `equals`, `startswith`, `endswith`, `regex`,`notfound`.
-   `templates` folder.
-   Simple usage
    ```nim
    import akane

    var server = newServer(debug=true)  # launch on http://localhost:5000

    server.pages:
      equal("/"):
        # type of `request` is a Request.
        await request.answer("Hello, world!")  # utf-8 encoded message.

    server.start()
    ```


# FAQ
*Q*: How I can help to develop this project?  
*A*: You can put a :star: :3


<div align="center">
  Copyright 2020 Ethosa
</div>
