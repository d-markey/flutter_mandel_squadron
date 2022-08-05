import 'dart:async';
import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:squadron/squadron.dart';

import 'worker/mandelbrot.dart';

class MandleView extends StatefulWidget {
  final int width;
  final int height;
  final Offset upperLeftCoord;
  final double renderWidth;
  final List<Mandelbrot> workers;
  const MandleView({
    Key? key,
    required this.width,
    required this.height,
    required this.upperLeftCoord,
    required this.renderWidth,
    required this.workers,
  }) : super(key: key);

  @override
  State<MandleView> createState() => _MandleViewState();
}

class _MandleViewState extends State<MandleView> {
  FrameInfo? frameToDisplay;

  CancellationToken? _token;

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

  void _renderMandel() async {
    if (_token != null) {
      Squadron.info('Cancel pending rendering');
      _token?.cancel();
    }
    final token = CancellationToken(DateTime.now().toIso8601String());
    _token = token;

    final workers = widget.workers;

    Squadron.info('Start rendering');

    final sw = Stopwatch();
    sw.start();

    final double aspect = widget.width / widget.height;

    final xMin = widget.upperLeftCoord.dx;
    final xMax = widget.upperLeftCoord.dx + widget.renderWidth;

    final ySpan = (widget.renderWidth / aspect) / workers.length;

    var yMin = widget.upperLeftCoord.dy;
    var yMax = yMin + ySpan;

    final wSpan = widget.width;
    var hSpan = widget.height ~/ workers.length;

    // Have the first workers compute each partial bitmap.
    // The last worker will be assigned a different batch.
    final computations = <Future<ByteBuffer>>[];
    for (var worker in workers.take(workers.length - 1)) {
      computations.add(worker
          .renderData(
        xMin,
        xMax,
        yMin,
        yMax,
        clToken: token,
        bitmapWidth: wSpan,
        bitmapHeight: hSpan,
      )
          .whenComplete(() {
        Squadron.info(
            '   Worker #${worker is MandelbrotWorker ? worker.workerId : 'single-thread'} completed in ${sw.elapsed}');
      }));
      yMin = yMax;
      yMax = yMin + ySpan;
    }

    // The last batch must include the pixels at the bottom of the widget, which
    // may have been lost due to rounding errors depending on the number of workers.
    // As a result, the last partial bitmap may be slightly deformed, I need to work
    // out the maths to adjust yMax accordingly.
    hSpan += widget.height - hSpan * workers.length;
    final worker = workers.last;
    computations.add(worker
        .renderData(
      xMin,
      xMax,
      yMin,
      yMax,
      clToken: token,
      bitmapWidth: wSpan,
      bitmapHeight: hSpan,
    )
        .whenComplete(() {
      Squadron.info(
          '   Worker #${worker is MandelbrotWorker ? worker.workerId : 'single-thread'} completed in ${sw.elapsed}');
    }));

    // Wait for computations to complete...
    try {
      final parts =
          (await Future.wait(computations)).map((b) => b.asUint8List());

      _token = null;

      // Consolidate data...
      final size = parts.map((l) => l.length).reduce((s, l) => s + l);
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
      setState(() => frameToDisplay = frame);
    } catch (ex) {
      Squadron.info('Error ${ex.runtimeType}');
    }

    sw.stop();
    Squadron.info('Render completed in ${sw.elapsed}');
  }

  @override
  Widget build(BuildContext context) {
    if (frameToDisplay != null) {
      return RawImage(
        image: frameToDisplay!.image,
      );
    } else {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }
  }
}
