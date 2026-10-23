import 'package:flutter/material.dart';

import '../../services/chofer_api.dart';
import 'chofer_widgets.dart';

class ChoferCaja extends StatefulWidget {
  const ChoferCaja({
    super.key,
    required this.api,
    required this.day,
    required this.shift,
    required this.name,
  });

  final ChoferApi api;
  final String day;
  final String shift;
  final String name;

  @override
  State<ChoferCaja> createState() => _ChoferCajaState();
}

class _ChoferCajaState extends State<ChoferCaja> {
  late Future<Json> _data;
  String get _path => 'turnos/${widget.shift}/corte';
  Map<String, String> get _query => {'fecha': widget.day};

  @override
  void initState() {
    super.initState();
    _data = _load();
  }

  Future<Json> _load() => widget.api.get(_path, _query);
  void _refresh() {
    final next = _load();
    setState(() {
      _data = next;
    });
  }

  Future<void> _expense() async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) =>
            _ExpenseForm(api: widget.api, shift: widget.shift, day: widget.day),
      ),
    );
    if (changed == true && mounted) _refresh();
  }

  Future<void> _close(Json data) async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => _CloseForm(
          api: widget.api,
          path: _path,
          query: _query,
          summary: data,
        ),
      ),
    );
    if (changed == true && mounted) _refresh();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text('Caja · ${widget.name}')),
    body: AsyncContent(
      future: _data,
      retry: _refresh,
      builder: (data) {
        final cut = data['corte'] as Json?;
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(widget.day, style: Theme.of(context).textTheme.headlineSmall),
            Text('Pagos recibidos ${mxn(data['total_pagos'])}'),
            Text('Pagos en efectivo ${mxn(data['efectivo'])}'),
            Text('Viáticos gastados ${mxn(data['gastos'])}'),
            if (cut != null) ...[
              const SizedBox(height: 16),
              _CutDetails(cut: cut),
            ] else
              Wrap(
                spacing: 8,
                children: [
                  OutlinedButton(
                    onPressed: _expense,
                    child: const Text('Registrar viático'),
                  ),
                  FilledButton(
                    onPressed: () => _close(data),
                    child: const Text('Preparar corte'),
                  ),
                ],
              ),
            const SizedBox(height: 16),
            Text('Movimientos', style: Theme.of(context).textTheme.titleLarge),
            for (final payment in rows(data, 'pagos'))
              ListTile(
                title: Text('${payment['folio']} · ${payment['metodo']}'),
                trailing: Text(mxn(payment['importe'])),
              ),
            for (final expense in rows(data, 'viaticos'))
              ListTile(
                title: Text('${expense['concepto']}'),
                trailing: Text('-${mxn(expense['importe'])}'),
              ),
          ],
        );
      },
    ),
  );
}

class _ExpenseForm extends StatefulWidget {
  const _ExpenseForm({
    required this.api,
    required this.shift,
    required this.day,
  });
  final ChoferApi api;
  final String shift;
  final String day;

  @override
  State<_ExpenseForm> createState() => _ExpenseFormState();
}

class _ExpenseFormState extends State<_ExpenseForm> {
  final _form = GlobalKey<FormState>();
  final _concept = TextEditingController();
  final _amount = TextEditingController();
  final _operation = operationKey();
  bool _busy = false;

  @override
  void dispose() {
    _concept.dispose();
    _amount.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _busy = true);
    try {
      await widget.api.post('viaticos', {
        'fk_turno': widget.shift,
        'fecha': widget.day,
        'concepto': _concept.text.trim(),
        'importe': normalizedDecimal(_amount.text),
        'clave': _operation,
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
    appBar: AppBar(title: const Text('Registrar viático')),
    body: Form(
      key: _form,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextFormField(
            controller: _concept,
            maxLength: 120,
            decoration: const InputDecoration(labelText: 'Concepto'),
            validator: (value) =>
                (value ?? '').trim().isEmpty ? 'Campo obligatorio' : null,
          ),
          DecimalField(controller: _amount, label: 'Importe gastado'),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _busy ? null : _save,
            child: const Text('Guardar viático'),
          ),
        ],
      ),
    ),
  );
}

class _CloseForm extends StatefulWidget {
  const _CloseForm({
    required this.api,
    required this.path,
    required this.query,
    required this.summary,
  });

  final ChoferApi api;
  final String path;
  final Map<String, String> query;
  final Json summary;

  @override
  State<_CloseForm> createState() => _CloseFormState();
}

