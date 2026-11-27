import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../services/chofer_api.dart';
import 'chofer_servicio.dart';
import 'chofer_widgets.dart';
import 'manifiesto_pdf.dart';
import 'ticket_venta_pdf.dart';

class ChoferParada extends StatefulWidget {
  const ChoferParada({super.key, required this.api, required this.id});

  final ChoferApi api;
  final String id;

  @override
  State<ChoferParada> createState() => _ChoferParadaState();
}

class _ChoferParadaState extends State<ChoferParada> {
  late Future<Json> _data;
  bool _busy = false;

  String get _path => 'paradas/${widget.id}';

  @override
  void initState() {
    super.initState();
    _data = widget.api.get(_path);
  }

  void _refresh() {
    final next = widget.api.get(_path);
    setState(() {
      _data = next;
    });
  }

  Future<void> _perform(Future<void> Function() work) async {
    setState(() => _busy = true);
    try {
      await work();
      if (mounted) _refresh();
    } on Exception catch (error) {
      if (mounted) showMessage(context, error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _openMap(String address) async {
    final url = Uri.https('www.google.com', '/maps/search/', {
      'api': '1',
      'query': address,
    });
    try {
      if (!await launchUrl(url, mode: LaunchMode.externalApplication) &&
          mounted) {
        showMessage(context, 'No se pudo abrir el mapa.');
      }
    } on Exception catch (error) {
      if (mounted) showMessage(context, error);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Detalle de parada'),
      actions: [
        IconButton(
          tooltip: 'Actualizar',
          onPressed: _busy ? null : _refresh,
          icon: const Icon(Icons.refresh),
        ),
      ],
    ),
    body: AsyncContent(
      future: _data,
      retry: _refresh,
      builder: (stop) {
        final status = stop['estado'] as String;
        final address = (stop['direccion'] as String?) ?? '';
        final sales = rows(stop, 'ventas');
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              '${stop['cliente']}',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            Text(
              '${stop['folio'] ?? widget.id} · ${stop['ruta']} · ${stop['turno']}',
            ),
            Text('${stop['fecha']} · ${stopStatus(status)}'),
            if (address.isNotEmpty) ...[
              Text(address),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () => _openMap(address),
                  icon: const Icon(Icons.map_outlined),
                  label: const Text('Abrir mapa'),
                ),
              ),
            ],
            if (stop['telefono'] != null) Text('Teléfono ${stop['telefono']}'),
            if (stop['llegada'] != null) Text('Llegada · ${stop['llegada']}'),
            if (stop['cierre'] != null) Text('Cierre · ${stop['cierre']}'),
            if (stop['observaciones'] != null)
              Text('Observaciones · ${stop['observaciones']}'),
            if (stop['insumos'] != null) Text('Insumos · ${stop['insumos']}'),
            if (stop['motivo'] != null) Text('Motivo · ${stop['motivo']}'),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () =>
                    _open(_ClientVisits(api: widget.api, path: _path)),
                icon: const Icon(Icons.history),
                label: const Text('Historial de visitas al cliente'),
              ),
            ),
            const SizedBox(height: 16),
            if (status == 'pendiente' &&
                (stop['fecha_operable'] ?? stop['es_hoy']) == true)
              FilledButton.icon(
                onPressed: _busy
                    ? null
                    : () => _perform(() async {
                        await widget.api.post('$_path/inicio', {});
                      }),
                icon: const Icon(Icons.play_arrow),
                label: const Text('Registrar llegada'),
              ),
            if (status == 'en_curso') ...[
              FilledButton(
                onPressed: _busy
                    ? null
                    : () => _open(
                        ChoferServicio(
                          api: widget.api,
                          path: _path,
                          address: address,
                          initialNotes: stop['observaciones'] as String?,
                        ),
                      ),
                child: const Text('Capturar recolección'),
              ),
              OutlinedButton(
                onPressed: _busy
                    ? null
                    : () => _open(
                        _FailedVisit(
                          api: widget.api,
                          path: _path,
                          fee: stop['cargo_ausencia'] as String?,
                        ),
                      ),
                child: const Text('Registrar visita fallida'),
              ),
            ],
            if (status == 'completada') ...[
              OutlinedButton.icon(
                onPressed: () =>
                    _open(ChoferManifiesto(api: widget.api, path: _path)),
                icon: const Icon(Icons.description_outlined),
                label: const Text('Consultar manifiesto'),
              ),
              for (final item in rows(stop, 'residuos'))
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text('${item['nombre']}'),
                  subtitle: Text(
                    'Cantidad ${item['cantidad']} · ${item['peso']} kg',
                  ),
                ),
            ],
            if (stop['tiene_foto'] == 1)
              TextButton(
                onPressed: () => _evidence('foto'),
                child: const Text('Ver fotografía'),
              ),
            if (stop['tiene_firma'] == 1)
              TextButton(
                onPressed: () => _evidence('firma'),
                child: const Text('Ver firma'),
              ),
            if (sales.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text('Cobranza', style: Theme.of(context).textTheme.titleLarge),
              for (final sale in sales) _sale(stop, sale),
            ],
            if (rows(stop, 'pagos').isNotEmpty) ...[
              Text(
                'Pagos de esta visita',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              for (final payment in rows(stop, 'pagos'))
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    '${payment['metodo']} · ${mxn(payment['importe'])}',
                  ),
                  subtitle: Text('${payment['fecha']}'),
                ),
            ],
          ],
        );
      },
    ),
  );

  Widget _sale(Json stop, Json sale) {
    final isCurrent = sale['fk_recoleccion'] == widget.id;
    final canPay =
        (stop['fecha_operable'] ?? stop['es_hoy']) == true &&
        (double.tryParse('${sale['saldo']}') ?? 0) > 0;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${isCurrent ? 'Venta de la visita' : 'Adeudo anterior'} · ${sale['folio']}',
            ),
            if (isCurrent)
              for (final line in rows(stop, 'conceptos'))
                Text('${line['concepto']} · ${mxn(line['subtotal'])}'),
            if (isCurrent) Text('IVA ${mxn(sale['iva'])}'),
            Text('Total ${mxn(sale['total'])} · Saldo ${mxn(sale['saldo'])}'),
            if (isCurrent) TicketVentaPdfButton(stop: stop, sale: sale),
            if (canPay)
              TextButton(
                onPressed: _busy
                    ? null
                    : () => _open(
                        _Payment(api: widget.api, path: _path, sale: sale),
                      ),
                child: const Text('Registrar pago'),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _open(Widget screen) async {
    final changed = await Navigator.of(context)
        .push<bool>(MaterialPageRoute(builder: (_) => screen));
    if (changed == true && mounted) _refresh();
  }

  Future<void> _evidence(String type) async {
    final future = widget.api.evidence('$_path/evidencias/$type');
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(type == 'foto' ? 'Fotografía' : 'Firma del cliente'),
        content: SizedBox(
          width: 500,
          height: 240,
          child: FutureBuilder<Uint8List>(
            future: future,
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Center(child: Text('${snapshot.error}'));
              }
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              return Image.memory(snapshot.data!, fit: BoxFit.contain);
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
  }
}

class _ClientVisits extends StatefulWidget {
  const _ClientVisits({required this.api, required this.path});

  final ChoferApi api;
  final String path;

  @override
  State<_ClientVisits> createState() => _ClientVisitsState();
}

class _ClientVisitsState extends State<_ClientVisits> {
  late Future<Json> _data;

  @override
  void initState() {
    super.initState();
    _data = _load();
  }

  Future<Json> _load() => widget.api.get('${widget.path}/historial');

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Últimas visitas al cliente')),
    body: AsyncContent(
      future: _data,
      retry: () {
        final next = _load();
        setState(() {
          _data = next;
        });
      },
      builder: (data) {
        final visits = rows(data, 'paradas');
        if (visits.isEmpty) {
          return const Center(
            child: Text('Aún no tienes visitas cerradas para este cliente.'),
          );
        }
        return ListView(
          children: [
            for (final visit in visits)
              ListTile(
                title: Text(
                  '${visit['folio'] ?? visit['pk_recoleccion']} · ${stopStatus(visit['estado'] as String)}',
                ),
                subtitle: Text('${visit['fecha']} · ${visit['ruta']}'),
              ),
          ],
        );
      },
    ),
  );
}

