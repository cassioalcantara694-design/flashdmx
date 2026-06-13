import 'package:flutter/material.dart';

void main() {
  runApp(const MaterialApp(home: PatchScreen()));
}

class PatchScreen extends StatefulWidget {
  const PatchScreen({super.key});
  @override
  State<PatchScreen> createState() => _PatchScreenState();
}

class _PatchScreenState extends State<PatchScreen> {
  // Esta lista armazena seus aparelhos
  List<Map<String, dynamic>> aparelhos = [];
  
  final TextEditingController _start = TextEditingController(text: "1");
  final TextEditingController _qty = TextEditingController(text: "10");
  final TextEditingController _chs = TextEditingController(text: "16");
  final TextEditingController _off = TextEditingController(text: "24");

  void _executarPatch() {
    int start = int.tryParse(_start.text) ?? 1;
    int qty = int.tryParse(_qty.text) ?? 1;
    int chs = int.tryParse(_chs.text) ?? 16;
    int off = int.tryParse(_off.text) ?? 24;
    int step = chs > off ? chs : off;

    setState(() {
      for (int i = 0; i < qty; i++) {
        aparelhos.add({
          "nome": "BEAM #${aparelhos.length + 1}",
          "inicio": start,
          "fim": start + chs - 1
        });
        start += step;
      }
      _start.text = start.toString();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Row(
        children: [
          // Painel Lateral de Controle
          Container(
            width: 300, 
            color: Colors.grey[900], 
            padding: const EdgeInsets.all(20), 
            child: Column(children: [
              TextField(controller: _start, decoration: const InputDecoration(labelText: "Endereço Inicial", labelStyle: TextStyle(color: Colors.white))),
              TextField(controller: _qty, decoration: const InputDecoration(labelText: "Quantidade", labelStyle: TextStyle(color: Colors.white))),
              TextField(controller: _chs, decoration: const InputDecoration(labelText: "Canais", labelStyle: TextStyle(color: Colors.white))),
              TextField(controller: _off, decoration: const InputDecoration(labelText: "Offset", labelStyle: TextStyle(color: Colors.white))),
              const SizedBox(height: 20),
              ElevatedButton(onPressed: _executarPatch, child: const Text("Executar Patch")),
              ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: Colors.red), onPressed: () => setState(() => aparelhos.clear()), child: const Text("Limpar Lista")),
            ])
          ),
          // Lista de Aparelhos (Onde os dados aparecem)
          Expanded(
            child: aparelhos.isEmpty 
              ? const Center(child: Text("Nenhum aparelho patchado.", style: TextStyle(color: Colors.white54)))
              : ListView.builder(
                  itemCount: aparelhos.length,
                  itemBuilder: (context, i) => Card(
                    color: const Color(0xFF161616),
                    child: ListTile(
                      leading: Text("${aparelhos[i]['inicio']} - ${aparelhos[i]['fim']}", style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.bold)),
                      title: Text(aparelhos[i]['nome'], style: const TextStyle(color: Colors.white)),
                      trailing: IconButton(icon: const Icon(Icons.delete, color: Colors.red), onPressed: () => setState(() => aparelhos.removeAt(i))),
                    ),
                  ),
                ),
          )
        ],
      ),
    );
  }
}