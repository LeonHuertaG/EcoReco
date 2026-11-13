import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../../services/chofer_api.dart';
import 'chofer_widgets.dart';

class ChoferServicio extends StatefulWidget {
  const ChoferServicio({
    super.key,
    required this.api,
    required this.path,
    required this.address,
    this.initialNotes,
  });

  final ChoferApi api;
  final String path;
  final String address;
  final String? initialNotes;

  @override
  State<ChoferServicio> createState() => _ChoferServicioState();
}

class _ChoferServicioState extends State<ChoferServicio> {
  final _form = GlobalKey<FormState>();
  final _signature = GlobalKey<_SignatureState>();
  final _items = [_WasteInput()];
  late final _notes = TextEditingController(text: widget.initialNotes);
  late Future<Json> _catalog;
  Json? _quote;
  List<Json>? _quotedItems;
  // Evidencia opcional adicional a la firma.
  Uint8List? _photo;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _catalog = widget.api.get('catalogos');
  }

  @override
  void dispose() {
    for (final item in _items) {
      item.dispose();
    }
    _notes.dispose();
    super.dispose();
  }

  Future<void> _preview() async {
    if (!_form.currentState!.validate()) return;
    final items = [for (final item in _items) item.toJson()];
    setState(() => _busy = true);
    try {
      final quote = await widget.api.post('${widget.path}/cotizacion', {
        'residuos': items,
      });
      if (mounted) {
        setState(() {
          _quotedItems = items;
          _quote = quote;
        });
      }
    } on Exception catch (error) {
      if (mounted) showMessage(context, error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _finish() async {
    final signer = _signature.currentState!;
    if (!signer.hasSignature) {
      showMessage(context, 'Recaba la firma del cliente antes de finalizar.');
      return;
    }
    setState(() => _busy = true);
    try {
      final signature = await signer.export();
      await widget.api.post('${widget.path}/completar', {
        'residuos': _quotedItems,
        'total_confirmado': _quote!['total'],
        'observaciones': _notes.text.trim(),
        'firma': signature,
        if (_photo != null) 'foto': base64Encode(_photo!),
      });
      if (mounted) Navigator.pop(context, true);
    } on Exception catch (error) {
      if (mounted) showMessage(context, error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Capturar recolección')),
    body: AsyncContent(
      future: _catalog,
      retry: () {
        final next = widget.api.get('catalogos');
        setState(() {
          _catalog = next;
        });
      },
      builder: (catalog) => _quote == null ? _capture(catalog) : _confirm(),
    ),
  );

  Widget _capture(Json catalog) {
    final wastes = rows(catalog, 'residuos');
    if (wastes.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Text('No hay residuos activos en el catálogo.'),
        ),
      );
    }

    return Form(
      key: _form,
      child: AbsorbPointer(
        absorbing: _busy,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            for (var index = 0; index < _items.length; index++)
              _wasteCard(index, wastes),
            TextButton.icon(
              onPressed: _items.length >= wastes.length || _items.length >= 50
                  ? null
                  : () => setState(() => _items.add(_WasteInput())),
              icon: const Icon(Icons.add),
              label: const Text('Agregar tipo de residuo'),
            ),
            TextFormField(
              controller: _notes,
              maxLength: 255,
              decoration: const InputDecoration(
                labelText: 'Observaciones del servicio',
              ),
            ),
            FilledButton(
              onPressed: _busy ? null : _preview,
              child: Text(_busy ? 'Calculando…' : 'Calcular cargos'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _wasteCard(int index, List<Json> catalog) {
    final item = _items[index];
    return Card(
      key: ObjectKey(item),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            DropdownButtonFormField<String>(
              initialValue: item.waste,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Tipo de residuo'),
              items: [
                for (final entry in catalog)
                  DropdownMenuItem<String>(
                    value: entry['id'].toString(),
                    child: Text(
                      '${entry['nombre']} · ${entry['unidad_medida'] ?? 'unidad'}',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
              onChanged: (value) => item.waste = value,
              validator: (value) {
                if (value == null) {
                  return 'Selecciona un residuo';
                }

                if (_items.where((other) => other.waste == value).length > 1) {
                  return 'Agrupa los residuos del mismo tipo';
                }

                return null;
              },
            ),
            DecimalField(controller: item.quantity, label: 'Cantidad'),
            DecimalField(controller: item.weight, label: 'Peso en kg'),
            TextFormField(
              controller: item.notes,
              maxLength: 255,
              decoration: const InputDecoration(
                labelText: 'Observaciones del residuo',
              ),
            ),
            if (_items.length > 1)
              TextButton(
                onPressed: () {
                  setState(() => _items.removeAt(index));
                  WidgetsBinding.instance.addPostFrameCallback(
                    (_) => item.dispose(),
                  );
                },
                child: const Text('Quitar tipo de residuo'),
              ),
          ],
        ),
      ),
    );
  }

  Widget _confirm() {
    final quote = _quote!;
    return AbsorbPointer(
      absorbing: _busy,
      child: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text(
                  'Importes para el cliente',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                for (final line in rows(quote, 'conceptos'))
                  Text('${line['concepto']} · ${mxn(line['subtotal'])}'),
                Text('Subtotal ${mxn(quote['subtotal'])}'),
                Text('IVA ${mxn(quote['iva'])}'),
                Text(
                  'Total ${mxn(quote['total'])}',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 12),
                const Text(
                  'La firma reconoce el servicio y los importes informados. El pago se registra por separado.',
                ),
                const SizedBox(height: 8),

                PhotoInput(
                  photo: _photo,
                  enabled: !_busy,
                  onChanged: (photo) => setState(() => _photo = photo),
                ),
                FilledButton(
                  onPressed: _busy ? null : _finish,
                  child: Text(
                    _busy ? 'Guardando…' : 'Finalizar y emitir comprobantes',
                  ),
                ),
                TextButton(
                  onPressed: _busy ? null : () => setState(() => _quote = null),
                  child: const Text('Volver a la captura'),
                ),
              ],
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _Signature(key: _signature),
            ),
          ),
        ],
      ),
    );
  }
}

class _WasteInput {
  String? waste;
  final quantity = TextEditingController();
  final weight = TextEditingController();
  final notes = TextEditingController();

  Json toJson() => {
    'fk_desecho': waste,
    'cantidad': normalizedDecimal(quantity.text),
    'peso': normalizedDecimal(weight.text),
    'observaciones': notes.text.trim(),
  };

  void dispose() {
    quantity.dispose();
    weight.dispose();
    notes.dispose();
  }
}

class _Signature extends StatefulWidget {
  const _Signature({super.key});

  @override
  State<_Signature> createState() => _SignatureState();
}

class _SignatureState extends State<_Signature> {
  final _capture = GlobalKey();
  final _strokes = <List<Offset>>[];
  int? _pointer;

  bool get hasSignature => _strokes.any((stroke) => stroke.length > 1);

  Future<String> export() async {
    final boundary =
        _capture.currentContext!.findRenderObject() as RenderRepaintBoundary;
    final image = await boundary.toImage();
    try {
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      return base64Encode(
        data!.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
      );
    } finally {
      image.dispose();
    }
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Text('Firma del cliente'),
      Container(
        decoration: BoxDecoration(
          border: Border.all(color: Theme.of(context).colorScheme.outline),
        ),
        child: Listener(
          behavior: HitTestBehavior.opaque,
          onPointerDown: (event) {
            if (_pointer != null) return;
            _pointer = event.pointer;
            setState(() => _strokes.add([event.localPosition]));
          },
          onPointerMove: (event) {
            if (_pointer == event.pointer && _strokes.isNotEmpty) {
              setState(() => _strokes.last.add(event.localPosition));
            }
          },
          onPointerUp: (event) {
            if (_pointer == event.pointer) _pointer = null;
          },
          onPointerCancel: (event) {
            if (_pointer == event.pointer) _pointer = null;
          },
          child: RepaintBoundary(
            key: _capture,
            child: ColoredBox(
              color: Colors.white,
              child: CustomPaint(
                painter: _SignaturePainter(_strokes),
                child: const SizedBox(width: double.infinity, height: 180),
              ),
            ),
          ),
        ),
      ),
      TextButton(
        onPressed: () => setState(_strokes.clear),
        child: const Text('Borrar firma'),
      ),
    ],
  );
}

class _SignaturePainter extends CustomPainter {
  _SignaturePainter(this.strokes);

  final List<List<Offset>> strokes;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.clipRect(Offset.zero & size);
    final pen = Paint()
      ..color = Colors.black
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;
    for (final stroke in strokes) {
      for (var i = 1; i < stroke.length; i++) {
        canvas.drawLine(stroke[i - 1], stroke[i], pen);
      }
    }
  }

  @override
  bool shouldRepaint(_SignaturePainter oldDelegate) => true;
}
