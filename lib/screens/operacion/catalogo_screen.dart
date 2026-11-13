import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../services/chofer_api.dart';
import '../chofer/chofer_widgets.dart';

class CatalogoScreen extends StatefulWidget {
  const CatalogoScreen({
    super.key,
    required this.api,
    required this.resource,
    required this.label,
  });

  final ChoferApi api;
  final String resource;
  final String label;

  @override
  State<CatalogoScreen> createState() => _CatalogoScreenState();
}

class _CatalogoScreenState extends State<CatalogoScreen> {
  late Future<Json> _data;
  int _page = 1;
  bool _busy = false;
  String get _path => 'catalogos/${widget.resource}';

  @override
  void initState() {
    super.initState();
    _data = _load();
  }

  Future<Json> _load() => widget.api.get(_path, {'pagina': '$_page'});
  void _refresh() {
    final next = _load();
    setState(() {
      _data = next;
    });
  }

  Future<void> _edit(Json data, [Json? item]) async {
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) =>
            _CatalogoForm(api: widget.api, path: _path, data: data, item: item),
      ),
    );
    if (mounted && changed == true) _refresh();
  }

  Future<void> _toggle(Json item) async {
    final active = item['estado'] != 1;
    final action = active ? 'Activar' : 'Desactivar';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('$action registro'),
        content: Text('¿Quieres ${action.toLowerCase()} este registro?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Volver'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(action),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _busy = true);
    try {
      await widget.api.post('$_path/${item['id']}/estado', {'activo': active});
      if (mounted) _refresh();
    } on ChoferError catch (error) {
      if (mounted) showMessage(context, error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(widget.label)),
    body: AsyncContent(
      future: _data,
      retry: _refresh,
      builder: (data) => ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: FilledButton.icon(
              onPressed: _busy ? null : () => _edit(data),
              icon: const Icon(Icons.add),
              label: const Text('Nuevo registro'),
            ),
          ),
          if (rows(data, 'items').isEmpty) const Text('Aún no hay registros.'),
          for (final item in rows(data, 'items'))
            Card(
              child: ListTile(
                title: Text('${item[data['title']]}'),
                subtitle: Text(item['estado'] == 1 ? 'Activo' : 'Inactivo'),
                onTap: _busy ? null : () => _edit(data, item),
                trailing: PopupMenuButton<void>(
                  enabled: !_busy,
                  itemBuilder: (_) => [
                    PopupMenuItem(
                      onTap: () => _edit(data, item),
                      child: const Text('Editar'),
                    ),
                    PopupMenuItem(
                      onTap: () => _toggle(item),
                      child: Text(
                        item['estado'] == 1 ? 'Desactivar' : 'Activar',
                      ),
                    ),
                  ],
                ),
              ),
            ),
          if (_page > 1 || data['more'] == true)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                TextButton(
                  onPressed: _page > 1
                      ? () {
                          _page--;
                          _refresh();
                        }
                      : null,
                  child: const Text('Anterior'),
                ),
                Text('Página $_page'),
                TextButton(
                  onPressed: data['more'] == true
                      ? () {
                          _page++;
                          _refresh();
                        }
                      : null,
                  child: const Text('Siguiente'),
                ),
              ],
            ),
        ],
      ),
    ),
  );
}

class _CatalogoForm extends StatefulWidget {
  const _CatalogoForm({
    required this.api,
    required this.path,
    required this.data,
    required this.item,
  });

  final ChoferApi api;
  final String path;
  final Json data;
  final Json? item;

  @override
  State<_CatalogoForm> createState() => _CatalogoFormState();
}

class _CatalogoFormState extends State<_CatalogoForm> {
  final _form = GlobalKey<FormState>();
  final _values = <String, Object?>{};
  bool _busy = false;
  Object? _selectedRole;

  @override
  void initState() {
    super.initState();
    _values.addAll(widget.item ?? {});
  }

