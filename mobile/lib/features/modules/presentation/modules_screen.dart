import 'package:flutter/material.dart';
import '../module_catalog.dart';

class ModulesScreen extends StatelessWidget {
  const ModulesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('VoltMap Modules')),
      body: ListView.builder(
        itemCount: moduleCatalog.length,
        itemBuilder: (context, index) => ListTile(
          leading: CircleAvatar(child: Text('${index + 1}')),
          title: Text(moduleCatalog[index]),
          subtitle: const Text('Foundation registered; external integration may still be required.'),
        ),
      ),
    );
  }
}
