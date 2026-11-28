import 'package:flutter/material.dart';

import '../../services/chofer_api.dart';
import '../chofer/chofer_widgets.dart';

Future<String?> pickOperationDay(
  BuildContext context,
  String day, {
  String? minimum,
}) async {
  final selected = await showDatePicker(
    context: context,
    initialDate: DateTime.parse(day),
    firstDate: minimum == null ? DateTime(2000) : DateTime.parse(minimum),
    lastDate: DateTime(2100, 12, 31),
  );
  return selected == null ? null : isoDay(selected);
}

class AgendaScreen extends StatefulWidget {
  const AgendaScreen({super.key, required this.api});
  final ChoferApi api;

  @override
  State<AgendaScreen> createState() => _AgendaScreenState();
}

class _AgendaScreenState extends State<AgendaScreen> {
  late Future<Json> _data;
  final _selected = <String>{};
  String? _day;
  String? _selectionDay;
  String? _status;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _data = _load();
  }

  Future<Json> _load() =>
      widget.api.get('agenda', _day == null ? null : {'fecha': _day!});
  void _refresh() {
    final next = _load();
    setState(() {
      _data = next;
    });
  }

  Future<void> _mutate(
    String path,
    Json body,
    String Function(Json) message,
  ) async {
    setState(() => _busy = true);
    try {
      final result = await widget.api.post(path, body);
      if (!mounted) return;
      _selected.clear();
      _refresh();
      showMessage(context, message(result));
    } on ChoferError catch (error) {
      if (mounted) showMessage(context, error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _pick(String day) async {
    final picked = await pickOperationDay(context, day);
    if (picked == null || !mounted) return;
    _selected.clear();
    _day = picked;
    _refresh();
  }

  Future<void> _generate(String today) async {
    final start = DateTime.parse(today);
    final range = await showDateRangePicker(
      context: context,
      firstDate: start,
      lastDate: start.add(const Duration(days: 365)),
      initialDateRange: DateTimeRange(
        start: start,
        end: start.add(const Duration(days: 14)),
      ),
    );
    if (range == null || !mounted) return;
    await _mutate('agenda/generar', {
      'desde': isoDay(range.start),
      'hasta': isoDay(range.end),
    }, (data) => 'Visitas creadas: ${data['creadas']}');
  }

  Future<void> _schedule(Json data) async {
    final today = data['hoy'] as String;
    final day = await pickOperationDay(
      context,
      _day != null && _day!.compareTo(today) >= 0 ? _day! : today,
      minimum: today,
    );
    if (day == null || !mounted) return;
    final contract = await showDialog<String>(
      context: context,
      builder: (_) => SimpleDialog(
        title: Text('Programar visita · $day'),
        children: [
          if (rows(data, 'contratos').isEmpty)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('Registra un contrato activo primero.'),
            ),
          for (final item in rows(data, 'contratos'))
            SimpleDialogOption(
              onPressed: () => Navigator.pop(context, item['id'] as String),
              child: Text('${item['nombre']}'),
            ),
        ],
      ),
    );
    if (contract == null || !mounted) return;
    await _mutate('agenda/programar', {
      'fecha': day,
      'fk_contrato': contract,
    }, (_) => 'Visita programada.');
  }

  Future<void> _assign(Json data) async {
    final selection = await showDialog<Json>(
      context: context,
      builder: (_) => _AssignmentDialog(data: data),
    );
    if (selection == null || !mounted) return;
    await _mutate(
      'agenda/asignar',
      {...selection, 'fecha': _selectionDay, 'paradas': _selected.toList()},
      (data) => selection['publicar'] == true
          ? 'Paradas publicadas: ${data['asignadas']}'
          : 'Paradas en borrador: ${data['asignadas']}',
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Calendario y rutas'),
      actions: [
        IconButton(
          onPressed: _busy ? null : _refresh,
          tooltip: 'Actualizar',
          icon: const Icon(Icons.refresh),
        ),
      ],
    ),
    body: AsyncContent(
      future: _data,
      retry: _refresh,
      builder: (data) {
        final day = data['fecha'] as String?;
        final today = data['hoy'] as String;
        final visits = rows(data, 'items').where((visit) {
          final status = visit['activo'] != 1 ? 'cancelada' : visit['servicio'];
          return _status == null || status == _status;
        }).toList();
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Wrap(
              spacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: _busy ? null : () => _pick(day ?? today),
                  icon: const Icon(Icons.calendar_today),
                  label: Text(day ?? 'Filtrar por fecha'),
                ),
                if (day != null)
                  TextButton(
                    onPressed: _busy
                        ? null
                        : () {
                            _day = null;
                            _selected.clear();
                            _refresh();
                          },
                    child: const Text('Todas las fechas'),
                  ),
                OutlinedButton(
                  onPressed: _busy ? null : () => _generate(today),
                  child: const Text('Generar visitas'),
                ),
                OutlinedButton(
                  onPressed: _busy ? null : () => _schedule(data),
                  child: const Text('Programar una visita'),
                ),
                FilledButton(
                  onPressed: _busy || _selected.isEmpty
                      ? null
                      : () => _assign(data),
                  child: Text('Asignar (${_selected.length})'),
                ),
              ],
            ),
            DropdownButton<String>(
              hint: const Text('Todos los estados'),
              value: _status,
              items: [
                const DropdownMenuItem(
                  value: null,
                  child: Text('Todos los estados'),
                ),
                for (final status in [
                  'pendiente',
                  'en_curso',
                  'completada',
                  'fallida',
                  'cancelada',
                ])
                  DropdownMenuItem(
                    value: status,
                    child: Text(
                      status == 'cancelada' ? 'Cancelada' : stopStatus(status),
                    ),
                  ),
              ],
              onChanged: (status) => setState(() {
                _status = status;
                _selected.clear();
              }),
            ),
            const Text('Selecciona las paradas en el orden de visita.'),
            if (visits.isEmpty) const Text('Sin visitas programadas.'),
            for (final visit in visits) _visit(visit, today),
          ],
        );
      },
    ),
  );

  Widget _visit(Json visit, String today) {
    final id = visit['id'] as String;
    final date = visit['fecha'].toString().split('T').first;
    final available =
        date.compareTo(today) >= 0 &&
        visit['activo'] == 1 &&
        visit['servicio'] == 'pendiente';
    final assigned = visit['fk_ruta'] != null;
    final position = _selected.toList().indexOf(id);
    return Card(
      child: ListTile(
        leading: available
            ? Checkbox(
                value: position >= 0,
                onChanged: _busy
                    ? null
                    : (value) => setState(() {
                        if (value == true) {
                          if (_selectionDay != date) _selected.clear();
                          _selectionDay = date;
                          _selected.add(id);
                        } else {
                          _selected.remove(id);
                        }
                      }),
              )
            : const Icon(Icons.event_note_outlined),
        title: Text(
          '${position >= 0 ? '${position + 1}. ' : ''}${visit['cliente']}',
        ),
        subtitle: Text(
          '${visit['contrato'] ?? visit['folio']} · ${visit['folio']}\n'
          '${visit['activo'] != 1 ? 'Cancelada' : stopStatus(visit['servicio'] as String)}'
          ' · Cliente: ${visit['respuesta_cliente']}\n'
          '${visit['fecha'].toString().replaceFirst('T', ' ')} · '
          '${assigned ? "${visit['ruta']} / ${visit['chofer']}" : "Sin asignar"}'
          '${assigned && visit['publicada'] == 0 ? ' · Borrador' : ''}',
        ),
        trailing: available && assigned
            ? IconButton(
                tooltip: 'Desasignar',
                onPressed: _busy
                    ? null
                    : () => _mutate(
                        'agenda/$id/desasignar',
                        {},
                        (_) => 'Parada desasignada.',
                      ),
                icon: const Icon(Icons.link_off),
              )
            : null,
      ),
    );
  }
}

