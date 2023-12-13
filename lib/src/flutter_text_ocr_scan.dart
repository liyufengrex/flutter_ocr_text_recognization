import 'dart:developer';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import './text_recognizer_painter.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:camera/camera.dart';

class TextOrcScan extends StatefulWidget {
  const TextOrcScan({
    Key? key,
    this.painBoxLeftOff = 4,
    this.painBoxRightOff = 4,
    this.painBoxBottomOff = 2.7,
    this.painBoxTopOff = 2.7,
    this.boxRadius = 0,
    required this.widgetHeight,
    required this.getScannedText,
    this.paintboxCustom,
    this.throttlingInterval = const Duration(milliseconds: 900),
  }) : super(key: key);

  final double widgetHeight;

  final double boxRadius;

  final Paint? paintboxCustom;

  final double painBoxLeftOff, painBoxBottomOff, painBoxRightOff, painBoxTopOff;

  final Duration throttlingInterval;

  final Function getScannedText;

  @override
  TextOrcScanState createState() => TextOrcScanState();
}

class TextOrcScanState extends State<TextOrcScan> with WidgetsBindingObserver{
  final TextRecognizer _textRecognizer = TextRecognizer();
  final cameraPrev = GlobalKey();

  bool _isBusy = false;
  CustomPaint? customPaint;

  CameraController? _controller;
  late List<CameraDescription> _cameras;
  double zoomLevel = 3.0, minZoomLevel = 0.0, maxZoomLevel = 10.0;

