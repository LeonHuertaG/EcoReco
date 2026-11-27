import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../services/chofer_api.dart';
import '../auth/login_screen.dart';

String isoDay(DateTime date) => date.toIso8601String().substring(0, 10);
String mxn(Object? value) => '\$${value ?? '0.00'}';

String stopStatus(String status) => switch (status) {
  'en_curso' => 'En curso',
  'completada' => 'Completada',
  'fallida' => 'Visita fallida',
  _ => 'Pendiente',
};

Future<void> closeSession(BuildContext context, ChoferApi api) async {
  try {
    await api.logout();
  } on ChoferError {
    // Se descarta la sesión local incluso si el servidor no responde.
  }
  if (context.mounted) {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (_) => false,
    );
  }
}

void showMessage(BuildContext context, Object message) {
  ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(content: Text(message.toString())));
}

class AsyncContent<T> extends StatelessWidget {
  const AsyncContent({
    super.key,
    required this.future,
    required this.retry,
    required this.builder,
  });

  final Future<T> future;
  final VoidCallback retry;
  final Widget Function(T data) builder;

  @override
  Widget build(BuildContext context) => FutureBuilder<T>(
    future: future,
    builder: (context, snapshot) {
      if (snapshot.connectionState != ConnectionState.done) {
        return const Center(child: CircularProgressIndicator());
      }
      if (snapshot.hasError) {
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('${snapshot.error}', textAlign: TextAlign.center),
                TextButton(onPressed: retry, child: const Text('Reintentar')),
              ],
            ),
          ),
        );
      }
      return builder(snapshot.data as T);
    },
  );
}

Future<String?> askText(
  BuildContext context, {
  required String title,
  required String label,
}) async {
  String value = '';
  return showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: TextField(
        autofocus: true,
        maxLength: 255,
        decoration: InputDecoration(labelText: label),
        onChanged: (text) => value = text,
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: () {
            if (value.trim().isNotEmpty) Navigator.pop(context, value.trim());
          },
          child: const Text('Guardar'),
        ),
      ],
    ),
  );
}

class DecimalField extends StatelessWidget {
  const DecimalField({
    super.key,
    required this.controller,
    required this.label,
    this.allowZero = false,
  });

  final TextEditingController controller;
  final String label;
  final bool allowZero;

  @override
  Widget build(BuildContext context) => TextFormField(
    controller: controller,
    keyboardType: const TextInputType.numberWithOptions(decimal: true),
    decoration: InputDecoration(labelText: label),
    validator: (value) {
      final input = normalizedDecimal(value ?? '');
      if (!RegExp(r'^\d{1,8}(\.\d{1,2})?$').hasMatch(input)) {
        return 'Ingresa un valor con hasta dos decimales';
      }
      if (!allowZero && double.parse(input) == 0) {
        return 'Debe ser mayor que cero';
      }
      return null;
    },
  );
}

String normalizedDecimal(String input) => input.trim().replaceAll(',', '.');

class PhotoInput extends StatelessWidget {
  const PhotoInput({
    super.key,
    required this.photo,
    required this.enabled,
    required this.onChanged,
  });

  final Uint8List? photo;
  final bool enabled;
  final ValueChanged<Uint8List?> onChanged;

  Future<void> _pick(BuildContext context, ImageSource source) async {
    try {
      final file = await ImagePicker().pickImage(
        source: source,
        maxWidth: 1600,
        maxHeight: 1600,
        imageQuality: 80,
      );
      if (file == null || !context.mounted) return;
      if (await file.length() > 2097152) {
        if (context.mounted) showMessage(context, 'La imagen supera 2 MB.');
        return;
      }
      final bytes = await file.readAsBytes();
      if (!context.mounted) return;
      final isPng =
          bytes.length >= 8 &&
          bytes[0] == 0x89 &&
          bytes[1] == 0x50 &&
          bytes[2] == 0x4e &&
          bytes[3] == 0x47;
      final isJpeg =
          bytes.length >= 3 &&
          bytes[0] == 0xff &&
          bytes[1] == 0xd8 &&
          bytes[2] == 0xff;
      if (!isPng && !isJpeg) {
        showMessage(context, 'Selecciona una foto en formato JPEG o PNG.');
        return;
      }
      onChanged(bytes);
    } on Exception catch (error) {
      if (context.mounted) showMessage(context, error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final platform = Theme.of(context).platform;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (photo != null) Image.memory(photo!, height: 150),
        Wrap(
          spacing: 8,
          children: [
            if (platform == TargetPlatform.android ||
                platform == TargetPlatform.iOS)
              TextButton.icon(
                onPressed: enabled
                    ? () => _pick(context, ImageSource.camera)
                    : null,
                icon: const Icon(Icons.photo_camera_outlined),
                label: const Text('Tomar foto'),
              ),
            TextButton.icon(
              onPressed: enabled
                  ? () => _pick(context, ImageSource.gallery)
                  : null,
              icon: const Icon(Icons.image_outlined),
              label: Text(photo == null ? 'Adjuntar foto' : 'Cambiar foto'),
            ),
            if (photo != null)
              TextButton(
                onPressed: enabled ? () => onChanged(null) : null,
                child: const Text('Quitar'),
              ),
          ],
        ),
      ],
    );
  }
}
