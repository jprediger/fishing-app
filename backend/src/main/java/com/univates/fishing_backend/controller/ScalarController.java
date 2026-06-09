package com.univates.fishing_backend.controller;

import org.springframework.stereotype.Controller;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.ResponseBody;

@Controller
public class ScalarController {

    @GetMapping("/docs")
    @ResponseBody
    public String docs() {
        return """
                <!doctype html>
                <html>
                <head>
                  <title>Fishing Backend API</title>
                  <meta charset="utf-8" />
                  <meta name="viewport" content="width=device-width, initial-scale=1" />
                </head>
                <body>
                  <script
                    id="api-reference"
                    data-url="/v3/api-docs">
                  </script>
                  <script src="https://cdn.jsdelivr.net/npm/@scalar/api-reference"></script>
                </body>
                </html>
                """;
    }
}
