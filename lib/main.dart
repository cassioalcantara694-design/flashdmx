import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:file_saver/file_saver.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';
import 'package:csv/csv.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() => runApp(const MaterialApp(debugShowCheckedModeBanner: false, home: PatchScreen()));

class PatchScreen extends StatefulWidget {
  const PatchScreen({super.key});
  @override
  State<PatchScreen> createState() => _PatchScreenState();
}

class _PatchScreenState extends State<PatchScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  int currentUniverse = 1;
  bool _mostrarFormulario = true;
  Map<int, List<Map<String, dynamic>>> patchesPorUniverso = {for (int i = 1; i <= 16; i++) i: []};
  Color _corSelecionada = Colors.white;

  final TextEditingController _nome = TextEditingController(text: "DIMMER");
  final TextEditingController _start = TextEditingController(text: "1");
  final TextEditingController _qty = TextEditingController(text: "10");
  final TextEditingController _off = TextEditingController(text: "1");
  final TextEditingController _id = TextEditingController(text: "1");

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 16, vsync: this);
    _carregarDados();
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        setState(() {
          currentUniverse = _tabController.index + 1;
        });
      }
    });
  }

  void _handleTabTap(int index) {
    if (index + 1 == currentUniverse) {
      setState(() => _mostrarFormulario = !_mostrarFormulario);
    } else {
      setState(() {
        currentUniverse = index + 1;
        _mostrarFormulario = true;
      });
    }
  }

  Future<void> _salvarDados() async {
    final prefs = await SharedPreferences.getInstance();
    String jsonString = jsonEncode(patchesPorUniverso.map((k, v) => MapEntry(k.toString(), v)));
    await prefs.setString('patch_data_v1', jsonString);
  }

  Future<void> _carregarDados() async {
    final prefs = await SharedPreferences.getInstance();
    String? jsonString = prefs.getString('patch_data_v1');
    if (jsonString != null) {
      Map<String, dynamic> decoded = jsonDecode(jsonString);
      setState(() {
        patchesPorUniverso = decoded.map((key, value) =>
            MapEntry(int.parse(key), List<Map<String, dynamic>>.from(value)));
      });
    }
  }

  void _showMsg(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: color));
  }

  void _executar() {
    int start = int.tryParse(_start.text) ?? 1;
    int qty = int.tryParse(_qty.text) ?? 0;
    int off = int.tryParse(_off.text) ?? 1;
    int fixtureId = int.tryParse(_id.text) ?? 1;

    setState(() {
      int adicionados = 0;
      for (int i = 0; i < qty; i++) {
        if (start > 512) {
          if (adicionados > 0) _showMsg("Limite de 512 atingido. Adicionados $adicionados.", Colors.orange);
          else _showMsg("Erro: Canal 512 excedido!", Colors.red);
          break;
        }
        patchesPorUniverso[currentUniverse]!.add({
          "nome": "${_nome.text} ID ${fixtureId + i}",
          "inicio": start,
          "cor": _corSelecionada.toARGB32()
        });
        start = (start + off);
        adicionados++;
      }
      _start.text = start.toString();
      _id.text = (fixtureId + adicionados).toString();
      _salvarDados();
    });
  }

  Future<void> _exportarPDF() async {
    try {
      final pdf = pw.Document();
      final font = await PdfGoogleFonts.nunitoRegular();
      final fontBold = await PdfGoogleFonts.nunitoBold();

      pdf.addPage(pw.MultiPage(
        theme: pw.ThemeData.withFont(base: font, bold: fontBold),
        build: (pw.Context context) => [
          pw.Header(level: 0, text: "Patch DMX - FLASHDMX"),
          ...patchesPorUniverso.entries.where((e) => e.value.isNotEmpty).expand((e) => [
            pw.Header(level: 1, text: "Universo ${e.key}", textStyle: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
            pw.TableHelper.fromTextArray(
              context: context,
              headers: ['Equipamento', 'Endereço DMX'],
              data: e.value.map((item) => [item['nome'], "CH: ${item['inicio']}"]).toList(),
              border: pw.TableBorder.all(),
              headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white),
              headerDecoration: pw.BoxDecoration(color: PdfColors.grey700),
              cellAlignment: pw.Alignment.centerLeft,
              cellStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 20),
          ]).toList()
        ]
      ));
      await Printing.layoutPdf(onLayout: (format) => pdf.save());
    } catch (e) {
      _showMsg("Erro ao gerar PDF.", Colors.red);
    }
  }

  Future<void> _exportarCSV() async {
    List<List<dynamic>> rows = [["Layer", "Fix ID", "Ch ID", "Name", "FixtureType", "Patch", "Color"]];
    int contador = 1;
    patchesPorUniverso.forEach((universo, lista) {
      for (var item in lista) {
        String patchMA2 = "${universo}.${item['inicio'].toString().padLeft(3, '0')}";
        rows.add(["Patch", contador, contador, item['nome'], "Generic", patchMA2, "white"]);
        contador++;
      }
    });
    String csv = const ListToCsvConverter(fieldDelimiter: ';').convert(rows);
    await FileSaver.instance.saveFile(name: "patch_ma2.csv", bytes: Uint8List.fromList(csv.codeUnits), ext: "csv", mimeType: MimeType.csv);
  }

  InputDecoration _inputStyle(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: Colors.grey, fontSize: 13),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Colors.white24)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Colors.blueAccent)),
    );
  }

  Widget _seletorNumerico(TextEditingController controller, String label) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12)),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.white24),
          ),
          child: Row(
            children: [
              IconButton(
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                icon: const Icon(Icons.remove_circle_outline, color: Colors.blueAccent, size: 22),
                onPressed: () {
                  int val = int.tryParse(controller.text) ?? 0;
                  if (val > 0) controller.text = (val - 1).toString();
                },
              ),
              Expanded(
                child: TextField(
                  controller: controller,
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
                  decoration: const InputDecoration(
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(vertical: 8),
                    border: InputBorder.none,
                  ),
                ),
              ),
              IconButton(
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                icon: const Icon(Icons.add_circle_outline, color: Colors.blueAccent, size: 22),
                onPressed: () {
                  int val = int.tryParse(controller.text) ?? 0;
                  controller.text = (val + 1).toString();
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
          title: const Text("FLASHDMX", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
          backgroundColor: const Color(0xFF0D0D0D),
          elevation: 0,
          actions: [
            IconButton(icon: const Icon(Icons.picture_as_pdf, color: Colors.white, size: 20), onPressed: _exportarPDF),
            IconButton(icon: const Icon(Icons.table_chart, color: Colors.white, size: 20), onPressed: _exportarCSV),
          ],
          bottom: TabBar(
              controller: _tabController, isScrollable: true, labelColor: Colors.blueAccent, unselectedLabelColor: Colors.grey,
              indicatorColor: Colors.blueAccent,
              onTap: _handleTabTap,
              tabs: List.generate(16, (i) => Tab(text: "U${i + 1}"))
          )
      ),
      body: Stack(
        children: [
          // Área de Formulário
          if (_mostrarFormulario)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: Column(children: [
                Row(children: [
                  Expanded(child: TextField(controller: _nome, style: const TextStyle(color: Colors.white), decoration: _inputStyle("Aparelho"))),
                  const SizedBox(width: 15),
                  GestureDetector(
                    onTap: () => showDialog(context: context, builder: (c) => AlertDialog(backgroundColor: Colors.grey[900], title: const Text("Cor", style: TextStyle(color: Colors.white)), content: Wrap(spacing: 10, runSpacing: 10, children: [Colors.red, Colors.blue, Colors.green, Colors.yellow, Colors.white, Colors.purple, Colors.orange, Colors.cyan].map((c) => IconButton(icon: Icon(Icons.circle, color: c, size: 45), onPressed: () { setState(() => _corSelecionada = c); Navigator.pop(context); })).toList()))),
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(color: Colors.white10, shape: BoxShape.circle, border: Border.all(color: _corSelecionada, width: 2)),
                      child: CircleAvatar(backgroundColor: _corSelecionada, radius: 18),
                    ),
                  )
                ]),
                const SizedBox(height: 15),
                Row(children: [
                  Expanded(child: _seletorNumerico(_start, "End. Inicial")),
                  const SizedBox(width: 30),
                  Expanded(child: _seletorNumerico(_id, "ID Inicial")),
                ]),
                const SizedBox(height: 15),
                Row(children: [
                  Expanded(child: _seletorNumerico(_qty, "Quantidade")),
                  const SizedBox(width: 30),
                  Expanded(child: _seletorNumerico(_off, "Offset")),
                ]),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                    onPressed: _executar, 
                    child: const Text("ADICIONAR APARELHOS", style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold))
                  ),
                ),
                const SizedBox(height: 15),
                Center(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      setState(() => patchesPorUniverso[currentUniverse]!.clear());
                      _salvarDados();
                    },
                    icon: const Icon(Icons.delete_sweep, color: Colors.redAccent, size: 18),
                    label: const Text("LIMPAR UNIVERSO ATUAL", style: TextStyle(color: Colors.redAccent, fontSize: 12, fontWeight: FontWeight.bold)),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.redAccent, width: 1),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    ),
                  ),
                )
              ]),
            ),

          // Lista Deslizante (Draggable Sheet)
          DraggableScrollableSheet(
            initialChildSize: _mostrarFormulario ? 0.45 : 0.9,
            minChildSize: 0.15,
            maxChildSize: 0.95,
            builder: (context, scrollController) {
              return Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF111111),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(25)),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.8), blurRadius: 20, spreadRadius: 5)],
                ),
                child: Column(children: [
                  const SizedBox(height: 10),
                  Container(width: 45, height: 4, decoration: BoxDecoration(color: Colors.grey[800], borderRadius: BorderRadius.circular(10))),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Text("PATCH - U$currentUniverse", style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
                  ),
                  Expanded(
                    child: ListView.builder(
                        controller: scrollController,
                        padding: const EdgeInsets.fromLTRB(10, 0, 10, 30),
                        itemCount: patchesPorUniverso[currentUniverse]!.length,
                        itemBuilder: (context, i) {
                          final item = patchesPorUniverso[currentUniverse]![i];
                          String endStr = item['inicio'].toString().padLeft(3, '0');
                          return Container(
                            margin: const EdgeInsets.only(bottom: 4),
                            decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), borderRadius: BorderRadius.circular(8)),
                            child: ListTile(
                              dense: true,
                              visualDensity: const VisualDensity(vertical: -4),
                              leading: CircleAvatar(backgroundColor: Color(item['cor']), radius: 4),
                              title: Text("${item['nome']} - CH $endStr", style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500)),
                              trailing: IconButton(
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                                icon: const Icon(Icons.close, color: Colors.white24, size: 16), 
                                onPressed: () {
                                  setState(() => patchesPorUniverso[currentUniverse]!.removeAt(i));
                                  _salvarDados();
                                }
                              ),
                            ),
                          );
                        }
                    ),
                  ),
                ]),
              );
            },
          ),
        ],
      ),
    );
  }
}