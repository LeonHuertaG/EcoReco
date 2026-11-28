import 'package:ecoreco/main.dart';
import 'package:ecoreco/screens/chofer/chofer_home.dart';
import 'package:ecoreco/screens/chofer/manifiesto_pdf.dart';
import 'package:ecoreco/services/chofer_api.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('EcoReco abre en el inicio de sesión', (tester) async {
    await tester.pumpWidget(const MyApp());

    expect(find.text('EcoReco'), findsOneWidget);
    expect(find.text('Usuario o Correo'), findsOneWidget);
    expect(find.text('Contraseña'), findsOneWidget);
    expect(find.text('INGRESAR'), findsOneWidget);
  });

  testWidgets('Volver desde el detalle recarga la ruta del chofer', (
    tester,
  ) async {
    final api = _RouteApi();
    await tester.pumpWidget(
      MaterialApp(
        home: ChoferHome(nombre: 'Chofer', api: api),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cliente de prueba'));
    await tester.pumpAndSettle();
    expect(find.text('Detalle de parada'), findsOneWidget);

    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Cliente de prueba'), findsOneWidget);
    expect(api.routeLoads, 2);
  });

  testWidgets('Compartir manifiesto envía un PDF con el folio', (tester) async {
    const channel = MethodChannel('net.nfet.printing');
    final messenger = tester.binding.defaultBinaryMessenger;
    MethodCall? shared;
    messenger.setMockMethodCallHandler(channel, (call) async {
      shared = call;
      return 1;
    });
    addTearDown(() => messenger.setMockMethodCallHandler(channel, null));

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: ManifiestoPdfButton(
            manifest: {
              'folio': 'M-123',
              'cliente': 'Clínica',
              'emision': '2026-11-07',
            },
            items: [
              {'descripcion': 'Residuos', 'cantidad': 1, 'peso': '2.00'},
            ],
          ),
        ),
      ),
    );
    await tester.tap(find.text('Compartir PDF'));
    await tester.pumpAndSettle();

    expect(shared?.method, 'sharePdf');
    expect(shared?.arguments['name'], 'manifiesto-M-123.pdf');
    final bytes = shared?.arguments['doc'] as Uint8List;
    expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
  });
}

class _RouteApi extends ChoferApi {
  _RouteApi() : super('test');

  static const stopId = '507f1f77bcf86cd799439011';

  int routeLoads = 0;

  @override
  Future<Json> get(String path, [Map<String, String>? query]) async {
    const stop = {
      'pk_recoleccion': stopId,
      'fk_ruta': '507f1f77bcf86cd799439012',
      'fk_turno': '507f1f77bcf86cd799439013',
      'fecha': '2026-11-07T09:00:00',
      'cliente': 'Cliente de prueba',
      'ruta': 'Ruta de prueba',
      'turno': 'Matutino',
      'estado': 'pendiente',
    };
    if (path == 'paradas') {
      routeLoads++;
      return {
        'fecha': '2026-11-07',
        'paradas': [stop],
      };
    }
    if (path == 'paradas/$stopId') {
      return {...stop, 'ventas': <Json>[], 'pagos': <Json>[]};
    }
    throw StateError('Ruta inesperada: $path');
  }
}
