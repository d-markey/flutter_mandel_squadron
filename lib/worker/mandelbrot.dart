import 'dart:async';
import 'dart:typed_data';

import 'package:squadron/squadron.dart';
import 'package:squadron/squadron_annotations.dart';

import 'mandelbrot.activator.g.dart';

part 'mandelbrot.worker.g.dart';

@SquadronService(baseUrl: '/worker')
class Mandelbrot extends WorkerService {
  static const int maxIterations = 2000;

  static List<List<int>> levelColors = [
    [0, 0xff000435],
    [1, 0xff00086b], // dark blue background
    [2, 0xff0010d6],
    [100, 0xffffff00], // yellow
    [200, 0xffff0000], // red
    [400, 0xff00ff00], // green
    [600, 0xff00ffff], // cyan
    [800, 0xfffefefe], // white
    [900, 0xff808080], // gray
    [1000, 0xff000000], // black
    [1200, 0xff00ffff], // cyan
    [1400, 0xff00ff00], // green
    [1600, 0xffff0000], // red
    [1800, 0xffffff00], // yellow
    [1900, 0xffffff00], // yellow
    [2000, 0xff000000] // black
  ];

  static int iterations(double x0, double y0) {
    if (y0 < 0) {
      y0 = -y0;
    }
    var x = x0;
    var y = y0;

    var y2 = y * y;

    // Filter out points in the main cardiod
    if (-0.75 < x && x < 0.38 && y < 0.66) {
      final q = (x - 0.25) * (x - 0.25) + y2;
      if (q * (q + x - 0.25) < 0.25 * y2) {
        return maxIterations;
      }
    }

    // Filter out points in bulb of radius 1/4 around (-1,0)
    if (-1.25 < x && x < -0.75 && y < 0.25) {
      final d = (x + 1) * (x + 1) + y2;
      if (d < 1 / 16) {
        return maxIterations;
      }
    }

    for (int i = 0; i < maxIterations; i++) {
      final x2 = x * x;
      y2 = y * y;
      if (x2 + y2 > 4) {
        return i;
      }

      final xT = x2 - y2 + x0;
      y = 2 * x * y + y0;
      x = xT;
    }

    return maxIterations;
  }

  static int colorFromLevel(int level) {
    // Interpolate control points in this.levelColors
    // to map levels to colors.
    int iMin = 0;
    int iMax = levelColors.length;
    while (iMin < iMax - 1) {
      final iMid = (iMin + iMax) ~/ 2;
      final levelT = levelColors[iMid][0];
      if (levelT == level) {
        return levelColors[iMid][1];
      }
      if (levelT < level) {
        iMin = iMid;
      } else {
        iMax = iMid;
      }
    }

    var levelMin = levelColors[iMin][0];
    var levelMax = levelColors[iMax][0];
    // Make sure we are not overly sensitive to rounding
    final p = (level - levelMin) / (levelMax - levelMin);

    var colMin = levelColors[iMin][1];
    var colMax = levelColors[iMax][1];
    var color = 0;
    for (var i = 0; i < 4; i++) {
      final cMin = colMin >> i * 8 & 0xff;
      final cMax = colMax >> i * 8 & 0xff;
      final value = (cMin + p * (cMax - cMin)).toInt();
      color += (value << i * 8);
    }

    return color;
  }

  static void delay() {
    int i = 1000;
    while (i > 0) {
      i--;
    }
  }

  @SquadronMethod()
  Future<ByteBuffer> renderData(
    double xMin,
    double xMax,
    double yMin,
    double yMax, {
    CancellationToken? clToken,
    required int bitmapWidth,
    required int bitmapHeight,
  }) async {
    final data = Uint32List(bitmapHeight * bitmapWidth);

    // Per-pixel step values
    final dx = (xMax - xMin) / bitmapWidth;
    final dy = (yMax - yMin) / bitmapHeight;

    var y = yMin + dy / 2;
    var idx = 0;
    for (int iy = 0; iy < bitmapHeight; iy++) {
      if (iy % 10 == 0) {
        // Yield every once in a while to allow for cancellation notifications
        // to pass through.
        await Future.delayed(Duration.zero);
        if (clToken?.cancelled ?? false) {
          Squadron.info(
              'Task cancelled during computation: iy = $iy / $bitmapHeight');
          break;
        }
      }

      var x = xMin + dx / 2;
      for (int ix = 0; ix < bitmapWidth; ix++) {
        final iters = iterations(x, y);
        data[idx++] = colorFromLevel(iters);
        x += dx;
      }
      y += dy;
    }

    return data.buffer;
  }

  @override
  late final Map<int, CommandHandler> operations =
      buildMandelbrotOperations(this);
}
