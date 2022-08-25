import 'dart:async';
import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:squadron/squadron.dart';

import 'worker/mandelbrot.dart';

class MandleView extends StatefulWidget {
  const MandleView({
    Key? key,
    required this.width,
    required this.height,
    required this.centerCoord,
    required this.renderWidth,
    required this.workers,
  })  : aspect = width / height,
        renderHeight = (height * renderWidth) / width,
        super(key: key);

  final int width;
  final int height;
  final Offset centerCoord;
  final double renderWidth;

  final List<Mandelbrot> workers;

  final double aspect;
  final double renderHeight;

  Offset get renderOffset => Offset(renderWidth, renderHeight);

  @override
  State<MandleView> createState() => _MandleViewState();
}

class _MandleViewState extends State<MandleView> {
  FrameInfo? _frameToDisplay;
  CancellationToken _token = CancellationToken();

  static int _renderId = 0;

  @override
  void initState() {
    super.initState();
    _renderMandel();
  }

  @override
  void didUpdateWidget(covariant MandleView oldWidget) {
    super.didUpdateWidget(oldWidget);
    _renderMandel();
  }

  Future _renderMandel() async {
    _token.cancel();

    final renderId = (++_renderId);
    Squadron.info('[$renderId] Start rendering');

    final token = CancellationToken('Render id = $renderId');
    _token = token;

    final workers = widget.workers;

    final sw = Stopwatch();
    sw.start();

    final xMin = widget.centerCoord.dx - widget.renderWidth / 2;
    final xMax = widget.centerCoord.dx + widget.renderWidth / 2;

    final ySpan = widget.renderHeight / workers.length;

    var yMin = widget.centerCoord.dy - widget.renderHeight / 2;
    var yMax = yMin + ySpan;

    final wSpan = widget.width;
    var hSpan = widget.height ~/ workers.length;

    int maxElapsed = 0;

    // This function returns a Future that complete when the worker has finished
    // computing its batch
    Future<Uint8List> _computeMandel(Mandelbrot worker) {
      final workerInfo =
          'Worker #${worker is MandelbrotWorker ? worker.workerId : 'single-thread'} $yMin->$yMax';
      return worker
          .renderData(
        xMin,
        xMax,
        yMin,
        yMax,
        clToken: token,
        bitmapWidth: wSpan,
        bitmapHeight: hSpan,
      )
          .then((buffer) {
        final elapsed = sw.elapsedMilliseconds;
        if (elapsed > maxElapsed) maxElapsed = elapsed;
        Squadron.info('[$renderId]   $workerInfo completed in $elapsed ms');
        return buffer.asUint8List();
      });
    }

    // Have the first workers compute each partial bitmap.
    // The last worker will be assigned a different batch.
    final computations = <Future<Uint8List>>[];
    for (var worker in workers.take(workers.length - 1)) {
      computations.add(_computeMandel(worker));
      yMin = yMax;
      yMax = yMin + ySpan;
    }

    // The last batch must include the pixels at the bottom of the widget, which
    // may have been lost due to rounding errors depending on the number of workers.
    // Adjust coordinates accordingly.
    final lastHSpan = hSpan + widget.height - hSpan * workers.length;
    final lastYSpan = ySpan * lastHSpan / hSpan;
    yMax = yMin + lastYSpan;
    hSpan = lastHSpan;

    final lastWorker = workers.last;
    final lastComputation = _computeMandel(lastWorker);
    computations.add(lastComputation);

    // Wait for computations to complete...
    try {
      final parts = await Future.wait(computations);

      if (parts.any((buffer) => buffer.isEmpty)) {
        throw CancelledException(message: 'Computation was cancelled');
      }

      final elapsed = sw.elapsedMilliseconds;
      Squadron.info(
          '[$renderId] Processing completed in $elapsed ms, maxElapsed = $maxElapsed ms');

      // Consolidate data...
      int size = 0;
      final blackLine =
          List.generate(wSpan * 4, (n) => n % 4 == 3 ? 0xFF : 0x00);
      for (var bytes in parts) {
        // uncomment the next line to visualize partial bitmaps
        // bytes.setRange(0, blackLine.length, blackLine);
        size += bytes.length;
      }
      final pixels = Uint8List(size);
      int offset = 0;
      for (var bytes in parts) {
        final end = offset + bytes.length;
        pixels.setRange(offset, end, bytes);
        offset = end;
      }

      // Display!
      final value = await ImmutableBuffer.fromUint8List(pixels);
      final codec = await ImageDescriptor.raw(value,
              width: widget.width,
              height: widget.height,
              pixelFormat: PixelFormat.bgra8888)
          .instantiateCodec();
      final frame = await codec.getNextFrame();
      setState(() => _frameToDisplay = frame);
    } catch (ex) {
      Squadron.info('[$renderId] Error ${ex.runtimeType}');
    }

    final elapsed = sw.elapsedMilliseconds;
    Squadron.info(token.cancelled
        ? '[$renderId] Render cancelled after $elapsed ms'
        : '[$renderId] Render completed in $elapsed ms, maxElapsed = $maxElapsed ms');
  }

  @override
  Widget build(BuildContext context) {
    final image = _frameToDisplay?.image;
    return (image == null)
        ? const Center(child: CircularProgressIndicator())
        : RawImage(image: image);
  }
}
