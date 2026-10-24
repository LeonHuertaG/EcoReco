import 'package:flutter/material.dart';

class FormularioUsuarioScreen extends StatefulWidget {
  final Map<String, String>? usuario;

  const FormularioUsuarioScreen({super.key, this.usuario});

  @override
  State<FormularioUsuarioScreen> createState() =>
      _FormularioUsuarioScreenState();
}

class _FormularioUsuarioScreenState extends State<FormularioUsuarioScreen> {
  static const Color verde = Color(0xFF20794D);

  final formKey = GlobalKey<FormState>();

  late TextEditingController nombreController;
  late TextEditingController correoController;
  late TextEditingController telefonoController;
  late TextEditingController direccionController;

  @override
  void initState() {
    super.initState();

    nombreController = TextEditingController(
      text: widget.usuario?['nombre'] ?? '',
    );
    correoController = TextEditingController(
      text: widget.usuario?['correo'] ?? '',
    );
    telefonoController = TextEditingController(
      text: widget.usuario?['telefono'] ?? '',
    );
    direccionController = TextEditingController(
      text: widget.usuario?['direccion'] ?? '',
    );
  }

  @override
  void dispose() {
    nombreController.dispose();
    correoController.dispose();
    telefonoController.dispose();
    direccionController.dispose();
    super.dispose();
  }

  Widget crearCampo(
    String etiqueta,
    TextEditingController controller,
    IconData icono, {
    TextInputType? tipo,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextFormField(
        controller: controller,
        keyboardType: tipo,
        decoration: InputDecoration(
          labelText: etiqueta,
          prefixIcon: Icon(icono, color: verde),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        ),
        validator: (valor) {
          if (valor == null || valor.trim().isEmpty) {
            return 'Este campo es obligatorio';
          }
          return null;
        },
      ),
    );
  }

  void guardar() {
    if (!formKey.currentState!.validate()) return;

    Navigator.pop(context, <String, String>{
      'nombre': nombreController.text.trim(),
      'correo': correoController.text.trim(),
      'telefono': telefonoController.text.trim(),
      'direccion': direccionController.text.trim(),
    });
  }

  @override
  Widget build(BuildContext context) {
    final editando = widget.usuario != null;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F8F4),
      appBar: AppBar(
        title: Text(editando ? 'Editar usuario' : 'Agregar usuario'),
        backgroundColor: verde,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Card(
          color: Colors.white,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Form(
              key: formKey,
              child: Column(
                children: [
                  crearCampo('Nombre completo', nombreController, Icons.person),
                  crearCampo(
                    'Correo electrónico',
                    correoController,
                    Icons.email,
                    tipo: TextInputType.emailAddress,
                  ),
                  crearCampo(
                    'Teléfono',
                    telefonoController,
                    Icons.phone,
                    tipo: TextInputType.phone,
                  ),
                  crearCampo(
                    'Dirección',
                    direccionController,
                    Icons.location_on,
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: guardar,
                      icon: const Icon(Icons.save),
                      label: const Text('Guardar usuario'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: verde,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.all(16),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