  String? _validate(Json field, Object? value) {
    final required =
        field['required'] == true ||
        (field['type'] == 'password' && widget.item == null);
    if (required && (value == null || value.toString().trim().isEmpty)) {
      return 'Campo obligatorio';
    }
    if (field['type'] == 'phone' &&
        value is String &&
        value.isNotEmpty &&
        !RegExp(r'^\d{10}$').hasMatch(value)) {
      return 'Ingresa 10 dígitos';
    }
    return null;
  }

  Future<void> _save() async {
    final form = _form.currentState!;
    if (!form.validate()) return;
    form.save();
    setState(() => _busy = true);
    try {
      final path = widget.item == null
          ? widget.path
          : '${widget.path}/${widget.item!['id']}';
      await widget.api.post(path, _values);
      if (mounted) Navigator.pop(context, true);
    } on ChoferError catch (error) {
      if (mounted) showMessage(context, error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _select(Json field, InputDecoration decoration, Object? value) {
    final key = field['key'] as String;
    final isContractShift = field['source'] == 'turnos_contrato';
    final optional =
        field['required'] != true &&
        (!isContractShift || (widget.item != null && value == null));
    const unassigned = '';
    final options = field['type'] == 'ref'
        ? rows(widget.data['selectors'] as Json, field['source'] as String)
        : [
            for (final option in widget.data['frequencies'] as List)
              {'id': option, 'nombre': option},
          ];
    final available = options
        .where((entry) => entry['asignada'] != true || entry['id'] == value)
        .toList();
    final currentIsAvailable = available.any((entry) => entry['id'] == value);
    return DropdownButtonFormField<Object>(
      initialValue: currentIsAvailable
          ? value
          : value == null && optional
          ? unassigned
          : null,
      isExpanded: true,
      decoration: decoration.copyWith(
        hintText: value != null && !currentIsAvailable
            ? 'Selecciona un valor vigente'
            : null,
        helperText: key == 'fk_usuario' && optional
            ? 'Opcional. Solo se muestran cuentas disponibles.'
            : null,
      ),
      items: [
        if (optional)
          const DropdownMenuItem(value: unassigned, child: Text('Sin asignar')),
        for (final entry in available)
          DropdownMenuItem(
            value: entry['id'] as Object,
            child: Text('${entry['nombre']}', overflow: TextOverflow.ellipsis),
          ),
      ],
      onChanged: (value) {
        if (key == 'fk_rol') setState(() => _selectedRole = value);
      },
      validator: (selection) {
        if (isContractShift && !optional && selection == null) {
          return 'Selecciona un turno de recolección';
        }
        if (selection == null && value != null && !currentIsAvailable) {
          return optional
              ? 'Selecciona un valor vigente o Sin asignar'
              : 'Selecciona un valor vigente';
        }
        return _validate(field, selection);
      },
      onSaved: (selection) =>
          _values[key] = selection == unassigned ? null : selection,
    );
  }

  Widget _contractDate(Json field, InputDecoration decoration) {
    final key = field['key'] as String;
    final isStart = key == 'fecha_inicio';
    final rawToday = widget.data['fecha_actual'] as String?;
    final today = DateUtils.dateOnly(
      DateTime.tryParse(rawToday ?? '') ?? DateTime.now(),
    );
    final original = DateTime.tryParse('${widget.item?[key] ?? ''}');
    final selected = DateTime.tryParse('${_values[key] ?? ''}');

    DateTime minimum() => isStart
        ? today
        : DateTime.tryParse('${_values['fecha_inicio'] ?? ''}') ?? today;

    return FormField<DateTime>(
      initialValue: selected,
      validator: (value) {
        if (value == null) return 'Campo obligatorio';
        if (value.isBefore(minimum()) && (!isStart || value != original)) {
          return isStart
              ? 'El inicio no puede ser anterior a hoy'
              : 'El fin no puede ser anterior al inicio';
        }
        return null;
      },
      builder: (state) => InkWell(
        onTap: () async {
          final first = minimum();
          final value = state.value ?? first;
          final date = await showDatePicker(
            context: context,
            initialDate: value.isBefore(first) ? first : value,
            firstDate: first,
            lastDate: DateTime(9999, 12, 31),
            currentDate: today,
            initialEntryMode: DatePickerEntryMode.calendarOnly,
            helpText: field['label'] as String,
            cancelText: 'Cancelar',
            confirmText: 'Aceptar',
          );
          if (date == null || !mounted) return;
          state.didChange(date);
          _values[key] = date.toIso8601String().substring(0, 10);
        },
        child: InputDecorator(
          decoration: decoration.copyWith(
            suffixIcon: const Icon(Icons.calendar_today),
            errorText: state.errorText,
          ),
          isEmpty: state.value == null,
          child: Text(
            state.value == null
                ? ''
                : MaterialLocalizations.of(context)
                      .formatCompactDate(state.value!),
          ),
        ),
      ),
    );
  }

  Widget _input(Json field) {
    final key = field['key'] as String;
    final type = field['type'] as String;
    final value = _values[key];
    final label = field['label'] as String;
    final decoration = InputDecoration(labelText: label);
    if (type == 'ref' || type == 'frequency') {
      return _select(field, decoration, value);
    }
    if (type == 'date' && (key == 'fecha_inicio' || key == 'fecha_fin')) {
      return _contractDate(field, decoration);
    }
    final initial = value?.toString() ?? '';
    return TextFormField(
      initialValue: type == 'date' && initial.length > 10
          ? initial.substring(0, 10)
          : initial,
      decoration: decoration.copyWith(
        hintText: switch (type) {
          'date' => 'AAAA-MM-DD',
          'time' => 'HH:MM',
          'password' when widget.item != null => 'Escribe solo para cambiarla',
          _ => null,
        },
      ),
      inputFormatters: type == 'phone'
          ? [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(10),
            ]
          : null,
      keyboardType: switch (type) {
        'phone' => TextInputType.phone,
        'decimal' => const TextInputType.numberWithOptions(decimal: true),
        'email' => TextInputType.emailAddress,
        'date' || 'time' => TextInputType.datetime,
        _ => TextInputType.text,
      },
      obscureText: type == 'password',
      validator: (value) => _validate(field, value),
      onSaved: (value) => _values[key] = type == 'decimal'
          ? normalizedDecimal(value ?? '')
          : value?.trim(),
    );
  }

  bool get _newClient =>
      widget.item == null && widget.path.endsWith('/clientes');
  bool get _newClientUser =>
      widget.item == null &&
      _selectedRole == 4 &&
      widget.path.endsWith('/usuarios');

  Iterable<Json> _fields() sync* {
    for (final field in rows(widget.data, 'fields')) {
      if (_newClient && field['key'] == 'fk_usuario') continue;
      yield field;
      if (field['key'] == 'pass') {
        yield {
          'key': 'confirmar_pass',
          'label': 'Confirmar contraseña',
          'type': 'password',
          'required': widget.item == null,
        };
      }
    }
    if (_newClientUser) yield* rows(widget.data, 'campos_cliente');
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(widget.item == null ? 'Nuevo registro' : 'Editar registro'),
    ),
    body: AbsorbPointer(
      absorbing: _busy,
      child: Form(
        key: _form,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                '${widget.data['label']}',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              for (final field in _fields())
                Padding(
                  key: ValueKey(field['key']),
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _input(field),
                ),
              if (_newClient) ...[
                Text(
                  'Acceso del cliente',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                for (final field in const <Json>[
                  {
                    'key': 'usuario_cliente',
                    'label': 'Usuario',
                    'type': 'text',
                    'required': true,
                  },
                  {
                    'key': 'pass_cliente',
                    'label': 'Contraseña',
                    'type': 'password',
                    'required': true,
                  },
                  {
                    'key': 'confirmar_pass_cliente',
                    'label': 'Confirmar contraseña',
                    'type': 'password',
                    'required': true,
                  },
                ])
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _input(field),
                  ),
              ],
              FilledButton(
                onPressed: _busy ? null : _save,
                child: Text(_busy ? 'Guardando…' : 'Guardar'),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