class _AssignmentDialog extends StatefulWidget {
  const _AssignmentDialog({required this.data});
  final Json data;

  @override
  State<_AssignmentDialog> createState() => _AssignmentDialogState();
}

class _AssignmentDialogState extends State<_AssignmentDialog> {
  final values = <String, String>{};
  bool _publish = false;
  static const choices = {
    'rutas': ('fk_ruta', 'Ruta'),
    'choferes': ('fk_chofer', 'Chofer'),
    'turnos': ('fk_turno', 'Turno'),
  };

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Asignar paradas'),
    content: SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final entry in choices.entries)
            DropdownButtonFormField<String>(
              initialValue: values[entry.value.$1],
              decoration: InputDecoration(labelText: entry.value.$2),
              isExpanded: true,
              items: [
                for (final item in rows(widget.data, entry.key))
                  DropdownMenuItem(
                    value: item['id'] as String,
                    child: Text(
                      '${item['nombre']}',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
              onChanged: (value) {
                if (value != null) {
                  setState(() => values[entry.value.$1] = value);
                }
              },
            ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: _publish,
            onChanged: (value) => setState(() => _publish = value),
            title: const Text('Publicar para el chofer'),
            subtitle: const Text(
              'Revisa las confirmaciones antes de publicar.',
            ),
          ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancelar'),
      ),
      FilledButton(
        onPressed: values.length == choices.length
            ? () => Navigator.pop(context, <String, dynamic>{
                ...values,
                'publicar': _publish,
              })
            : null,
        child: const Text('Asignar'),
      ),
    ],
  );
}
