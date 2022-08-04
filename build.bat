call dart run build_runner build

call dart compile js .\lib\worker\mandelbrot.web.g.dart -o .\web\worker\mandelbrot.web.g.dart.js -m
