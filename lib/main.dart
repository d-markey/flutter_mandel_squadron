import 'package:flutter/material.dart';
import 'package:flutter_mandel/worker/mandelbrot.dart';
import 'package:squadron/squadron.dart';

import 'mandel_view.dart';

void main() {
  Squadron.setId('Mandelbrot');
  Squadron.setLogger(ConsoleSquadronLogger());
  Squadron.logLevel = SquadronLogLevel.all;
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: Scaffold(
        appBar: AppBar(
          title: const Text('Mandel Demo'),
        ),
        body: const MandelExplorer(),
      ),
    );
  }
}

class MandelExplorer extends StatefulWidget {
  const MandelExplorer({
    Key? key,
  }) : super(key: key);

  @override
  State<MandelExplorer> createState() => _MandelExplorerState();
}

class _MandelExplorerState extends State<MandelExplorer> {
  Offset upperLeft = const Offset(-2.05, -1.1);
  double renderWidth = 3.0;
  List<MandelbrotWorker> workers = [];

  @override
  void initState() {
    super.initState();
    for (var i = 0; i < 1; i++) {
      final w = MandelbrotWorker();
      workers.add(w);
      w.start();
    }
  }

  void _removeLastWorker() {
    if (workers.length > 1) {
      final w = workers.removeLast();
      w.stop();
      setState(() {});
    }
  }

  Future _addOneWorker() async {
    final w = MandelbrotWorker();
    await w.start();
    workers.add(w);
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final whiteButton = ButtonStyle(
        backgroundColor: MaterialStateProperty.all<Color>(Colors.white));
    return Stack(
      children: [
        LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) {
            return MandleView(
              width: constraints.maxWidth.toInt(),
              height: constraints.maxHeight.toInt(),
              upperLeftCoord: upperLeft,
              renderWidth: renderWidth,
              workers: workers,
            );
          },
        ),
        Positioned(
            left: 20,
            top: 20,
            child: Row(children: [
              TextButton(
                  onPressed: _removeLastWorker,
                  style: whiteButton,
                  child: const Text("-1")),
              Text(
                workers.length.toString(),
                style: const TextStyle(backgroundColor: Colors.white),
              ),
              TextButton(
                  onPressed: _addOneWorker,
                  style: whiteButton,
                  child: const Text("+1")),
            ])),
        Positioned(
            right: 60,
            bottom: 100,
            child: FloatingActionButton(
              mini: true,
              onPressed: (() {
                setState(() {
                  upperLeft = upperLeft.translate(0, -(renderWidth / 30));
                });
              }),
              child: const Icon(Icons.arrow_drop_up),
            )),
        Positioned(
            right: 20,
            bottom: 60,
            child: FloatingActionButton(
              mini: true,
              onPressed: (() {
                setState(() {
                  upperLeft = upperLeft.translate((renderWidth / 30), 0);
                });
              }),
              child: const Icon(Icons.arrow_right),
            )),
        Positioned(
            right: 100,
            bottom: 60,
            child: FloatingActionButton(
              mini: true,
              onPressed: (() {
                setState(() {
                  upperLeft = upperLeft.translate(-(renderWidth / 30), 0);
                });
              }),
              child: const Icon(Icons.arrow_left),
            )),
        // floatingActionButton: FloatingActionButton(
        Positioned(
            right: 60,
            bottom: 20,
            child: FloatingActionButton(
              mini: true,
              onPressed: (() {
                setState(() {
                  upperLeft = upperLeft.translate(0, (renderWidth / 30));
                });
              }),
              child: const Icon(Icons.arrow_drop_down),
            )),
        Positioned(
            right: 85,
            bottom: 150,
            child: FloatingActionButton(
              mini: true,
              onPressed: (() {
                setState(() {
                  renderWidth = renderWidth - (renderWidth / 30);
                  upperLeft = upperLeft.translate(
                      (renderWidth / 60), (renderWidth / 60));
                });
              }),
              child: const Icon(Icons.zoom_in),
            )),
        // floatingActionButton: FloatingActionButton(
        Positioned(
            right: 35,
            bottom: 150,
            child: FloatingActionButton(
              mini: true,
              onPressed: (() {
                setState(() {
                  renderWidth = renderWidth + 0.1;
                  upperLeft = upperLeft.translate(-0.05, -0.05);
                });
              }),
              child: const Icon(Icons.zoom_out),
            ))
      ],
    );
  }
}
