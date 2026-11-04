import 'dart:typed_data';
import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

/// Fontovi sa našim slovima (č ć ž š đ); ugrađeni PDF fontovi ih nemaju.
Future<({pw.Font regular, pw.Font bold})> loadReportFonts() async => (
      regular: pw.Font.ttf(await rootBundle.load('assets/fonts/NotoSans-Regular.ttf')),
      bold: pw.Font.ttf(await rootBundle.load('assets/fonts/NotoSans-Bold.ttf')),
    );

/// PDF izveštaja: zaglavlje firme (i logo), period, zbir i tabela vožnji.
/// Tekstovi su već prevedeni; korisnički podaci (zaglavlje) se ne prevode.
/// U [summary] `null` znači razdelnu liniju.
Future<Uint8List> buildReportPdf({
  required String title,
  required String period,
  required List<String> headerLines,
  Uint8List? logo,
  required List<(String, String)?> summary,
  required List<String> columns,
  required List<List<String>> rows,
  required String footer,
  required pw.Font regular,
  required pw.Font bold,
}) {
  final doc = pw.Document(
    theme: pw.ThemeData.withFont(base: regular, bold: bold),
    title: '$title $period',
    creator: 'Taksimetar Balkan',
  );
  final muted = PdfColor.fromInt(0xFF666666);
  final header = headerLines.where((l) => l.trim().isNotEmpty).toList();

  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.fromLTRB(36, 36, 36, 40),
      footer: (ctx) => pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(footer, style: pw.TextStyle(fontSize: 8, color: muted)),
          pw.Text('${ctx.pageNumber}/${ctx.pagesCount}',
              style: pw.TextStyle(fontSize: 8, color: muted)),
        ],
      ),
      build: (ctx) => [
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            if (logo != null)
              pw.Padding(
                padding: const pw.EdgeInsets.only(right: 12),
                child: pw.Image(pw.MemoryImage(logo), width: 64, height: 64,
                    fit: pw.BoxFit.contain),
              ),
            pw.Expanded(
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  for (final (i, l) in header.indexed)
                    pw.Text(l, style: i == 0
                        ? pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold)
                        : const pw.TextStyle(fontSize: 10)),
                ],
              ),
            ),
          ],
        ),
        pw.SizedBox(height: 14),
        pw.Text(title, style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
        pw.Text(period, style: pw.TextStyle(fontSize: 12, color: muted)),
        pw.SizedBox(height: 12),
        pw.Container(
          width: 280,
          child: pw.Column(
            children: [
              for (final (i, r) in summary.indexed)
                if (r == null)
                  pw.Divider(height: 8, thickness: 0.5, color: PdfColors.grey400)
                else
                  pw.Padding(
                    padding: const pw.EdgeInsets.symmetric(vertical: 2),
                    child: pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text(r.$1, style: const pw.TextStyle(fontSize: 10)),
                        pw.Text(r.$2, style: pw.TextStyle(
                            fontSize: i == 0 ? 13 : 10,
                            fontWeight: i == 0 ? pw.FontWeight.bold : pw.FontWeight.normal)),
                      ],
                    ),
                  ),
            ],
          ),
        ),
        pw.SizedBox(height: 16),
        if (rows.isNotEmpty)
          pw.TableHelper.fromTextArray(
            headers: columns,
            data: rows,
            headerStyle: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold),
            cellStyle: const pw.TextStyle(fontSize: 8.5),
            headerDecoration: const pw.BoxDecoration(color: PdfColors.grey200),
            cellAlignments: {
              for (var c = 2; c < columns.length - 1; c++) c: pw.Alignment.centerRight,
            },
            border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
            cellPadding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 3),
          ),
      ],
    ),
  );
  return doc.save();
}
