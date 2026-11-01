import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import 'commerce_models.dart';
import 'inventory_models.dart';

class CommerceReceiptService {
  Future<Uint8List> build(CommerceOrder order) async {
    final document = pw.Document();
    document.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(38),
        build: (_) => [
          pw.Text(
            order.dianInvoiceUrl == null
                ? 'COMPROBANTE DE COMPRA'
                : 'FACTURA ELECTRÓNICA DE VENTA',
            style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 8),
          pw.Text(order.workshopName),
          pw.Text('Documento: ${order.receiptNumber}'),
          pw.Text('Fecha: ${_date(order.createdAt)}'),
          pw.Divider(),
          _row('Cliente', order.clientName),
          _row('Producto', order.productName),
          _row('Cantidad', '${order.quantity}'),
          _row('Valor unitario', commerceMoney(order.unitPriceCents)),
          _row('Total pagado', commerceMoney(order.subtotalCents), bold: true),
          _row('Medio de pago', order.paymentMethod),
          _row('Estado', commerceStatusLabel(order.status)),
          pw.SizedBox(height: 18),
          pw.Container(
            width: double.infinity,
            padding: const pw.EdgeInsets.all(14),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColors.grey500),
            ),
            child: pw.Column(
              children: [
                pw.Text('CÓDIGO DE RETIRO'),
                pw.SizedBox(height: 5),
                pw.Text(
                  order.pickupCode,
                  style: pw.TextStyle(
                    fontSize: 26,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.Text('Preséntalo cuando el pedido esté listo.'),
              ],
            ),
          ),
          pw.SizedBox(height: 18),
          if (order.cufe != null) pw.Text('CUFE: ${order.cufe}'),
          if (order.dianInvoiceUrl == null)
            pw.Text(
              'Este documento confirma el pago y la orden. No reemplaza la factura electrónica validada por la DIAN cuando el vendedor está obligado a expedirla.',
              style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
            ),
        ],
      ),
    );
    return document.save();
  }

  Future<Uint8List> buildPointOfSale(PointOfSaleTicket ticket) async {
    final document = pw.Document();
    document.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(38),
        build: (_) => [
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    ticket.workshopName.toUpperCase(),
                    style: pw.TextStyle(
                      fontSize: 20,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.Text('Comprobante de venta presencial'),
                ],
              ),
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Text(
                    ticket.invoiceNumber,
                    style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                  ),
                  pw.Text(_date(ticket.createdAt)),
                ],
              ),
            ],
          ),
          pw.SizedBox(height: 18),
          pw.Container(
            width: double.infinity,
            padding: const pw.EdgeInsets.all(12),
            color: PdfColors.grey100,
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text('Cliente: ${ticket.customerName}'),
                if (ticket.customerDocument.isNotEmpty)
                  pw.Text('Documento: ${ticket.customerDocument}'),
                if (ticket.customerPhone.isNotEmpty)
                  pw.Text('Teléfono: ${ticket.customerPhone}'),
                pw.Text('Medio de pago: ${ticket.paymentMethod}'),
              ],
            ),
          ),
          pw.SizedBox(height: 18),
          pw.TableHelper.fromTextArray(
            headers: const ['Producto', 'Marca', 'Cant.', 'Unitario', 'Total'],
            data: ticket.lines
                .map(
                  (line) => [
                    line.productName,
                    line.brand,
                    '${line.quantity}',
                    commerceMoney(line.unitPriceCents),
                    commerceMoney(line.totalCents),
                  ],
                )
                .toList(),
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
            headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
            cellPadding: const pw.EdgeInsets.all(7),
          ),
          pw.SizedBox(height: 14),
          _row('Subtotal', commerceMoney(ticket.subtotalCents)),
          if (ticket.discountCents > 0)
            _row('Descuento', '- ${commerceMoney(ticket.discountCents)}'),
          pw.Divider(),
          _row('TOTAL PAGADO', commerceMoney(ticket.totalCents), bold: true),
          pw.SizedBox(height: 22),
          pw.Text(
            'Gracias por su compra.',
            style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 8),
          pw.Text(
            'Este comprobante registra la venta y el pago. Cuando el vendedor esté obligado a facturar electrónicamente, el documento fiscal definitivo debe ser validado mediante un proveedor autorizado por la DIAN.',
            style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
          ),
        ],
      ),
    );
    return document.save();
  }

  pw.Widget _row(String label, String value, {bool bold = false}) => pw.Padding(
    padding: const pw.EdgeInsets.symmetric(vertical: 5),
    child: pw.Row(
      children: [
        pw.Expanded(child: pw.Text(label)),
        pw.Text(
          value,
          style: bold ? pw.TextStyle(fontWeight: pw.FontWeight.bold) : null,
        ),
      ],
    ),
  );

  String _date(DateTime value) =>
      '${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')}/${value.year}';
}
