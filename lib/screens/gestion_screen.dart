import 'package:flutter/material.dart';

import 'usuarios/lista_usuarios.dart';
import 'contratos/lista_contratos.dart';

class GestionScreen extends StatelessWidget {
  const GestionScreen({super.key});

  static const Color verde = Color(0xFF20794D);
  static const Color naranja = Color(0xFFF28C38);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F8F4),
      appBar: AppBar(
        title: const Text('Panel de gestión'),
        backgroundColor: verde,
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text(
            'Administración',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: verde,
            ),
          ),
          const SizedBox(height: 5),
          const Text(
            'Gestiona usuarios y contratos',
            style: TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 25),
          crearCard(
            context,
            titulo: 'Usuarios',
            descripcion: 'Gestiona los usuarios registrados.',
            icono: Icons.people_alt_rounded,
            colorIcono: verde,
            destino: const ListaUsuariosScreen(),
          ),
          const SizedBox(height: 20),
          crearCard(
            context,
            titulo: 'Contratos',
            descripcion: 'Consulta y administra contratos.',
            icono: Icons.description_rounded,
            colorIcono: naranja,
            destino: const ListaContratosScreen(),
          ),
        ],
      ),
    );
  }

  Widget crearCard(
    BuildContext context, {
    required String titulo,
    required String descripcion,
    required IconData icono,
    required Color colorIcono,
    required Widget destino,
  }) {
    return Card(
      elevation: 3,
      color: Colors.white,
      shadowColor: Colors.black12,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: colorIcono.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icono, size: 30, color: colorIcono),
                ),
                const SizedBox(width: 15),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        titulo,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: verde,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        descripcion,
                        style: const TextStyle(
                          fontSize: 13,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 22),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => destino),
                  );
                },
                icon: const Icon(Icons.list),
                label: Text('Ver ${titulo.toLowerCase()}'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: verde,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
