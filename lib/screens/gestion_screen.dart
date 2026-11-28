import 'package:flutter/material.dart';

import '../ui/eco_theme.dart';

import 'usuarios/lista_usuarios.dart';
import 'contratos/lista_contratos.dart';

class GestionScreen extends StatelessWidget {
  const GestionScreen({super.key});

  static const Color naranja = ecoOrange;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Panel de gestión')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const EcoBanner(
            title: 'Administración',
            subtitle: 'Usuarios y contratos',
            icon: Icons.admin_panel_settings_outlined,
          ),
          const SizedBox(height: 16),
          crearCard(
            context,
            titulo: 'Usuarios',
            descripcion: 'Gestiona los usuarios registrados.',
            icono: Icons.people_alt_rounded,
            colorIcono: naranja,
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
                          color: naranja,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        descripcion,
                        style: const TextStyle(
                          fontSize: 13,
                          color: Color(0xFF42534B),
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
                  backgroundColor: naranja,
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
