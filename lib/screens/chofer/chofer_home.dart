import 'package:flutter/material.dart';

import '../../services/chofer_api.dart';
import 'chofer_caja.dart';
import 'chofer_parada.dart';
import 'chofer_widgets.dart';

class ChoferHome extends StatefulWidget {
  const ChoferHome({super.key, required this.nombre, required this.api});

  final String nombre;
  final ChoferApi api;

  @override
  State<ChoferHome> createState() => _ChoferHomeState();
}

class _ChoferHomeState extends State<ChoferHome> {
  late Future<Json> _data;
  String? _cashDay;

  @override
  void initState() {
    super.initState();
    _data = _load();
  }

  Future<Json> _load() => widget.api.get('paradas');

  void _refresh() {
    final next = _load();
    setState(() {
      _data = next;
    });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Chofer · Paradas pendientes'),
      actions: [
        IconButton(
          tooltip: 'Actualizar',
          onPressed: _refresh,
          icon: const Icon(Icons.refresh),
        ),
        IconButton(
          tooltip: 'Cerrar sesión',
          onPressed: () => closeSession(context, widget.api),
          icon: const Icon(Icons.logout),
        ),
      ],
    ),
    body: AsyncContent(
      future: _data,
      retry: _refresh,
      builder: (data) {
        final stops = rows(data, 'paradas');
        final cash = data['cajas'] == null ? <Json>[] : rows(data, 'cajas');
        final cashDays = cash.map((item) => item['fecha'] as String).toSet();
        final day = cashDays.contains(_cashDay)
            ? _cashDay
            : cashDays.isEmpty
            ? null
            : cashDays.first;
        final shifts = cash.where((item) => item['fecha'] == day);
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              widget.nombre,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            Wrap(
              spacing: 8,
              children: [
                TextButton.icon(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => _History(api: widget.api),
                    ),
                  ),
                  icon: const Icon(Icons.receipt_long),
                  label: const Text('Historial de ventas'),
                ),
                TextButton.icon(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          _History(api: widget.api, manifests: true),
                    ),
                  ),
                  icon: const Icon(Icons.description_outlined),
                  label: const Text('Manifiestos'),
                ),
              ],
            ),
            if (stops.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 32),
                child: Text('No tienes paradas pendientes.'),
              ),
            for (var index = 0; index < stops.length; index++)
              _stopTile(stops, index),
            if (shifts.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text(
                'Caja por jornada y turno',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              DropdownButton<String>(
                value: day,
                items: [
                  for (final date in cashDays)
                    DropdownMenuItem(value: date, child: Text(date)),
                ],
                onChanged: (date) => setState(() => _cashDay = date),
              ),
              for (final shift in shifts)
                ListTile(
                  leading: const Icon(Icons.account_balance_wallet_outlined),
                  title: Text(shift['nombre'] as String),
                  subtitle: const Text('Pagos, viáticos y corte'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ChoferCaja(
                        api: widget.api,
                        day: day!,
                        shift: shift['id'] as String,
                        name: shift['nombre'] as String,
                      ),
                    ),
                  ),
                ),
            ],
          ],
        );
      },
    ),
  );

  Widget _stopTile(List<Json> stops, int index) {
    final stop = stops[index];
    final previous = index > 0 ? stops[index - 1] : null;
    final startsGroup =
        previous?['fk_turno'] != stop['fk_turno'] ||
        previous?['fk_ruta'] != stop['fk_ruta'];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (startsGroup)
          Padding(
            padding: const EdgeInsets.fromLTRB(0, 16, 0, 4),
            child: Text(
              '${stop['turno']} · ${stop['ruta']}',
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
        Card(
          child: ListTile(
            leading: const Icon(Icons.location_on_outlined),
            title: Text('${stop['cliente']}'),
            subtitle: Text(
              '${stop['fecha'].toString().replaceFirst('T', ' ')} · '
              '${stopStatus(stop['estado'] as String)}\n${stop['direccion'] ?? ''}',
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ChoferParada(
                    api: widget.api,
                    id: stop['pk_recoleccion'].toString(),
                  ),
                ),
              );
              if (mounted) _refresh();
            },
          ),
        ),
      ],
    );
  }
}

class _History extends StatefulWidget {
  const _History({required this.api, this.manifests = false});

  final ChoferApi api;
  final bool manifests;

  @override
  State<_History> createState() => _HistoryState();
}

class _HistoryState extends State<_History> {
  final _filter = TextEditingController();
  late Future<Json> _data;

  Future<Json> _load() => widget.api.get(
    widget.manifests ? 'manifiestos' : 'ventas',
    {(widget.manifests ? 'folio' : 'cliente'): _filter.text.trim()},
  );

  @override
  void initState() {
    super.initState();
    _data = _load();
  }

  @override
  void dispose() {
    _filter.dispose();
    super.dispose();
  }

  void _refresh() {
    final next = _load();
    setState(() {
      _data = next;
    });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(widget.manifests ? 'Manifiestos' : 'Historial de ventas'),
    ),
    body: Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: TextField(
            controller: _filter,
            onSubmitted: (_) => _refresh(),
            decoration: InputDecoration(
              labelText: widget.manifests
                  ? 'Buscar por folio'
                  : 'Filtrar por cliente',
              suffixIcon: IconButton(
                tooltip: 'Buscar',
                onPressed: _refresh,
                icon: const Icon(Icons.search),
              ),
            ),
          ),
        ),
        Expanded(
          child: AsyncContent(
            future: _data,
            retry: _refresh,
            builder: (data) {
              final items = rows(
                data,
                widget.manifests ? 'manifiestos' : 'ventas',
              );
              if (items.isEmpty) {
                return const Center(child: Text('No hay resultados.'));
              }
              return ListView(
                children: [
                  for (final item in items)
                    ListTile(
                      title: Text('${item['folio']} · ${item['cliente']}'),
                      subtitle: Text(
                        widget.manifests
                            ? '${item['fecha']}'
                            : '${item['fecha']} · Total ${mxn(item['total'])} · Saldo ${mxn(item['saldo'])}',
                      ),
                      onTap: item['fk_recoleccion'] == null
                          ? null
                          : () async {
                              final id = item['fk_recoleccion'].toString();
                              await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => widget.manifests
                                      ? ChoferManifiesto(
                                          api: widget.api,
                                          path: 'paradas/$id',
                                        )
                                      : ChoferParada(api: widget.api, id: id),
                                ),
                              );
                              if (mounted) _refresh();
                            },
                    ),
                ],
              );
            },
          ),
        ),
      ],
    ),
  );
}
