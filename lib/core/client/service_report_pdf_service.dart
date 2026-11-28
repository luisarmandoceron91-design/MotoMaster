import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../commerce/commerce_models.dart';
import 'client_service_store.dart';

/// Documento descargable de la orden de servicio publicada por el taller.
class ServiceReportPdfService {
  Future<Uint8List> build({
    required ClientAppointment appointment,
    required String workshopName,
  }) async {
    final report = appointment.serviceReport;
    final document = pw.Document();
    document.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(36),
        build: (_) => [
          pw.Text(
            'ORDEN DE SERVICIO',
            style: pw.TextStyle(fontSize: 21, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 5),
          pw.Text(workshopName.toUpperCase()),
          pw.Text('Cita: ${_date(appointment.date)} · ${appointment.time}'),
          pw.Divider(),
          _data('Servicio', appointment.serviceType),
          _data('Moto', appointment.motorcycleName),
          _data('Mecánico', _mechanic(appointment)),
          if (report.mileage.trim().isNotEmpty)
            _data('Kilometraje', report.mileage),
          if (report.diagnosis.trim().isNotEmpty)
            _data('Diagnóstico, daños o novedades', report.diagnosis),
          pw.SizedBox(height: 14),
          pw.Text(
            'REPUESTOS INSTALADOS',
            style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 5),
          _partsTable(report.parts),
          _total('Subtotal repuestos', report.partsSubtotalCents),
          pw.SizedBox(height: 16),
          pw.Text(
            'MANO DE OBRA',
            style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 5),
          _laborTable(report.labor),
          _total('Subtotal mano de obra', report.laborSubtotalCents),
          pw.SizedBox(height: 16),
          pw.Container(
            width: double.infinity,
            padding: const pw.EdgeInsets.all(12),
            decoration: pw.BoxDecoration(
              color: PdfColors.grey200,
              border: pw.Border.all(color: PdfColors.grey500),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  'TOTAL A PAGAR',
                  style: pw.TextStyle(fontSize: 15, fontWeight: pw.FontWeight.bold),
                ),
                pw.Text(
                  commerceMoney(report.totalCents),
                  style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 20),
          pw.Text(
            'Este documento fue publicado por el taller. Los valores están expresados en pesos colombianos.',
            style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
          ),
        ],
      ),
    );
    return document.save();
  }

  pw.Widget _partsTable(List<ClientServiceReportLine> items) => pw.Table.fromTextArray(
    headers: const ['Repuesto', 'Marca', 'Cant.', 'Subtotal'],
    data: items.isEmpty
        ? const [<String>['Sin repuestos registrados', '', '', '']]
        : items
            .map((item) => [
                  item.name,
                  item.brand.isEmpty ? '—' : item.brand,
                  '${item.quantity}',
                  commerceMoney(item.subtotalCents),
                ])
            .toList(),
    headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
    headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
    cellStyle: const pw.TextStyle(fontSize: 9),
    cellAlignment: pw.Alignment.centerLeft,
  );

  pw.Widget _laborTable(List<ClientServiceLaborLine> items) => pw.Table.fromTextArray(
    headers: const ['Trabajo realizado', 'Precio'],
    data: items.isEmpty
        ? const [<String>['Sin mano de obra registrada', '']]
        : items
            .map((item) => [item.description, commerceMoney(item.priceCents)])
            .toList(),
    headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
    headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
    cellStyle: const pw.TextStyle(fontSize: 9),
  );

  pw.Widget _data(String label, String value) => pw.Padding(
    padding: const pw.EdgeInsets.only(bottom: 5),
    child: pw.RichText(
      text: pw.TextSpan(
        children: [
          pw.TextSpan(text: '$label: ', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
          pw.TextSpan(text: value),
        ],
      ),
    ),
  );

  pw.Widget _total(String label, int cents) => pw.Align(
    alignment: pw.Alignment.centerRight,
    child: pw.Text(
      '$label: ${commerceMoney(cents)}',
      style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
    ),
  );

  String _mechanic(ClientAppointment appointment) {
    final reportMechanic = appointment.serviceReport.mechanicName.trim();
    if (reportMechanic.isNotEmpty) return reportMechanic;
    if (appointment.mechanicName.trim().isNotEmpty) return appointment.mechanicName;
    if (appointment.requestedMechanicName.trim().isNotEmpty) {
      return appointment.requestedMechanicName;
    }
    return 'Por asignar';
  }

  String _date(DateTime value) =>
      '${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')}/${value.year}';
}
