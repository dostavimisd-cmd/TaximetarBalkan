import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart';
import '../../domain/models/app_settings.dart';
import '../../domain/models/ride_record.dart';
import '../../domain/printing/dither.dart';
import '../../domain/printing/escpos.dart';
import '../../domain/printing/receipt.dart';
import '../providers/history_provider.dart';
import '../providers/settings_provider.dart';

/// Izbor načina štampe naših slova. Brojevi kodnih strana zavise od firmvera
/// kineskih štampača; korisnik bira red koji je na probnoj štampi ispravan.
class PrintOption {
  final String label;
  final PrintMode mode;
  final int codePage;

  const PrintOption(this.label, this.mode, [this.codePage = 0]);

  static const List<PrintOption> all = [
    PrintOption('A) Kao slika (uvek tačno)', PrintMode.image),
    PrintOption('B) Tekst CP852 (ESC t 18)', PrintMode.cp852, 18),
    PrintOption('C) Tekst CP1250 (ESC t 45)', PrintMode.cp1250, 45),
    PrintOption('D) Tekst CP1250 (ESC t 30)', PrintMode.cp1250, 30),
    PrintOption('E) Tekst CP1250 (ESC t 72)', PrintMode.cp1250, 72),
    PrintOption('F) Bez kvačica (c, s, z, dj)', PrintMode.plain),
  ];

  static PrintOption of(AppSettings s) => all.firstWhere(
        (o) => o.mode == s.printMode && (o.codePage == s.printCodePage || o.codePage == 0),
        orElse: () => all.first,
      );
}

class PrintException implements Exception {
  final String message;
  const PrintException(this.message);
  @override
  String toString() => message;
}

/// Šalje račun na upareni Bluetooth termalni štampač (58 mm, ESC/POS).
class ReceiptPrinter {
  Future<void> _ensurePermission() async {
    if (!(await Permission.bluetoothConnect.request()).isGranted) {
      throw const PrintException('Potrebna je dozvola za Bluetooth uređaje u blizini.');
    }
    if (!await PrintBluetoothThermal.bluetoothEnabled) {
      throw const PrintException('Bluetooth je isključen.');
    }
  }

  Future<List<BluetoothInfo>> paired() async {
    await _ensurePermission();
    return PrintBluetoothThermal.pairedBluetooths;
  }

  Future<void> send(String mac, List<int> bytes) async {
    await _ensurePermission();
    if (await PrintBluetoothThermal.connectionStatus) {
      await PrintBluetoothThermal.disconnect;
    }
    if (!await PrintBluetoothThermal.connect(macPrinterAddress: mac)) {
      throw const PrintException('Štampač nije dostupan. Da li je uključen i uparen?');
    }
    try {
      if (!await PrintBluetoothThermal.writeBytes(bytes)) {
        throw const PrintException('Slanje na štampač nije uspelo.');
      }
    } finally {
      await PrintBluetoothThermal.disconnect;
    }
  }

  // ---------------------------------------------------------------- bajtovi

  /// Širina logoa na papiru (tačke); ostatak do 384 je beli rub.
  static const int logoWidth = 256;

  /// Logo firme kao raster (dithering), centriran; null ako slika ne može da
  /// se pročita (tada se račun štampa bez logoa).
  static Future<List<int>?> logoBytes(String path) async {
    try {
      final codec = await ui.instantiateImageCodec(await File(path).readAsBytes(),
          targetWidth: logoWidth);
      final frame = await codec.getNextFrame();
      final image = frame.image;
      final w = image.width, h = image.height;
      final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
      image.dispose();
      final rgba = data!.buffer.asUint8List();
      final lum = List<int>.generate(w * h, (i) {
        final o = i * 4;
        final a = rgba[o + 3];
        final l = (rgba[o] * 299 + rgba[o + 1] * 587 + rgba[o + 2] * 114) ~/ 1000;
        return (l * a + 255 * (255 - a)) ~/ 255; // providno = belo
      });
      final pixels = Dither.centerOnWidth(
          w, h, Dither.floydSteinberg(w, h, lum), EscPos.dotsPerLine);
      return EscPos.raster(EscPos.dotsPerLine, h, pixels);
    } catch (_) {
      return null;
    }
  }