class _Payment extends StatefulWidget {
  const _Payment({required this.api, required this.path, required this.sale});

  final ChoferApi api;
  final String path;
  final Json sale;

  @override
  State<_Payment> createState() => _PaymentState();
}

class _PaymentState extends State<_Payment> {
  final _form = GlobalKey<FormState>();
  late final _amount = TextEditingController(text: '${widget.sale['saldo']}');
  final _key = operationKey();
  late Future<Json> _catalog;
  String? _method;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _catalog = widget.api.get('catalogos');
  }

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _busy = true);
    try {
      await widget.api.post('${widget.path}/pagos', {
        'fk_venta': widget.sale['pk_venta'],
        'fk_metodo_pago': _method,
        'importe': normalizedDecimal(_amount.text),
        'clave': _key,
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
    appBar: AppBar(title: Text('Cobrar ${widget.sale['folio']}')),
    body: AsyncContent(
      future: _catalog,
      retry: () {
        final next = widget.api.get('catalogos');
        setState(() {
          _catalog = next;
        });
      },
      builder: (catalog) => Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text('Saldo pendiente ${mxn(widget.sale['saldo'])}'),
            DecimalField(controller: _amount, label: 'Importe recibido'),
            DropdownButtonFormField<String>(
              initialValue: _method,
              decoration: const InputDecoration(labelText: 'Método de pago'),
              items: [
                for (final method in rows(catalog, 'metodos'))
                  DropdownMenuItem<String>(
                    value: method['id'].toString(),
                    child: Text('${method['nombre']}'),
                  ),
              ],
              onChanged: _busy
                  ? null
                  : (value) => setState(() => _method = value),
              validator: (value) =>
                  value == null ? 'Selecciona un método' : null,
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _busy ? null : _save,
              child: const Text('Confirmar pago'),
            ),
          ],
        ),
      ),
    ),
  );
}

