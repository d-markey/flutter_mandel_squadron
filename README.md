## Flutter-Mandel + Squadron

Forked from https://github.com/escamoteur/flutter_mandel which was ported from https://github.com/mckoss/dart-mandelbrot.

Then augmented with https://github.com/d-markey/squadron

1. First, generate Squadron cross-platform workers with:

```
dart run build_runner build
```

2. Then, compile Squadron Web worker to JavaScript with:

```
dart compile js .\lib\worker\mandelbrot.web.g.dart -o .\web\worker\mandelbrot.web.g.dart.js -m
```

3. Finally, run on desktop, mobile, and Web and start playing with workers!
