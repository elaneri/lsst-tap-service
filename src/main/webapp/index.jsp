<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>TAP API Docs</title>
  <link rel="stylesheet" href="https://cdn.jsdelivr.net/npm/swagger-ui-dist@5.11.8/swagger-ui.css" />
  <style>
    html {
      box-sizing: border-box;
      overflow: -moz-scrollbars-vertical;
      overflow-y: scroll;
    }
    *, *:before, *:after {
      box-sizing: inherit;
    }
    body {
      margin: 0;
      background: #fafafa;
      font-family: Arial, sans-serif;
    }
    #swagger-ui {
      max-width: 1200px;
      margin: 20px auto;
      padding: 0 20px 40px;
    }
    .topbar {
      display: none;
    }
  </style>
</head>
<body>
  <div id="swagger-ui"></div>

  <script src="https://cdn.jsdelivr.net/npm/swagger-ui-dist@5.11.8/swagger-ui-bundle.js"></script>
  <script src="https://cdn.jsdelivr.net/npm/swagger-ui-dist@5.11.8/swagger-ui-standalone-preset.js"></script>
  <script>
    window.onload = function () {
      const ui = SwaggerUIBundle({
        url: 'service.json',
        dom_id: '#swagger-ui',
        deepLinking: true,
        persistAuthorization: true,
        displayOperationId: false,
        docExpansion: 'list',
        defaultModelsExpandDepth: 1,
        defaultModelExpandDepth: 1,
        showExtensions: true,
        supportedSubmitMethods: ['get', 'post', 'put', 'delete', 'patch'],
        presets: [
          SwaggerUIBundle.presets.apis,
          SwaggerUIStandalonePreset
        ],
        layout: 'StandaloneLayout'
      });
      window.ui = ui;
    };
  </script>
</body>
</html>