class _CloseFormState extends State<_CloseForm> {
  final _form = GlobalKey<FormState>();
  final _notes = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _notes.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _busy = true);
    try {
      await widget.api.post(widget.path, {
        'observaciones': _notes.text.trim(),
      }, widget.query);
      if (mounted) Navigator.pop(context, true);
    } on Exception catch (error) {
      if (mounted) showMessage(context, error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Corte del turno')),
    body: Form(
      key: _form,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Cobros en efectivo ${mxn(widget.summary['efectivo'])}'),
          Text('Viáticos ${mxn(widget.summary['gastos'])}'),
          const Text(
            'Al cerrar el turno se bloquean nuevos cobros y viáticos de esta jornada para el turno seleccionado.',
          ),
          Text('Otros métodos ${mxn(widget.summary['otros_metodos'])}'),
          Text(
            'Efectivo a entregar ${mxn(widget.summary['efectivo_a_entregar'])}',
          ),
          TextFormField(
            controller: _notes,
            maxLength: 255,
            decoration: const InputDecoration(labelText: 'Observaciones'),
          ),
          FilledButton(
            onPressed: _busy ? null : _save,
            child: const Text('Confirmar corte'),
          ),
        ],
      ),
    ),
  );
}

class _CutDetails extends StatelessWidget {
  const _CutDetails({required this.cut});
  final Json cut;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text('Corte ${cut['fk_corte']} · ${cut['turno']}'),
      Text('Jornada ${cut['jornada']}'),
      if (cut['efectivo'] != null)
        Text('Cobrado en efectivo ${mxn(cut['efectivo'])}'),
      if (cut['otros_metodos'] != null)
        Text('Otros métodos ${mxn(cut['otros_metodos'])}'),
      Text('Total cobrado ${mxn(cut['total_ventas'])}'),
      Text('Total de viáticos ${mxn(cut['total_gastos'])}'),
      Text('Efectivo a entregar ${mxn(cut['efectivo_esperado'])}'),
      if (cut['observaciones'] != null) Text('${cut['observaciones']}'),

      Text(
        cut['fk_revisor'] == null
            ? 'Pendiente de revisión'
            : 'Revisado ${cut['fecha_revision']} · ${cut['nota_revision']}',
      ),
    ],
  );
}

class RevisionCortes extends StatefulWidget {
  const RevisionCortes({super.key, required this.api});
  final ChoferApi api;

  @override
  State<RevisionCortes> createState() => _RevisionCortesState();
}

class _RevisionCortesState extends State<RevisionCortes> {
  String? _day;
  bool _pendingOnly = false;
  late Future<Json> _data;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _data = _load();
  }

  Future<Json> _load() =>
      widget.api.get('revision/cortes', _day == null ? null : {'fecha': _day!});
  void _refresh() {
    final next = _load();
    setState(() {
      _data = next;
    });
  }

  Future<void> _pick(String day) async {
    final selected = await showDatePicker(
      context: context,
      initialDate: DateTime.parse(day),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (selected != null && mounted) {
      _day = isoDay(selected);
      _refresh();
    }
  }

  Future<void> _review(Json cut) async {
    final note = await askText(
      context,
      title: 'Revisar corte',
      label: 'Nota de revisión',
    );
    if (note == null || !mounted) return;
    setState(() => _busy = true);
    try {
      await widget.api.post('revision/cortes/${cut['fk_corte']}', {
        'nota_revision': note,
      });
      if (mounted) _refresh();
    } on Exception catch (error) {
      if (mounted) showMessage(context, error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Administración · Cortes'),
      actions: [
        IconButton(
          onPressed: _refresh,
          tooltip: 'Actualizar',
          icon: const Icon(Icons.refresh),
        ),
        IconButton(
          onPressed: () => closeSession(context, widget.api),
          tooltip: 'Cerrar sesión',
          icon: const Icon(Icons.logout),
        ),
      ],
    ),
    body: AsyncContent(
      future: _data,
      retry: _refresh,
      builder: (data) {
        final day = data['fecha'] as String?;
        final cuts = rows(
          data,
          'cortes',
        ).where((cut) => !_pendingOnly || cut['fk_revisor'] == null);
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton.icon(
                onPressed: () => _pick(day ?? data['hoy'] as String),
                icon: const Icon(Icons.calendar_today),
                label: Text(day ?? 'Filtrar por fecha'),
              ),
            ),
            if (day != null)
              TextButton(
                onPressed: () {
                  _day = null;
                  _refresh();
                },
                child: const Text('Todas las fechas'),
              ),
            SwitchListTile(
              title: const Text('Solo pendientes de revisión'),
              value: _pendingOnly,
              onChanged: (value) => setState(() => _pendingOnly = value),
            ),
            if (cuts.isEmpty) const Text('No hay cortes.'),

            for (final cut in cuts)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${cut['chofer']}',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      _CutDetails(cut: cut),
                      if (cut['fk_revisor'] == null)
                        TextButton(
                          onPressed: _busy ? null : () => _review(cut),
                          child: const Text('Registrar revisión'),
                        ),
                    ],
                  ),
                ),
              ),
          ],
        );
      },
    ),
  );
}
