import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:file_saver/file_saver.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

void main() => runApp(const MaterialApp(debugShowCheckedModeBanner: false, home: PatchScreen()));

class PatchScreen extends StatefulWidget {
  const PatchScreen({super.key});
  @override
  State<PatchScreen> createState() => _PatchScreenState();
}

class _PatchScreenState extends State<PatchScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  int currentUniverse = 1;
  bool _mostrarPainel = true; // Interruptor para esconder/mostrar o painel
  Map<int, List<Map<String, dynamic>>> patchesPorUniverso = {for (int i = 1; i <= 16; i++) i: []};
  Color _corSelecionada = Colors.white;

  final TextEditingController _nome = TextEditingController(text: "BEAM");
  final TextEditingController _start = TextEditingController(text: "1");
  final TextEditingController _qty = TextEditingController(text: "10");
  final TextEditingController _off = TextEditingController(text: "24");
  
  final int canaisPorAparelho = 20;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 16, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        setState(() {
          currentUniverse = _tabController.index + 1;
          _mostrarPainel = true; 
        });
      }
    });
  }

  void _handleTabTap(int index) {
    if (index + 1 == currentUniverse) {
      setState(() => _mostrarPainel = !_mostrarPainel);
    }
  }

  void _showMsg(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: color));
  }

  void _executar() {
    int start = int.tryParse(_start.text) ?? 1;
    int qty = int.tryParse(_qty.text) ?? 0;
    int off = int.tryParse(_off.text) ?? 0;

    setState(() {
      for (int i = 0; i < qty; i++) {
        if ((start + canaisPorAparelho - 1) > 512) {
          _showMsg("Erro: Aparelho passaria de 512!", Colors.red);
          break;
        }
        patchesPorUniverso[currentUniverse]!.add({
          "nome": "${_nome.text} #${patchesPorUniverso[currentUniverse]!.length + 1}",
          "inicio": start,
          "cor": _corSelecionada.toARGB32()
        });
        start = (start + off).toInt();
      }
      _start.text = start.toString();
    });
  }

  Future<void> _exportarPDF() async {
    final pdf = pw.Document();
    pdf.addPage(pw.MultiPage(build: (pw.Context context) => [
      pw.Header(level: 0, text: "Patch DMX"),
      ...patchesPorUniverso.entries.where((e) => e.value.isNotEmpty).map((e) => pw.Column(children: [
        pw.Header(level: 1, text: "Universo ${e.key}"),
        ...e.value.map((item) => pw.Text("${item['nome']} - CH: ${item['inicio']}"))
      ]))
    ]));
    await Printing.layoutPdf(onLayout: (format) => pdf.save());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text("FLASHDMX", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)), 
        backgroundColor: Colors.grey[900],
        actions: [
          IconButton(icon: const Icon(Icons.picture_as_pdf, color: Colors.white), onPressed: _exportarPDF),
          IconButton(icon: const Icon(Icons.download, color: Colors.white), onPressed: () => FileSaver.instance.saveFile(name: "patch", bytes: Uint8List.fromList(utf8.encode(jsonEncode(patchesPorUniverso))), ext: "json", mimeType: MimeType.json)),
        ],
        bottom: TabBar(
          controller: _tabController, isScrollable: true, labelColor: Colors.white, unselectedLabelColor: Colors.grey,
          onTap: _handleTabTap,
          tabs: List.generate(16, (i) {
            bool temPatch = patchesPorUniverso[i + 1]!.isNotEmpty;
            return Tab(child: Text("U${i + 1}", style: TextStyle(fontWeight: temPatch ? FontWeight.bold : FontWeight.normal)));
          })
        )
      ),
      body: LayoutBuilder(builder: (context, constraints) {
        bool isMobile = constraints.maxWidth < 600;
        
        Widget painelControle = Container(
          width: isMobile ? double.infinity : 300,
          color: Colors.grey[900],
          padding: const EdgeInsets.all(15),
          child: SingleChildScrollView(
            child: Column(
              children: [
                TextField(controller: _nome, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: "Nome", labelStyle: TextStyle(color: Colors.white))),
                TextField(controller: _start, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: "End. Inicial", labelStyle: TextStyle(color: Colors.white))),
                TextField(controller: _qty, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: "Qtd", labelStyle: TextStyle(color: Colors.white))),
                TextField(controller: _off, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: "Offset", labelStyle: TextStyle(color: Colors.white))),
                ListTile(
                  title: const Text("Cor", style: TextStyle(color: Colors.white)), 
                  trailing: CircleAvatar(backgroundColor: _corSelecionada), 
                  onTap: () => showDialog(context: context, builder: (c) => AlertDialog(content: Wrap(children: [Colors.red, Colors.blue, Colors.green, Colors.yellow, Colors.white].map((c) => IconButton(icon: Icon(Icons.circle, color: c, size: 40), onPressed: () { setState(() => _corSelecionada = c); Navigator.pop(context); })).toList())))),
                const SizedBox(height: 10),
                SizedBox(width: double.infinity, child: ElevatedButton(onPressed: _executar, child: const Text("ADICIONAR"))),
                TextButton(onPressed: () => setState(() => patchesPorUniverso[currentUniverse]!.clear()), child: const Text("LIMPAR UNIVERSO", style: TextStyle(color: Colors.red)))
              ],
            ),
          ),
        );

        Widget listaPatches = Expanded(
          child: ListView.builder(
            key: ValueKey(currentUniverse),
            itemCount: patchesPorUniverso[currentUniverse]!.length, 
            itemBuilder: (context, i) {
              final item = patchesPorUniverso[currentUniverse]![i];
              return Card(color: const Color(0xFF161616), child: ListTile(
                leading: CircleAvatar(backgroundColor: Color(item['cor']), radius: 10),
                title: Text(item['nome'], style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                subtitle: Text("CH-${item['inicio']}", style: const TextStyle(color: Colors.amber)),
                trailing: IconButton(icon: const Icon(Icons.delete, color: Colors.red), onPressed: () => setState(() => patchesPorUniverso[currentUniverse]!.removeAt(i))),
              ));
            }
          ),
        );

        Widget painelExibicao = _mostrarPainel ? painelControle : const SizedBox.shrink();
        return isMobile ? Column(children: [painelExibicao, listaPatches]) : Row(children: [painelExibicao, listaPatches]);
      }),
    );
  }
}