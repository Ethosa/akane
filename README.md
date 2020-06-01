<h1 align="center">Akane</h1>
<div align="center">The Nim asynchronous web framework.

[![Open Source Love](https://badges.frapsoft.com/os/v1/open-source.png?v=103)](https://github.com/ellerbrock/open-source-badges/)
[![Nim language-plastic](https://github.com/Ethosa/yukiko/blob/master/nim-lang.svg)](https://github.com/Ethosa/yukiko/blob/master/nim-lang.svg)
[![License](https://img.shields.io/github/license/Ethosa/akane)](https://github.com/Ethosa/akane/blob/master/LICENSE)
[![test](https://github.com/Ethosa/akane/workflows/test/badge.svg)](https://github.com/Ethosa/akane/actions)

<h4>Latest version - 0.1.1</h4>
<h4>Stable version - 0.1.1</h4>
</div>

## Install
-   git: `nimble install https://github.com/Ethosa/akane.git`
-   nimble: `nimble install akane`


## Features
-   Pages with URL handling methods: `equals`, `startswith`, `endswith`, `regex`,`notfound`;
-   `templates` folder;
-   Only the standard library used;
-   Debug mode;
-   Password hashing;
-   Working with cookies;
-   Simple usage:
    ```nim
    import akane

    proc main =  # for gcsafe
      var server = newServer()  # launch on http://localhost:5000

      server.pages:
        equals("/"):  # when url is "http://...localhost:5000/"
          # You also can write "/" instead of equals("/")
          # type of `request` is a Request.
          await request.answer("Hello, world!")  # utf-8 encoded message.

      server.start()
    main()
    ```

## Debug mode
For enable debug mode, please, compile with `-d:debug` or `--define:debug`.

## FAQ
*Q*: Where can I learn this?  
*A*: You can see [wiki page](https://github.com/Ethosa/akane/wiki/Getting-started)

*Q*: Where can I find the docs?  
*A*: You can see [docs page](https://ethosa.github.io/akane/akane.html)

*Q*: How can I help to develop this project?  
*A*: You can put a :star: :3


<div align="center">
  Copyright 2020 Ethosa
</div>
