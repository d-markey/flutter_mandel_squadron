// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'mandelbrot.dart';

// **************************************************************************
// SquadronServiceGenerator
// **************************************************************************

Map<int, CommandHandler> buildMandelbrotOperations(Mandelbrot instance) => {
      1: (r) => instance.renderData(r.args[0], r.args[1], r.args[2], r.args[3],
          clToken: r.cancelToken,
          bitmapWidth: r.args[4],
          bitmapHeight: r.args[5]),
    };

// Worker for Mandelbrot
class MandelbrotWorker extends Worker implements Mandelbrot {
  MandelbrotWorker() : super($MandelbrotActivator);

  @override
  Future<ByteBuffer> renderData(
          double xMin, double xMax, double yMin, double yMax,
          {CancellationToken? clToken,
          required int bitmapWidth,
          required int bitmapHeight}) =>
      send(1,
          args: [xMin, xMax, yMin, yMax, bitmapWidth, bitmapHeight],
          token: clToken,
          inspectRequest: false,
          inspectResponse: false);
}

// Worker pool for Mandelbrot
class MandelbrotWorkerPool extends WorkerPool<MandelbrotWorker>
    implements Mandelbrot {
  MandelbrotWorkerPool({ConcurrencySettings? concurrencySettings})
      : super(() => MandelbrotWorker(),
            concurrencySettings: concurrencySettings);
  @override
  Future<ByteBuffer> renderData(
          double xMin, double xMax, double yMin, double yMax,
          {CancellationToken? clToken,
          required int bitmapWidth,
          required int bitmapHeight}) =>
      execute((w) => w.renderData(xMin, xMax, yMin, yMax,
          clToken: clToken,
          bitmapWidth: bitmapWidth,
          bitmapHeight: bitmapHeight));
}
