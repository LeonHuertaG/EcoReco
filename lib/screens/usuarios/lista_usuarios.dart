import 'package:flutter/material.dart';

import 'formulario_usuario.dart';

class ListaUsuariosScreen extends StatefulWidget {
  const ListaUsuariosScreen({super.key});

  @override
  State<ListaUsuariosScreen> createState() => _ListaUsuariosScreenState();
}

class _ListaUsuariosScreenState extends State<ListaUsuariosScreen> {
  static const Color verde = Color(0xFF20794D);
  static const Color naranja = Color(0xFFF28C38);

  final List<Map<String, String>> usuarios = [
    {
      'nombre': 'Juan Pérez',
      'correo': 'juan@ejemplo.com',
      'telefono': '4421234567',
      'direccion': 'Querétaro',
    },
    {
      'nombre': 'María López',
      'correo': 'maria@ejemplo.com',
      'telefono': '4429876543',
      'direccion': 'Centro',
    },
  ];

  Future<void> abrirFormulario({int? indice}) async {
    final resultado = await Navigator.push<Map<String, String>>(
      context,
      MaterialPageRoute(
        builder: (_) => FormularioUsuarioScreen(
          usuario: indice == null ? null : usuarios[indice],
        ),
      ),
    );

    if (!mounted || resultado == null) return;

    setState(() {
      if (indice == null) {
        usuarios.add(resultado);
      } else {
        usuarios[indice] = resultado;
      }
    });
  }

  Future<void> eliminarUsuario(int indice) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Eliminar usuario'),
        content: Text('¿Deseas eliminar a ${usuarios[indice]['nombre']}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Eliminar', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (!mounted || confirmar != true) return;

    setState(() {
      usuarios.removeAt(indice);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F8F4),
      appBar: AppBar(
        title: const Text('Usuarios'),
        backgroundColor: verde,
        foregroundColor: Colors.white,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => abrirFormulario(),
        backgroundColor: naranja,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Agregar usuario'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Lista de usuarios',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: verde,
              ),
            ),
            const SizedBox(height: 20),
            Expanded(
              child: usuarios.isEmpty
                  ? const Center(child: Text('No hay usuarios registrados'))
                  : ListView.builder(
                      itemCount: usuarios.length,
                      itemBuilder: (context, index) {
                        final usuario = usuarios[index];

                        return Card(
                          color: Colors.white,
                          margin: const EdgeInsets.only(bottom: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: ListTile(
                            contentPadding: const EdgeInsets.all(12),
                            leading: const CircleAvatar(
                              backgroundColor: Color(0xFFE2F3E9),
                              child: Icon(Icons.person, color: verde),
                            ),
                            title: Text(
                              usuario['nombre'] ?? '',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            subtitle: Text(
                              '${usuario['correo']}\n'
                              '${usuario['telefono']}',
                            ),
                            isThreeLine: true,
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  tooltip: 'Editar',
                                  icon: const Icon(Icons.edit, color: naranja),
                                  onPressed: () =>
                                      abrirFormulario(indice: index),
                                ),
                                IconButton(
                                  tooltip: 'Eliminar',
                                  icon: const Icon(
                                    Icons.delete,
                                    color: Colors.red,
                                  ),
                                  onPressed: () => eliminarUsuario(index),
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