class _FailedVisit extends StatefulWidget {
  const _FailedVisit({required this.api, required this.path, this.fee});

  final ChoferApi api;
  final String path;
  final String? fee;

  @override
  State<_FailedVisit> createState() => _FailedVisitState();
}

class _FailedVisitState extends State<_FailedVisit> {
  final _reason = TextEditingController();
  Uint8List? _photo;
  bool _busy = false;

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_reason.text.trim().isEmpty || _photo == null) {
      showMessage(context, 'Captura el motivo y la fotografía.');
      return;
    }
    setState(() => _busy = true);
    try {
      await widget.api.post('${widget.path}/fallida', {
        'motivo': _reason.text.trim(),
        'foto': base64Encode(_photo!),
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
    appBar: AppBar(title: const Text('Visita fallida')),
    body: ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (widget.fee != null)
          Text('Cargo contractual por ausencia · ${mxn(widget.fee)}'),
        TextField(
          controller: _reason,
          maxLength: 255,
          decoration: const InputDecoration(
            labelText: 'Motivo de la visita fallida',
          ),
        ),
        PhotoInput(
          photo: _photo,
          enabled: !_busy,
          onChanged: (photo) => setState(() => _photo = photo),
        ),
        FilledButton(
          onPressed: _busy ? null : _save,
          child: const Text('Guardar incidencia'),
        ),
      ],
    ),
  );
}

class ChoferManifiesto extends StatefulWidget {
  const ChoferManifiesto({super.key, required this.api, required this.path});

  final ChoferApi api;
  final String path;

  @override
  State<ChoferManifiesto> createState() => _ManifestState();
}

class _ManifestState extends State<ChoferManifiesto> {
  late Future<Json> _data;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _data = _load();
  }

  Future<Json> _load() => widget.api.get('${widget.path}/manifiesto');

  Future<void> _deliver(String destination) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmar entrega de residuos'),
        content: Text(
          'Se registrará la entrega en $destination con la fecha y hora actuales.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Registrar entrega'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _busy = true);
    try {
      await widget.api.post('${widget.path}/manifiesto/entrega', {});
      if (mounted) {
        final next = _load();
        setState(() {
          _data = next;
        });
      }
    } on Exception catch (error) {
      if (mounted) showMessage(context, error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Manifiesto de recolección')),
    body: AsyncContent(
      future: _data,
      retry: () {
        final next = _load();
        setState(() {
          _data = next;
        });
      },
      builder: (manifest) => ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            '${manifest['folio']}',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          Text('Emitido ${manifest['fecha_emision']}'),
          Text('Cliente · ${manifest['cliente']}'),
          Text('Chofer · ${manifest['chofer']}'),
          Text('Origen · ${manifest['origen']}'),
          Text('Destino · ${manifest['destino'] ?? 'Por registrar'}'),
          if (manifest['fecha_entrega'] != null)
            Text('Entregado · ${manifest['fecha_entrega']}')
          else
            Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton(
                onPressed: _busy
                    ? null
                    : () =>
                          _deliver('${manifest['destino'] ?? 'Por registrar'}'),
                child: const Text('Registrar entrega'),
              ),
            ),
          if (manifest['observaciones'] != null)
            Text('${manifest['observaciones']}'),
          ManifiestoPdfButton(
            manifest: manifest,
            items: rows(manifest, 'residuos'),
            loadSignature: manifest['tiene_firma'] == true
                ? () => widget.api.evidence('${widget.path}/evidencias/firma')
                : null,
          ),
          for (final item in rows(manifest, 'residuos'))
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text('${item['descripcion']}'),
              subtitle: Text(
                'Cantidad ${item['cantidad']} · Peso ${item['peso']} kg',
              ),
            ),
        ],
      ),
    ),
  );
}
