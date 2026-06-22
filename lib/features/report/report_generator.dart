import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../core/diagnosis/models/diagnosis_result.dart';
import '../../core/diagnosis/models/sensor_summary.dart';

class ReportGenerator {
  ReportGenerator._();

  static Future<void> generate({
    required BuildContext context,
    required DiagnosisResult result,
    required List<SensorSummary> completedTests,
    String vehicleDescription = 'Vehicle',
    String driverComplaint = '',
    DateTime? date,
  }) async {
    final pdf = _buildPdf(
      result: result,
      completedTests: completedTests,
      vehicleDescription: vehicleDescription,
      driverComplaint: driverComplaint,
      date: date ?? DateTime.now(),
    );

    await Printing.layoutPdf(
      onLayout: (_) async => pdf.save(),
      name: 'OBD2_Diagnostic_Report_${DateTime.now().millisecondsSinceEpoch}.pdf',
    );
  }

  static pw.Document _buildPdf({
    required DiagnosisResult result,
    required List<SensorSummary> completedTests,
    required String vehicleDescription,
    required String driverComplaint,
    required DateTime date,
  }) {
    final pdf = pw.Document();

    final accentColor = PdfColor.fromHex('#E8B84B');
    final darkBg = PdfColor.fromHex('#0D0D0F');
    final mutedColor = PdfColor.fromHex('#6B6B78');

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        theme: pw.ThemeData(
          defaultTextStyle: pw.TextStyle(
            color: PdfColors.black,
            fontSize: 10,
          ),
        ),
        build: (context) => [
          // Header
          pw.Container(
            color: darkBg,
            padding: const pw.EdgeInsets.all(20),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'OBD2 Diagnostic Report',
                  style: pw.TextStyle(
                    color: accentColor,
                    fontSize: 22,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 6),
                pw.Text(
                  '$vehicleDescription  •  ${_formatDate(date)}',
                  style: pw.TextStyle(color: mutedColor, fontSize: 10),
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 16),

          // Driver complaint
          if (driverComplaint.isNotEmpty) ...[
            _sectionTitle('Driver Complaint', accentColor),
            pw.Text(driverComplaint),
            pw.SizedBox(height: 16),
          ],

          // Primary diagnosis
          _sectionTitle('Diagnosis', accentColor),
          pw.Container(
            padding: const pw.EdgeInsets.all(12),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(
                  color: accentColor, width: 1),
              borderRadius: const pw.BorderRadius.all(
                  pw.Radius.circular(6)),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  result.primaryFault,
                  style: pw.TextStyle(
                      fontWeight: pw.FontWeight.bold, fontSize: 14),
                ),
                pw.SizedBox(height: 6),
                pw.Row(children: [
                  _badge('SEVERITY: ${result.severity.toUpperCase()}',
                      accentColor),
                  pw.SizedBox(width: 8),
                  _badge(
                      'CONFIDENCE: ${result.confidence.toUpperCase()}',
                      PdfColor.fromHex('#4CAF82')),
                ]),
              ],
            ),
          ),
          pw.SizedBox(height: 16),

          // Evidence
          _sectionTitle('Supporting Evidence', accentColor),
          for (final e in result.evidence)
            pw.Padding(
              padding: const pw.EdgeInsets.only(bottom: 4),
              child: pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text('• ',
                      style:
                          pw.TextStyle(color: accentColor)),
                  pw.Expanded(child: pw.Text(e)),
                ],
              ),
            ),
          pw.SizedBox(height: 16),

          // Recommended action
          _sectionTitle('Recommended Action', accentColor),
          pw.Text(result.recommendedAction),
          pw.SizedBox(height: 16),

          // Tests table
          if (completedTests.isNotEmpty) ...[
            _sectionTitle('Tests Performed', accentColor),
            pw.TableHelper.fromTextArray(
              headers: ['Test', 'Duration', 'Samples', 'Events'],
              data: completedTests
                  .map((t) => [
                        t.testId.replaceAll('_', ' '),
                        '${t.durationSeconds}s',
                        '${t.sampleCount}',
                        '${t.notableEvents.length}',
                      ])
                  .toList(),
              headerStyle: pw.TextStyle(
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.white,
              ),
              headerDecoration:
                  pw.BoxDecoration(color: darkBg),
              cellPadding: const pw.EdgeInsets.all(6),
            ),
            pw.SizedBox(height: 16),
          ],

          // OBD2 limitations
          _sectionTitle('OBD2 Limitations', accentColor),
          pw.Text(
            result.whatObdCannotTell,
            style: pw.TextStyle(color: mutedColor),
          ),
          pw.SizedBox(height: 16),

          // Appendix — sensor summaries
          if (completedTests.isNotEmpty) ...[
            _sectionTitle('Appendix — Sensor Summaries', accentColor),
            for (final test in completedTests) ...[
              pw.Text(
                test.testId.replaceAll('_', ' ').toUpperCase(),
                style: pw.TextStyle(
                    fontWeight: pw.FontWeight.bold, fontSize: 10),
              ),
              pw.SizedBox(height: 4),
              for (final s in test.pidSummaries.values)
                pw.Text(s.toText(),
                    style: const pw.TextStyle(fontSize: 8)),
              if (test.notableEvents.isNotEmpty) ...[
                pw.SizedBox(height: 4),
                for (final e in test.notableEvents)
                  pw.Text(
                    '[${e.secondsIntoTest}s] ${e.description}',
                    style: pw.TextStyle(
                        fontSize: 8, color: accentColor),
                  ),
              ],
              pw.SizedBox(height: 12),
            ],
          ],
        ],
      ),
    );

    return pdf;
  }

  static pw.Widget _sectionTitle(String title, PdfColor color) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 8),
      child: pw.Text(
        title.toUpperCase(),
        style: pw.TextStyle(
          color: color,
          fontWeight: pw.FontWeight.bold,
          fontSize: 11,
          letterSpacing: 1,
        ),
      ),
    );
  }

  static pw.Widget _badge(String label, PdfColor color) {
    return pw.Container(
      padding:
          const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: color, width: 0.5),
        borderRadius:
            const pw.BorderRadius.all(pw.Radius.circular(4)),
      ),
      child: pw.Text(
        label,
        style: pw.TextStyle(
            color: color,
            fontSize: 8,
            fontWeight: pw.FontWeight.bold),
      ),
    );
  }

  static String _formatDate(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}
