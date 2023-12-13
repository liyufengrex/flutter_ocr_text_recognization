# flutter_ocr_text_recognization

依赖 google_mlkit_text_recognition 实现的 OCR 文本识别相机，支持局部识别。

![示例.gif](https://p6-juejin.byteimg.com/tos-cn-i-k3u1fbpfcp/3964e042c89c45dc95ed28d2f131c375~tplv-k3u1fbpfcp-jj-mark:0:0:0:0:q75.image#?w=360&h=782&s=7377669&e=gif&f=122&b=f5f5f5)

## 使用方式

添加依赖：

```dart
dependencies:
  flutter_ocr_text_recognization: x.x.x
```

```dart
import 'package:flutter_ocr_text_recognization/flutter_ocr_text_scan.dart';
```

示例：

```dart
TextOrcScan(
      paintboxCustom: Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 4.0
          ..color = const Color.fromARGB(153, 102, 160, 241),
      boxRadius: 12,
      painBoxLeftOff: 5,
      painBoxBottomOff: 2.5,
      painBoxRightOff: 5,
      painBoxTopOff: 2.5,
      widgetHeight: MediaQuery.of(context).size.height / 3,
      getScannedText: (value) {
        setText(value);
      },
)
```

参考自 https://pub-web.flutter-io.cn/packages/flutter_scalable_ocr ， 因项目需要，修复部分原库发现的问题，新建本库。