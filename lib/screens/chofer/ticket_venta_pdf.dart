import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../services/chofer_api.dart';
import 'chofer_widgets.dart';

class TicketVentaPdfButton extends StatefulWidget {
  const TicketVentaPdfButton({
    super.key,
    required this.stop,
    required this.sale,
  });

  final Json stop;
  final Json sale;

  @override
  State<TicketVentaPdfButton> createState() => _TicketVentaPdfButtonState();
}

class _TicketVentaPdfButtonState extends State<TicketVentaPdfButton> {
  bool _busy = false;

  Future<void> _share() async {
    setState(() => _busy = true);
    try {
      final sale = widget.sale;
      final folio = sale['folio'].toString();
      final document = pw.Document(
        title: 'Ticket de venta $folio',
        author: 'EcoReco',
      );

      document.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a5,
          build: (_) => [
            pw.Text(
              'EcoReco · Ticket de venta',
              style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 12),
            pw.Text('Folio: $folio'),
            pw.Text('Fecha: ${sale['fecha'] ?? widget.stop['fecha']}'),
            pw.Text('Cliente: ${widget.stop['cliente']}'),
            pw.Text('Recolección: ${widget.stop['folio']}'),
            pw.Divider(),
            for (final item in rows(widget.stop, 'conceptos'))
              pw.Text('${item['concepto']} · ${mxn(item['subtotal'])}'),
            pw.Divider(),
            pw.Text('Subtotal: ${mxn(sale['subtotal'])}'),
            pw.Text('IVA: ${mxn(sale['iva'])}'),
            pw.Text('Total: ${mxn(sale['total'])}'),
            for (final payment in rows(widget.stop, 'pagos'))
              pw.Text('Pago ${payment['metodo']}: ${mxn(payment['importe'])}'),
            pw.Text('Saldo pendiente: ${mxn(sale['saldo'])}'),
          ],
        ),
      );

      final safeFolio = folio.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '_');
      await Printing.sharePdf(
        bytes: await document.save(),
        filename: 'ticket-$safeFolio.pdf',
      );
    } on Exception catch (error) {
      if (mounted) showMessage(context, error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => OutlinedButton.icon(
    onPressed: _busy ? null : _share,
    icon: const Icon(Icons.receipt_long_outlined),
    label: const Text('Compartir ticket de venta'),
  );
}