  static Future<List<int>> receiptBytes(List<ReceiptLine> lines, PrintMode mode, int codePage,
      {String? logoPath}) async {
    final out = <int>[...EscPos.init];
    if (logoPath != null) {
      final logo = await logoBytes(logoPath);
      if (logo != null) out.addAll([...EscPos.align(0), ...logo, 0x0A]);
    }
    if (mode == PrintMode.image) {
      final img = await renderLines(lines);
      out
        ..addAll(EscPos.align(0))
        ..addAll(EscPos.raster(img.width, img.height, img.pixels));
    } else {
      if (mode != PrintMode.plain) out.addAll(EscPos.codePage(codePage));
      for (final l in lines) {
        out
          ..addAll(EscPos.align(l.align.index))
          ..addAll(EscPos.bold(l.bold))
          ..addAll(EscPos.large(l.large))
          ..addAll(EscPos.encode(l.text, mode))
          ..add(0x0A);
      }
      out
        ..addAll(EscPos.large(false))
        ..addAll(EscPos.bold(false));
    }
    return out..addAll(EscPos.feed(4));
  }

  /// Svaka opcija štampa naša slova; korisnik bira ispravan red.
  static Future<List<int>> testPageBytes() async {
    final out = <int>[...EscPos.init, ...EscPos.align(0)];
    out
      ..addAll(EscPos.encode('PROBNA STAMPA - izaberi red', PrintMode.plain))
      ..addAll([0x0A])
      ..addAll(EscPos.encode('u kome su slova ispravna:', PrintMode.plain))
      ..addAll([0x0A, 0x0A]);
    for (final o in PrintOption.all) {
      final label = o.label.split(')').first; // "A", "B", ...
      if (o.mode == PrintMode.image) {
        final img = await renderLines([ReceiptLine('$label) ${Receipt.sample}')]);
        out.addAll(EscPos.raster(img.width, img.height, img.pixels));
      } else {
        if (o.mode != PrintMode.plain) out.addAll(EscPos.codePage(o.codePage));
        out
          ..addAll(EscPos.encode('$label) ', PrintMode.plain))
          ..addAll(EscPos.encode(Receipt.sample, o.mode))
          ..add(0x0A);
      }
    }
    return out..addAll(EscPos.feed(4));
  }

  /// Crta redove računa u sliku širine štampača (384 tačke), crno-belo.
  static Future<({int width, int height, List<bool> pixels})> renderLines(
      List<ReceiptLine> lines) async {
    const width = EscPos.dotsPerLine;
    final painters = [
      for (final l in lines)
        (
          l,
          TextPainter(
            text: TextSpan(
              text: l.text,
              style: TextStyle(
                color: Colors.black,
                fontFamily: 'monospace',
                fontSize: l.large ? 38 : 19,
                fontWeight: l.bold ? FontWeight.w700 : FontWeight.w400,
              ),
            ),
            textDirection: TextDirection.ltr,
            maxLines: 3,
          )..layout(maxWidth: width.toDouble()),
        ),
    ];
    final height = painters.fold<double>(4, (h, p) => h + p.$2.height + 2).ceil();

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.drawRect(Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()),
        Paint()..color = Colors.white);
    var y = 2.0;
    for (final (line, painter) in painters) {
      final x = switch (line.align) {
        ReceiptAlign.left => 0.0,
        ReceiptAlign.center => (width - painter.width) / 2,
        ReceiptAlign.right => width - painter.width,
      };
      painter.paint(canvas, Offset(x, y));
      y += painter.height + 2;
    }
    final image = await recorder.endRecording().toImage(width, height);
    final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    image.dispose();
    final bytes = data!.buffer.asUint8List();
    final pixels = List<bool>.generate(width * height, (i) {
      final o = i * 4;
      final lum = (bytes[o] * 299 + bytes[o + 1] * 587 + bytes[o + 2] * 114) ~/ 1000;
      return lum < 160;
    });
    return (width: width, height: height, pixels: pixels);
  }
}

final receiptPrinterProvider = Provider<ReceiptPrinter>((ref) => ReceiptPrinter());

/// Štampa račun vožnje sa podešavanjima korisnika i javlja ishod.
Future<void> printRideReceipt(BuildContext context, WidgetRef ref, int rideId) async {
  final messenger = ScaffoldMessenger.of(context);
  void say(String m) => messenger.showSnackBar(SnackBar(content: Text(m)));
  final settings = ref.read(appSettingsProvider).value ?? const AppSettings();
  final mac = settings.printerMac;
  if (mac == null) {
    say('Izaberi štampač u Podešavanjima.');
    return;
  }
  try {
    final RideRecord? ride = await ref.read(rideHistoryRepositoryProvider).getById(rideId);
    if (ride == null) throw const PrintException('Vožnja nije pronađena.');
    final lines = Receipt.forRide(
      ride,
      header: settings.receiptHeader.split('\n'),
      eurRateMilli: settings.eurRateMilli,
    );
    final bytes = await ReceiptPrinter.receiptBytes(lines, settings.printMode, settings.printCodePage,
        logoPath: settings.receiptLogoPath);
    await ref.read(receiptPrinterProvider).send(mac, bytes);
    say('Račun je poslat na štampač.');
  } catch (e) {
    say('Štampa nije uspela: $e');
  }
}
