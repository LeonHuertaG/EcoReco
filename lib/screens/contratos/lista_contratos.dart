import 'package:flutter/material.dart';

import '../../ui/eco_theme.dart';

import 'formulario_contratos.dart';

class ListaContratosScreen extends StatefulWidget {
  const ListaContratosScreen({super.key});

  @override
  State<ListaContratosScreen> createState() => _ListaContratosScreenState();
}

class _ListaContratosScreenState extends State<ListaContratosScreen> {
  static const Color naranja = ecoOrange;

  final List<Map<String, String>> contratos = [
    {
      'folio': 'CONT-001',
      'usuario': 'Juan Pérez',
      'inicio': '2026-10-01',
      'fin': '2027-10-01',
      'monto': '1500',
      'estado': 'Activo',
    },
    {
      'folio': 'CONT-002',
      'usuario': 'María López',
      'inicio': '2026-09-01',
      'fin': '2027-09-01',
      'monto': '2500',
      'estado': 'Pendiente',
    },
  ];

  Future<void> abrirFormulario({int? indice}) async {
    final resultado = await Navigator.push<Map<String, String>>(
      context,
      MaterialPageRoute(
        builder: (_) => FormularioContratoScreen(
          contrato: indice == null ? null : contratos[indice],
        ),
      ),
    );

    if (!mounted || resultado == null) return;

    setState(() {
      if (indice == null) {
        contratos.add(resultado);
      } else {
        contratos[indice] = resultado;
      }
    });
  }

  Future<void> eliminarContrato(int indice) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Eliminar contrato'),
        content: Text('¿Eliminar el contrato ${contratos[indice]['folio']}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text(
              'Eliminar',
              style: TextStyle(color: Color(0xFF9E2724)),
            ),
          ),
        ],
      ),
    );

    if (!mounted || confirmar != true) return;

    setState(() {
      contratos.removeAt(indice);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Contratos')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => abrirFormulario(),
        backgroundColor: naranja,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Agregar contrato'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Lista de contratos',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: naranja,
              ),
            ),
            const SizedBox(height: 20),
            Expanded(
              child: contratos.isEmpty
                  ? const Center(child: Text('No hay contratos registrados'))
                  : ListView.builder(
                      itemCount: contratos.length,
                      itemBuilder: (context, index) {
                        final contrato = contratos[index];

                        return Card(
                          color: Colors.white,
                          margin: const EdgeInsets.only(bottom: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const EcoIcon(Icons.description_outlined),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        contrato['folio'] ?? '',
                                        style: const TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                    IconButton(
                                      tooltip: 'Editar',
                                      icon: const Icon(
                                        Icons.edit,
                                        color: naranja,
                                      ),
                                      onPressed: () =>
                                          abrirFormulario(indice: index),
                                    ),
                                    IconButton(
                                      tooltip: 'Eliminar',
                                      icon: const Icon(
                                        Icons.delete,
                                        color: Color(0xFF9E2724),
                                      ),
                                      onPressed: () => eliminarContrato(index),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                EcoField(
                                  Icons.person_outline,
                                  'Usuario',
                                  '${contrato['usuario']}',
                                ),
                                EcoField(
                                  Icons.event_outlined,
                                  'Inicio',
                                  '${contrato['inicio']}',
                                ),
                                EcoField(
                                  Icons.event_busy_outlined,
                                  'Vencimiento',
                                  '${contrato['fin']}',
                                ),
                                EcoField(
                                  Icons.payments_outlined,
                                  'Monto',
                                  '\$${contrato['monto']}',
                                ),
                                const SizedBox(height: 8),
                                Chip(
                                  label: Text(contrato['estado'] ?? ''),
                                  backgroundColor: const Color(0xFFE2F3E9),
                                  labelStyle: const TextStyle(color: naranja),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
