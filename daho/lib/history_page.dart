import 'package:flutter/material.dart';

class HistoryPage extends StatelessWidget {
  const HistoryPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('History'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: const [
          ListTile(
            leading: Icon(Icons.history),
            title: Text('#ORD-004'),
            subtitle: Text('Picked up — Gourmet Coffee'),
          ),
          Divider(),
          ListTile(
            leading: Icon(Icons.history),
            title: Text('#ORD-003'),
            subtitle: Text('Delivered — Mango Piaya'),
          ),
        ],
      ),
    );
  }
}
