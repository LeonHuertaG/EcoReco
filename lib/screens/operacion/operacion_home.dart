import 'package:flutter/material.dart';

import '../../services/chofer_api.dart';
import '../chofer/chofer_caja.dart';
import '../chofer/chofer_widgets.dart';
import 'agenda_screen.dart';
import 'catalogo_screen.dart';

class OperacionHome extends StatefulWidget {
  const OperacionHome({
    super.key,
    required this.nombre,
    required this.token,
    required this.admin,
  });
  final String nombre;
  final String token;
  final bool admin;

  @override
  State<OperacionHome> createState() => _OperacionHomeState();
}

class _OperacionHomeState extends State<OperacionHome> {
  late final _api = ChoferApi(widget.token, scope: 'operacion');
  late Future<Json> _data;

  @override
  void initState() {
    super.initState();
    _data = _api.get('catalogos');
  }

  void _open(Widget screen) =>
      Navigator.push(context, MaterialPageRoute(builder: (_) => screen));

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(widget.admin ? 'Administración' : 'Gestión comercial'),
      actions: [
        IconButton(
          onPressed: () => closeSession(context, _api),
          tooltip: 'Cerrar sesión',
          icon: const Icon(Icons.logout),
        ),
      ],
    ),
    body: AsyncContent(
      future: _data,
      retry: () {
        final next = _api.get('catalogos');
        setState(() {
          _data = next;
        });
      },
      builder: (data) => ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(widget.nombre, style: Theme.of(context).textTheme.headlineSmall),
          _entry(
            'Calendario y rutas',
            Icons.event_available,
            () => _open(AgendaScreen(api: _api)),
          ),
          if (widget.admin) ...[
            _entry(
              'Ventas, incidencias y bitácora',
              Icons.bar_chart,
              () => _open(_Reports(api: _api)),
            ),
            _entry(
              'Revisión de cortes',
              Icons.account_balance_wallet_outlined,
              () => _open(RevisionCortes(api: ChoferApi(widget.token))),
            ),
          ],
          const SizedBox(height: 12),
          Text('Catálogos', style: Theme.of(context).textTheme.titleLarge),
          for (final item in rows(data, 'items'))
            _entry(
              '${item['label']}',
              Icons.folder_outlined,
              () => _open(
                CatalogoScreen(
                  api: _api,
                  resource: item['key'] as String,
                  label: item['label'] as String,
                ),
              ),
            ),
        ],
      ),
    ),
  );

  Widget _entry(String label, IconData icon, VoidCallback tap) => Card(
    child: ListTile(
      leading: Icon(icon),
      title: Text(label),
      trailing: const Icon(Icons.chevron_right),
      onTap: tap,
    ),
  );
}

class _Reports extends StatefulWidget {
  const _Reports({required this.api});
  final ChoferApi api;

  @override
  State<_Reports> createState() => _ReportsState();
}

class _ReportsState extends State<_Reports> {
  String? _day;
  late Future<Json> _data;

  @override
  void initState() {
    super.initState();
    _data = _load();
  }

  Future<Json> _load() =>
      widget.api.get('reportes', _day == null ? null : {'fecha': _day!});
  void _refresh() {
    final next = _load();
    setState(() {
      _data = next;
    });
  }

  Future<void> _pick(String day) async {
    final selected = await pickOperationDay(context, day);
    if (selected == null || !mounted) return;
    _day = selected;
    _refresh();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Reportes de operación')),
    body: AsyncContent(
      future: _data,
      retry: _refresh,
      builder: (data) {
        final day = data['fecha'] as String;
        final server = data['servidor'] as Json;
        final job = server['ultima_generacion'] as Json?;
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton.icon(
                onPressed: () => _pick(day),
                icon: const Icon(Icons.calendar_today),
                label: Text(day),
              ),
            ),
            Card(
              child: ListTile(
                leading: const Icon(Icons.monitor_heart_outlined),
                title: const Text('Estado del servidor'),
                subtitle: Text(
                  '${server['solicitudes']} solicitudes · ${server['errores']} errores del servidor\n'
                  'Latencia media ${server['latencia_ms']} ms\n'
                  '${job == null ? 'Generación automática sin ejecuciones' : "Última generación ${job['estado']} · ${job['fecha']}"}',
                ),
              ),
            ),
            const Text('Ventas'),
            for (final item in rows(data, 'ventas'))
              ListTile(
                title: Text('${item['folio']} · ${item['cliente']}'),
                subtitle: Text(
                  'Total ${mxn(item['total'])} · Saldo ${mxn(item['saldo'])}',
                ),
              ),
            const Text('Incidencias'),
            for (final item in rows(data, 'incidencias'))
              ListTile(
                title: Text('${item['folio']} · ${item['cliente']}'),
                subtitle: Text('${item['motivo']}'),
              ),
            const Text('Bitácora'),
            for (final item in rows(data, 'eventos'))
              ListTile(
                title: Text(
                  '${item['accion']} · ${item['recurso']} #${item['recurso_id']}',
                ),
                subtitle: Text('${item['hora']} · ${item['usuario']}'),
              ),
          ],
        );
      },
    ),
  );
}
