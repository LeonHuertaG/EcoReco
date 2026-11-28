import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../services/chofer_api.dart';
import 'chofer_widgets.dart';

class ManifiestoPdfButton extends StatefulWidget {
  const ManifiestoPdfButton({
    super.key,
    required this.manifest,
    required this.items,
    this.loadSignature,
  });

  final Json manifest;
  final List<Json> items;
  final Future<Uint8List> Function()? loadSignature;

  @override
  State<ManifiestoPdfButton> createState() => _ManifiestoPdfButtonState();
}

class _ManifiestoPdfButtonState extends State<ManifiestoPdfButton> {
  bool _busy = false;

  Future<void> _share() async {
    setState(() => _busy = true);
    try {
      final manifest = widget.manifest;
      final folio = manifest['folio'].toString();
      final signature = await widget.loadSignature?.call();
      final document = pw.Document(
        title: 'Manifiesto $folio',
        author: 'EcoReco',
      );
      document.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          build: (_) => [
            pw.Text(
              'EcoReco',
              style: pw.TextStyle(color: PdfColors.deepOrange800, fontSize: 24),
            ),
            pw.SizedBox(height: 10),
            pw.Text(
              'Manifiesto de recolección',
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 20),
            ),
            pw.SizedBox(height: 16),
            pw.Text('Folio: $folio'),
            pw.Text('Cliente: ${manifest['cliente'] ?? 'Sin dato'}'),
            pw.Text('Chofer: ${manifest['chofer'] ?? 'Sin dato'}'),
            pw.Text('Origen: ${manifest['origen'] ?? 'Sin dato'}'),
            pw.Text('Destino: ${manifest['destino'] ?? 'Sin dato'}'),
            pw.Text(
              'Emisión: ${manifest['fecha_emision'] ?? manifest['emision']}',
            ),
            if (manifest['fecha_entrega'] ?? manifest['entrega']
                case final delivery?)
              pw.Text('Entrega: $delivery'),
            if (manifest['observaciones'] case final notes?)
              pw.Text('Observaciones: $notes'),
            pw.SizedBox(height: 16),
            pw.Text(
              'Residuos',
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
            ),
            for (final item in widget.items)
              pw.Padding(
                padding: const pw.EdgeInsets.only(top: 8),
                child: pw.Text(
                  '${item['descripcion'] ?? 'Residuo'}\n'
                  'Cantidad: ${item['cantidad']} ${item['unidad_medida'] ?? ''}'
                  '  ·  Peso: ${item['peso']} kg',
                ),
              ),
            if (signature != null) ...[
              pw.SizedBox(height: 16),
              pw.Text('Firma del cliente'),
              pw.Image(pw.MemoryImage(signature), width: 180, height: 75),
            ],
          ],
        ),
      );
      await Printing.sharePdf(
        bytes: await document.save(),
        filename:
            'manifiesto-${folio.replaceAll(RegExp(r"[^A-Za-z0-9_-]"), "_")}.pdf',
      );
    } on Exception catch (error) {
      if (mounted) showMessage(context, error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.centerLeft,
    child: OutlinedButton.icon(
      onPressed: _busy ? null : _share,
      icon: const Icon(Icons.picture_as_pdf_outlined),
      label: const Text('Compartir PDF'),
    ),
  );
}