  // Counting pointers (number of user fingers on screen)
  final double _minAvailableZoom = 1.0;
  final double _maxAvailableZoom = 10.0;
  double _currentScale = 3.0;
  double _baseScale = 3.0;
  final double previewAspectRatio = 0.5;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    startLiveFeed();
  }

  @override
  void dispose() {
    _stopLiveFeed();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed) {
      startLiveFeed();
    } else if (state == AppLifecycleState.paused) {
      _stopLiveFeed();
    }
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: widget.widgetHeight,
      child: _controller == null ||
              _controller?.value == null ||
              _controller?.value.isInitialized == false
          ? Container(
              decoration: BoxDecoration(
                color: Colors.grey,
                borderRadius: BorderRadius.circular(17),
              ),
            )
          : _cameraFeedBody(),
    );
  }

  Widget _cameraFeedBody() {
    final CameraController? cameraController = _controller;
    if (cameraController == null || !cameraController.value.isInitialized) {
      return const Text('Tap a camera');
    } else {
      return Stack(
        alignment: Alignment.topCenter,
        clipBehavior: Clip.none,
        fit: StackFit.expand,
        children: <Widget>[
          SizedBox.expand(
            key: cameraPrev,
            child: AspectRatio(
              aspectRatio: 1 / previewAspectRatio,
              child: ClipRRect(
                borderRadius: BorderRadius.all(
                  Radius.circular(widget.boxRadius),
                ),
                child: Transform.scale(
                  scale:
                      cameraController.value.aspectRatio / previewAspectRatio,
                  child: Center(
                    child: CameraPreview(
                      cameraController,
                      child: finderTapContainer(),
                    ),
                  ),
                ),
              ),
            ),
          ),
          if (customPaint != null) finderTapContainer(child: customPaint!),
        ],
      );
    }
  }

  Widget finderTapContainer({Widget? child}) {
    return LayoutBuilder(
      builder: (
        BuildContext context,
        BoxConstraints constraints,
      ) {
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onScaleStart: _handleScaleStart,
          onScaleUpdate: _handleScaleUpdate,
          onTapDown: (TapDownDetails details) => onViewFinderTap(
            details,
            constraints,
          ),
          child: child,
        );
      },
    );
  }

  // Start camera stream function
  Future startLiveFeed() async {
    _cameras = await availableCameras();
    if (_cameras.isEmpty) {
      return;
    }
    _controller = CameraController(
      _cameras[0],
      ResolutionPreset.max,
    );
    final camera = _cameras[0];
    _controller = CameraController(
      camera,
      ResolutionPreset.high,
      enableAudio: false,
    );
    _controller?.initialize().then((_) {
      if (!mounted) {
        return;
      }
      _controller?.getMinZoomLevel().then((value) {
        zoomLevel = value;
        minZoomLevel = value;
      });
      _controller?.getMaxZoomLevel().then((value) {
        maxZoomLevel = value;
      });
      _controller?.startImageStream(_processCameraImage);
      setState(() {});
    }).catchError((Object e) {
      if (e is CameraException) {
        switch (e.code) {
          case 'CameraAccessDenied':
            log('User denied camera access.');
            break;
          default:
            log('Handle other errors.');
            break;
        }
      }
    });
  }

  // Process image from camera stream
  Future _processCameraImage(CameraImage image) async {
    final WriteBuffer allBytes = WriteBuffer();
    for (final Plane plane in image.planes) {
      allBytes.putUint8List(plane.bytes);
    }
    final bytes = allBytes.done().buffer.asUint8List();

    final Size imageSize = Size(
      image.width.toDouble(),
      image.height.toDouble(),
    );

    final camera = _cameras[0];
    final imageRotation = InputImageRotationValue.fromRawValue(
      camera.sensorOrientation,
    );
    if (imageRotation == null) return;

    final inputImageFormat = InputImageFormatValue.fromRawValue(
      image.format.raw,
    );
    if (inputImageFormat == null) return;

    final planeData = InputImageMetadata(
      size: imageSize,
      rotation: imageRotation,
      format: inputImageFormat,
      bytesPerRow: image.planes[0].bytesPerRow,
    );
    final inputImage = InputImage.fromBytes(
      bytes: bytes,
      metadata: planeData,
    );
    processImage(inputImage);
  }

  // Scale image
  void _handleScaleStart(ScaleStartDetails details) {
    _baseScale = _currentScale;
  }

  // Handle scale update
  Future<void> _handleScaleUpdate(ScaleUpdateDetails details) async {
    if (_controller == null) {
      return;
    }
    _currentScale = (_baseScale * details.scale).clamp(
      _minAvailableZoom,
      _maxAvailableZoom,
    );
    await _controller!.setZoomLevel(_currentScale);
  }

  // Focus image
  void onViewFinderTap(
    TapDownDetails details,
    BoxConstraints constraints,
  ) {
    if (_controller == null) {
      return;
    }
    final CameraController cameraController = _controller!;
    final Offset offset = Offset(
      details.localPosition.dx / constraints.maxWidth,
      details.localPosition.dy / constraints.maxHeight,
    );
    cameraController.setExposurePoint(offset);
    cameraController.setFocusPoint(offset);
  }

  Future _stopLiveFeed() async {
    await _controller?.stopImageStream();
    await _controller?.dispose();
    _controller = null;
  }

  Future<void> processImage(InputImage inputImage) async {
    if (_isBusy) return;
    _isBusy = true;
    final recognizedText = await _textRecognizer.processImage(inputImage);
    if (inputImage.metadata?.size != null &&
        inputImage.metadata?.rotation != null &&
        cameraPrev.currentContext != null) {
      final renderBox = cameraPrev.currentContext?.findRenderObject();
      if (renderBox == null) {
        return;
      }
      var painter = TextRecognizerPainter(
        recognizedText,
        inputImage.metadata!.size,
        inputImage.metadata!.rotation,
        renderBox as RenderBox,
        (value) {
          widget.getScannedText(value);
        },
        boxLeftOff: widget.painBoxLeftOff,
        boxBottomOff: widget.painBoxBottomOff,
        boxRightOff: widget.painBoxRightOff,
        boxTopOff: widget.painBoxTopOff,
        paintboxCustom: widget.paintboxCustom,
      );
      customPaint = CustomPaint(painter: painter);
    } else {
      customPaint = null;
    }
    Future.delayed(widget.throttlingInterval).then(
      (value) {
        _isBusy = false;
        if (mounted) {
          setState(() {});
        }
      },
    );
  }
}
