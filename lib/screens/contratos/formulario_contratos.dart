import 'package:flutter/material.dart';

class FormularioContratoScreen extends StatefulWidget {
  final Map<String, String>? contrato;

  const FormularioContratoScreen({super.key, this.contrato});

  @override
  State<FormularioContratoScreen> createState() =>
      _FormularioContratoScreenState();
}

class _FormularioContratoScreenState extends State<FormularioContratoScreen> {
  static const Color verde = Color(0xFF20794D);

  final formKey = GlobalKey<FormState>();

  late TextEditingController folioController;
  late TextEditingController usuarioController;
  late TextEditingController inicioController;
  late TextEditingController finController;
  late TextEditingController montoController;

  String estado = 'Activo';

  @override
  void initState() {
    super.initState();

    folioController = TextEditingController(
      text: widget.contrato?['folio'] ?? '',
    );
    usuarioController = TextEditingController(
      text: widget.contrato?['usuario'] ?? '',
    );
    inicioController = TextEditingController(
      text: widget.contrato?['inicio'] ?? '',
    );
    finController = TextEditingController(text: widget.contrato?['fin'] ?? '');
    montoController = TextEditingController(
      text: widget.contrato?['monto'] ?? '',
    );
    estado = widget.contrato?['estado'] ?? 'Activo';
  }

  @override
  void dispose() {
    folioController.dispose();
    usuarioController.dispose();
    inicioController.dispose();
    finController.dispose();
    montoController.dispose();
    super.dispose();
  }

  Widget campo(
    String etiqueta,
    TextEditingController controller,
    IconData icono, {
    bool soloLectura = false,
    VoidCallback? alTocar,
    TextInputType? tipo,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextFormField(
        controller: controller,
        readOnly: soloLectura,
        onTap: alTocar,
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

  Future<void> seleccionarFecha(TextEditingController controller) async {
    final fecha = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );

    if (fecha != null) {
      controller.text =
          '${fecha.year}-${fecha.month.toString().padLeft(2, '0')}-'
          '${fecha.day.toString().padLeft(2, '0')}';
    }
  }

  void guardar() {
    if (!formKey.currentState!.validate()) return;

    final inicio = DateTime.parse(inicioController.text);
    final fin = DateTime.parse(finController.text);

    if (fin.isBefore(inicio)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'La fecha de vencimiento no puede ser anterior al inicio',
          ),
        ),
      );
      return;
    }

    final monto = double.tryParse(
      montoController.text.trim().replaceAll(',', '.'),
    );

    if (monto == null || monto < 0) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Ingresa un monto válido')));
      return;
    }

    Navigator.pop(context, <String, String>{
      'folio': folioController.text.trim(),
      'usuario': usuarioController.text.trim(),
      'inicio': inicioController.text,
      'fin': finController.text,
      'monto': monto.toStringAsFixed(2),
      'estado': estado,
    });
  }

  @override
  Widget build(BuildContext context) {
    final editando = widget.contrato != null;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F8F4),
      appBar: AppBar(
        title: Text(editando ? 'Editar contrato' : 'Agregar contrato'),
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
                  campo('Folio', folioController, Icons.numbers),
                  campo('Usuario asociado', usuarioController, Icons.person),
                  campo(
                    'Fecha de inicio',
                    inicioController,
                    Icons.calendar_today,
                    soloLectura: true,
                    alTocar: () => seleccionarFecha(inicioController),
                  ),
                  campo(
                    'Fecha de vencimiento',
                    finController,
                    Icons.event,
                    soloLectura: true,
                    alTocar: () => seleccionarFecha(finController),
                  ),
                  campo(
                    'Monto',
                    montoController,
                    Icons.attach_money,
                    tipo: const TextInputType.numberWithOptions(decimal: true),
                  ),
                  DropdownButtonFormField<String>(
                    initialValue: estado,
                    decoration: InputDecoration(
                      labelText: 'Estado',
                      prefixIcon: const Icon(Icons.info, color: verde),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    items: ['Activo', 'Pendiente', 'Finalizado']
                        .map(
                          (valor) => DropdownMenuItem(
                            value: valor,
                            child: Text(valor),
                          ),
                        )
                        .toList(),
                    onChanged: (valor) {
                      if (valor != null) {
                        setState(() => estado = valor);
                      }
                    },
                  ),
                  const SizedBox(height: 25),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: guardar,
                      icon: const Icon(Icons.save),
                      label: const Text('Guardar contrato'),
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
