import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../services/chofer_api.dart';
import '../chofer/chofer_widgets.dart';
import '../chofer/manifiesto_pdf.dart';
import 'agenda_screen.dart';

class ClienteHome extends StatefulWidget {
  const ClienteHome({super.key, required this.api, required this.nombre});

  final ChoferApi api;
  final String nombre;

  @override
  State<ClienteHome> createState() => _ClienteHomeState();
}

class _ClienteHomeState extends State<ClienteHome> {
  late Future<Json> _visits;
  Future<Json>? _account;
  int _section = 0;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _visits = widget.api.get('cliente/visitas');
  }

  void _refresh() => setState(() {
    if (_section == 0) {
      _visits = widget.api.get('cliente/visitas');
    } else {
      _account = widget.api.get('cliente/cuenta');
    }
  });

  Future<void> _change(Json visit, String action, String today) async {
    final body = <String, dynamic>{'accion': action};
    if (action == 'reprogramar') {
      final day = await pickOperationDay(context, today, minimum: today);
      if (day == null || !mounted) return;
      body['fecha'] = day;
    }
    if (action == 'cancelar') {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Cancelar visita'),
          content: const Text(
            'La cancelación aplica únicamente a esta visita.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Volver'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Cancelar visita'),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;
    }
    setState(() => _busy = true);
    try {
      await widget.api.post('cliente/visitas/${visit['id']}', body);
      if (mounted) _refresh();
    } on ChoferError catch (error) {
      if (mounted) showMessage(context, error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text('Cliente · ${widget.nombre}'),
      actions: [
        IconButton(
          onPressed: _busy ? null : _refresh,
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
      future: _section == 0 ? _visits : _account!,
      retry: _refresh,
      builder: _section == 0 ? _visitList : _accountList,
    ),
    bottomNavigationBar: NavigationBar(
      selectedIndex: _section,
      onDestinationSelected: _busy
          ? null
          : (index) => setState(() {
              _section = index;
              if (index == 1) _account ??= widget.api.get('cliente/cuenta');
            }),
      destinations: const [
        NavigationDestination(
          icon: Icon(Icons.event_outlined),
          label: 'Visitas',
        ),
        NavigationDestination(
          icon: Icon(Icons.folder_open),
          label: 'Mi cuenta',
        ),
      ],
    ),
  );

  Widget _visitList(Json data) {
    final today = data['fecha'] as String;
    final visits = rows(data, 'items');
    final pending = visits.where(
      (visit) =>
          visit['activo'] == 1 &&
          ['pendiente', 'en_curso'].contains(visit['servicio']),
    );
    final history = visits.where((visit) => !pending.contains(visit));
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          'Mis recolecciones',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        if (pending.isEmpty) const Text('No tienes recolecciones pendientes.'),
        for (final visit in pending) _visitCard(visit, today),
        if (history.isNotEmpty) _heading('Historial de visitas'),
        for (final visit in history) _visitCard(visit, today),
      ],
    );
  }

  Widget _visitCard(Json visit, String today) {
    final date = (visit['fecha'] as String).substring(0, 10);
    final active = visit['activo'] == 1;
    final recovery =
        visit['respuesta_cliente'] == 'cancelada' &&
        visit['frecuencia'] == 'Mensual' &&
        date.substring(0, 7) == today.substring(0, 7);
    final editable =
        visit['servicio'] == 'pendiente' &&
        (recovery || (active && date.compareTo(today) >= 0));
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${visit['folio']} · $date',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            Text(
              '${(visit['fecha'] as String).substring(11, 16)} · ${visit['respuesta_cliente']}',
            ),
            if (visit['servicio'] != 'pendiente')
              Text(stopStatus(visit['servicio'] as String)),
            if (editable)
              Wrap(
                children: [
                  if (active && visit['respuesta_cliente'] != 'confirmada')
                    TextButton(
                      onPressed: _busy
                          ? null
                          : () => _change(visit, 'confirmar', today),
                      child: const Text('Confirmar'),
                    ),
                  TextButton(
                    onPressed: _busy
                        ? null
                        : () => _change(visit, 'reprogramar', today),
                    child: const Text('Reprogramar'),
                  ),
                  if (active)
                    TextButton(
                      onPressed: _busy
                          ? null
                          : () => _change(visit, 'cancelar', today),
                      child: const Text('Cancelar visita'),
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _accountList(Json data) => ListView(
    padding: const EdgeInsets.all(16),
    children: [
      for (final notice in rows(data, 'avisos'))
        Card(
          child: ListTile(
            leading: const Icon(Icons.campaign_outlined),
            title: Text('${notice['titulo']}'),
            subtitle: Text('${notice['descripcion']}'),
          ),
        ),
      for (final client in rows(data, 'clientes'))
        ListTile(
          title: Text('${client['nombre']}'),
          subtitle: Text('${client['direccion'] ?? ''}'),
        ),
      _accountLink('Contratos', 'contratos', data),
      _accountLink('Estado de cuenta', 'ventas', data),
      _accountLink('Manifiestos', 'manifiestos', data),
    ],
  );

  String _documentSummary(String key, Json item) => switch (key) {
    'contratos' =>
      '${item['inicio']} a ${item['fin']} · ${item['frecuencia']}'
          ' · Cuota ${mxn(item['monto'])} · ${item['estado'] == 1 ? 'Activo' : 'Inactivo'}',
    'ventas' =>
      '${item['fecha'] ?? ''} · Total ${mxn(item['total'])}'
          ' · Saldo ${mxn(item['saldo'])}',
    _ => '${item['fecha']}',
  };

  Widget _accountLink(String title, String key, Json data) {
    final items = rows(data, key);
    return ListTile(
      title: Text(title),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute<void>(
          builder: (context) => Scaffold(
            appBar: AppBar(
              title: Text(title),
              actions: [
                if (key != 'manifiestos' && items.isNotEmpty)
                  IconButton(
                    tooltip: 'Compartir PDF',
                    icon: const Icon(Icons.picture_as_pdf_outlined),
                    onPressed: () async {
                      try {
                        final pdf = pw.Document(
                          title: title,
                          author: 'EcoReco',
                        );
                        pdf.addPage(
                          pw.MultiPage(
                            pageFormat: PdfPageFormat.a4,
                            maxPages: items.length + 1,
                            build: (_) => [
                              pw.Header(level: 0, text: 'EcoReco · $title'),
                              for (final item in items)
                                pw.Padding(
                                  padding: const pw.EdgeInsets.only(bottom: 10),
                                  child: pw.Text(
                                    '${item['folio']} · ${_documentSummary(key, item)}',
                                  ),
                                ),
                            ],
                          ),
                        );
                        await Printing.sharePdf(
                          bytes: await pdf.save(),
                          filename: '$key.pdf',
                        );
                      } on Exception catch (error) {
                        if (context.mounted) showMessage(context, error);
                      }
                    },
                  ),
              ],
            ),
            body: items.isEmpty
                ? const Center(child: Text('No hay registros disponibles.'))
                : ListView.builder(
                    itemCount: items.length,
                    itemBuilder: (context, index) {
                      final item = items[index];
                      return ListTile(
                        title: Text('${item['folio']}'),
                        subtitle: Text(_documentSummary(key, item)),
                        trailing: key == 'manifiestos'
                            ? const Icon(Icons.chevron_right)
                            : null,
                        onTap: key != 'manifiestos'
                            ? null
                            : () => Navigator.push(
                                context,
                                MaterialPageRoute<void>(
                                  builder: (_) => _CustomerManifest(
                                    api: widget.api,
                                    id: item['id'].toString(),
                                  ),
                                ),
                              ),
                      );
                    },
                  ),
          ),
        ),
      ),
    );
  }

  Widget _heading(String title) => Padding(
    padding: const EdgeInsets.only(top: 14),
    child: Text(title, style: Theme.of(context).textTheme.titleLarge),
  );
}

class _CustomerManifest extends StatefulWidget {
  const _CustomerManifest({required this.api, required this.id});

  final ChoferApi api;
  final String id;

  @override
  State<_CustomerManifest> createState() => _CustomerManifestState();
}

class _CustomerManifestState extends State<_CustomerManifest> {
  late Future<Json> _data;

  @override
  void initState() {
    super.initState();
    _data = _load();
  }

  Future<Json> _load() => widget.api.get('cliente/manifiestos/${widget.id}');

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Manifiesto')),
    body: AsyncContent(
      future: _data,
      retry: () {
        final next = _load();
        setState(() {
          _data = next;
        });
      },
      builder: (data) => ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            '${data['folio']}',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          Text('Origen · ${data['origen'] ?? 'Sin dato'}'),
          Text('Destino · ${data['destino'] ?? 'Sin dato'}'),
          Text('Chofer · ${data['chofer'] ?? 'Sin dato'}'),
          Text('Emisión · ${data['emision']}'),
          if (data['entrega'] != null) Text('Entrega · ${data['entrega']}'),
          ManifiestoPdfButton(manifest: data, items: rows(data, 'items')),
          for (final item in rows(data, 'items'))
            ListTile(
              title: Text('${item['descripcion']}'),
              subtitle: Text(
                'Cantidad ${item['cantidad']} · ${item['peso']} kg',
              ),
            ),
        ],
      ),
    ),
  );
}
