import 'dart:convert';
import 'dart:async';
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
  final DraggableScrollableController _sheetController = DraggableScrollableController();
  int currentUniverse = 1;
  bool _mostrarFormulario = true;
  Map<int, List<Map<String, dynamic>>> patchesPorUniverso = {for (int i = 1; i <= 16; i++) i: []};
  Color _corSelecionada = Colors.white;

  final TextEditingController _nome = TextEditingController(text: "DIMMER");
  final TextEditingController _start = TextEditingController(text: "1");
  final TextEditingController _qty = TextEditingController(text: "10");
  final TextEditingController _off = TextEditingController(text: "1");
  final TextEditingController _id = TextEditingController(text: "1");

  static const List<String> _opcoesNomes = [
    "ATOMIC_RGB", "BEAM", "BLINDER", "BL_RGBW", "BRUT", "BRUT_LED",
    "CITY_COLOR", "COB_200", "COB_300", "DIMMER", "FOG", "FRESNEL",
    "HAZE", "LASER", "LED_BAR", "MATRIX", "MINIBEAM", "MOONFLOWER",
    "MOVER", "P_5", "PAR_LED", "PIXEL_BAR", "RIBALTA", "RIBALTA_TILT",
    "SCANNER", "SMOKE_MACHINE", "SPIIDER", "SPOT", "SPOT_400", "SPOT_700",
    "STROBE", "SUNSTRIP", "WASH"
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 16, vsync: this);
    _carregarDados();
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        setState(() => currentUniverse = _tabController.index + 1);
      }
    });
  }

  void _handleTabTap(int index) {
    FocusScope.of(context).unfocus();
    if (index + 1 == currentUniverse) {
      setState(() => _mostrarFormulario = !_mostrarFormulario);
    } else {
      setState(() {
        currentUniverse = index + 1;
        _mostrarFormulario = true;
      });
    }
    
    // Anima a lista para cima se o formulário for escondido e houver itens
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_mostrarFormulario && patchesPorUniverso[currentUniverse]!.isNotEmpty) {
        _sheetController.animateTo(0.9, duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
      } else if (_mostrarFormulario) {
        _sheetController.animateTo(0.4, duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
      }
    });
  }

  Future<void> _salvarDados() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('patch_data_v1', jsonEncode(patchesPorUniverso.map((k, v) => MapEntry(k.toString(), v))));
  }

  Future<void> _carregarDados() async {
    final prefs = await SharedPreferences.getInstance();
    String? data = prefs.getString('patch_data_v1');
    if (data != null) {
      Map<String, dynamic> decoded = jsonDecode(data);
      setState(() => patchesPorUniverso = decoded.map((k, v) => MapEntry(int.parse(k), List<Map<String, dynamic>>.from(v))));
    }
  }

  void _showMsg(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: color, duration: const Duration(seconds: 2)));
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
          _showMsg("Limite de 512 atingido. Adicionados $adicionados.", Colors.orange);
          break;
        }
        
        bool sobreposto = patchesPorUniverso[currentUniverse]!.any((e) {
          int eStart = e['inicio'];
          return start == eStart; 
        });

        if (sobreposto) {
          _showMsg("Aviso: Canal $start já ocupado!", Colors.redAccent);
        }

        patchesPorUniverso[currentUniverse]!.add({
          "nome": "${_nome.text.toUpperCase()} ID ${fixtureId + i}",
          "inicio": start,
          "cor": _corSelecionada.toARGB32()
        });
        start += off;
        adicionados++;
      }
      _start.text = start.toString();
      _id.text = (fixtureId + adicionados).toString();
      _salvarDados();
    });
  }

  void _confirmarLimparTudo() {
    showDialog(
      context: context,
      builder: (c) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: const Text("Limpar Tudo?", style: TextStyle(color: Colors.white)),
        content: const Text("Isso apagará o patch de TODOS os 16 universos. Tem certeza?", style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: const Text("CANCELAR")),
          TextButton(
            onPressed: () {
              setState(() {
                for (int i = 1; i <= 16; i++) patchesPorUniverso[i] = [];
              });
              _salvarDados();
              _showMsg("Todos os universos foram limpos!", Colors.red);
              Navigator.pop(c);
            }, 
            child: const Text("LIMPAR TUDO", style: TextStyle(color: Colors.red))
          ),
        ],
      )
    );
  }

  Future<void> _exportarPDF() async {
    String evento = "FLASHDMX";
    TextEditingController eventCtrl = TextEditingController(text: "MEU EVENTO");
    
    await showDialog(
      context: context,
      builder: (c) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: const Text("Nome do Evento", style: TextStyle(color: Colors.white)),
        content: TextField(controller: eventCtrl, style: const TextStyle(color: Colors.white), decoration: _inputStyle("Ex: Festival de Verão")),
        actions: [TextButton(onPressed: () => Navigator.pop(c), child: const Text("GERAR"))],
      )
    );
    evento = eventCtrl.text;

    try {
      final pdf = pw.Document();
      final font = await PdfGoogleFonts.nunitoRegular();
      final fontBold = await PdfGoogleFonts.nunitoBold();

      for (var entry in patchesPorUniverso.entries.where((e) => e.value.isNotEmpty)) {
        Map<String, List<Map<String, dynamic>>> agrupados = {};
        for (var item in entry.value) {
          String base = item['nome'].contains(" ID ") ? item['nome'].split(" ID ")[0] : item['nome'];
          agrupados.putIfAbsent(base, () => []).add(item);
        }

        pdf.addPage(pw.MultiPage(
          theme: pw.ThemeData.withFont(base: font, bold: fontBold),
          header: (context) => pw.Header(level: 0, text: "Patch DMX - $evento"),
          build: (pw.Context context) => [
            pw.Header(level: 1, text: "Universo ${entry.key}", textStyle: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
            ...agrupados.entries.expand((grupo) => [
              pw.Padding(padding: const pw.EdgeInsets.only(top: 10, bottom: 5), child: pw.Text(grupo.key, style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold))),
              pw.TableHelper.fromTextArray(
                context: context,
                headers: ['Equipamento', 'ID', 'Endereço DMX'],
                data: grupo.value.map((item) {
                  String nome = item['nome'];
                  String base = nome.contains(" ID ") ? nome.split(" ID ")[0] : nome;
                  String id = nome.contains(" ID ") ? nome.split(" ID ")[1] : "-";
                  return [base, id, "CH: ${item['inicio']}"];
                }).toList(),
                border: pw.TableBorder.all(),
                headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white),
                headerDecoration: const pw.BoxDecoration(color: PdfColors.grey700),
                cellStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                columnWidths: {
                  0: const pw.FlexColumnWidth(3),
                  1: const pw.FlexColumnWidth(1),
                  2: const pw.FlexColumnWidth(2),
                },
              ),
              pw.SizedBox(height: 10),
            ]).toList()
          ]
        ));
      }
      await Printing.layoutPdf(onLayout: (format) => pdf.save());
    } catch (e) { _showMsg("Erro ao gerar PDF.", Colors.red); }
  }

  Future<void> _exportarCSV() async {
    List<List<dynamic>> rows = [["Layer", "Fix ID", "Ch ID", "Name", "FixtureType", "Patch", "Color"]];
    int contador = 1;
    patchesPorUniverso.forEach((universo, lista) {
      for (var item in lista) {
        rows.add(["Patch", contador, contador, item['nome'], "Generic", "$universo.${item['inicio'].toString().padLeft(3, '0')}", "white"]);
        contador++;
      }
    });
    String csv = const ListToCsvConverter(fieldDelimiter: ';').convert(rows);
    await FileSaver.instance.saveFile(name: "patch_flashdmx.csv", bytes: utf8.encode(csv), ext: "csv", mimeType: MimeType.csv);
  }

  InputDecoration _inputStyle(String label) => InputDecoration(
    labelText: label, labelStyle: const TextStyle(color: Colors.grey, fontSize: 13),
    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.white24)),
    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.blueAccent, width: 2)),
  );

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
            title: const Text("FLASHDMX", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 20)),
            backgroundColor: const Color(0xFF0D0D0D),
            elevation: 0,
            actions: [
              _actionBtn(Icons.exit_to_app, "IMPORTAR", () {}),
              _actionBtn(Icons.picture_as_pdf, "PDF", _exportarPDF),
              _actionBtn(Icons.table_chart, "CSV", _exportarCSV),
              _actionBtn(Icons.more_horiz, "MAIS", () {}),
              const SizedBox(width: 10),
            ],
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(60),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: TabBar(
                  controller: _tabController, isScrollable: true, onTap: _handleTabTap,
                  indicator: BoxDecoration(borderRadius: BorderRadius.circular(10), color: Colors.blueAccent),
                  indicatorSize: TabBarIndicatorSize.tab, labelColor: Colors.white, unselectedLabelColor: Colors.grey,
                  dividerColor: Colors.transparent,
                  tabs: List.generate(16, (i) => Tab(child: Text("U${i + 1}", style: const TextStyle(fontWeight: FontWeight.bold)))),
                ),
              ),
            )
        ),
        body: Stack(
          children: [
            if (_mostrarFormulario)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                child: SingleChildScrollView(
                  child: Column(children: [
                    Row(children: [
                      Expanded(child: Autocomplete<String>(
                        optionsBuilder: (val) => val.text.isEmpty ? _opcoesNomes : _opcoesNomes.where((opt) => opt.contains(val.text.toUpperCase())),
                        onSelected: (sel) => _nome.text = sel,
                        fieldViewBuilder: (ctx, ctrl, fn, sub) {
                          if (ctrl.text.isEmpty) ctrl.text = _nome.text;
                          ctrl.addListener(() => _nome.text = ctrl.text.toUpperCase());
                          return TextField(controller: ctrl, focusNode: fn, style: const TextStyle(color: Colors.white), decoration: _inputStyle("Aparelho").copyWith(suffixIcon: const Icon(Icons.arrow_drop_down, color: Colors.grey)));
                        },
                      )),
                      const SizedBox(width: 15),
                      GestureDetector(
                        onTap: () => _escolherCor(),
                        child: CircleAvatar(
                          backgroundColor: _corSelecionada, 
                          radius: 22, 
                          child: Container(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle, 
                              border: Border.all(color: Colors.white24, width: 2)
                            )
                          )
                        ),
                      )
                    ]),
                    const SizedBox(height: 20),
                    Row(children: [
                      Expanded(child: _SeletorInteligente(controller: _start, label: "End. Inicial")),
                      const SizedBox(width: 20),
                      Expanded(child: _SeletorInteligente(controller: _id, label: "ID Inicial")),
                    ]),
                    const SizedBox(height: 20),
                    Row(children: [
                      Expanded(child: _SeletorInteligente(controller: _qty, label: "Quantidade")),
                      const SizedBox(width: 20),
                      Expanded(child: _SeletorInteligente(controller: _off, label: "Offset")),
                    ]),
                    const SizedBox(height: 30),
                    SizedBox(width: double.infinity, height: 55, child: ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))), onPressed: _executar, child: const Text("ADICIONAR APARELHOS", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)))),
                    const SizedBox(height: 15),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () { setState(() => patchesPorUniverso[currentUniverse]!.clear()); _salvarDados(); }, 
                            icon: const Icon(Icons.delete_sweep, color: Colors.redAccent, size: 18), 
                            label: Text("LIMPAR U$currentUniverse", style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold, fontSize: 11)),
                            style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.redAccent), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)))
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _confirmarLimparTudo, 
                            icon: const Icon(Icons.delete_forever, color: Colors.red, size: 18), 
                            label: const Text("LIMPAR TUDO", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 11)), 
                            style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.red), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)))
                          ),
                        ),
                      ],
                    ),
                  ]),
                ),
              ),

            DraggableScrollableSheet(
              controller: _sheetController,
              initialChildSize: _mostrarFormulario ? 0.40 : 0.9, 
              minChildSize: _mostrarFormulario ? 0.35 : 0.8, // Aumentado para não sumir no fundo
              maxChildSize: 0.95,
              builder: (context, scrollController) {
                final items = patchesPorUniverso[currentUniverse]!;
                Map<String, List<Map<String, dynamic>>> agrupados = {};
                for (var item in items) {
                  String base = item['nome'].contains(" ID ") ? item['nome'].split(" ID ")[0] : item['nome'];
                  agrupados.putIfAbsent(base, () => []).add(item);
                }
                return Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFF111111), 
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(30)), 
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.8), blurRadius: 20, spreadRadius: 5)]
                  ),
                  child: Column(children: [
                    const SizedBox(height: 12),
                    Container(width: 60, height: 5, decoration: BoxDecoration(color: Colors.grey[700], borderRadius: BorderRadius.circular(10))), // Alça maior
                    Padding(padding: const EdgeInsets.symmetric(vertical: 15), child: Text("PATCH - UNIVERSO $currentUniverse", style: const TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.bold, letterSpacing: 2))),
                    Expanded(child: ListView.builder(controller: scrollController, padding: const EdgeInsets.fromLTRB(15, 0, 15, 40), itemCount: agrupados.length, itemBuilder: (context, idx) {
                      String base = agrupados.keys.elementAt(idx);
                      List<Map<String, dynamic>> fixtures = agrupados[base]!;
                      return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Padding(padding: const EdgeInsets.only(top: 15, bottom: 8, left: 5), child: Text(base, style: TextStyle(color: Colors.blueAccent.withOpacity(0.8), fontSize: 12, fontWeight: FontWeight.bold))),
                        ...fixtures.map((item) => Container(margin: const EdgeInsets.only(bottom: 6), decoration: BoxDecoration(color: Colors.white.withOpacity(0.04), borderRadius: BorderRadius.circular(12), border: Border.symmetric(vertical: BorderSide(color: Color(item['cor']), width: 4))), child: ListTile(dense: true, title: Text("${item['nome']} - CH ${item['inicio'].toString().padLeft(3, '0')}", style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500)), trailing: IconButton(icon: const Icon(Icons.close, color: Colors.redAccent, size: 18), onPressed: () { setState(() => items.remove(item)); _salvarDados(); })))).toList()
                      ]);
                    })),
                  ]),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _actionBtn(IconData icon, String label, VoidCallback press) => InkWell(
    onTap: press,
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Column(mainAxisSize: MainAxisSize.min, children: [Icon(icon, color: Colors.white, size: 20), Text(label, style: const TextStyle(color: Colors.white70, fontSize: 8, fontWeight: FontWeight.bold))]),
    ),
  );

  void _escolherCor() => showDialog(context: context, builder: (c) => AlertDialog(backgroundColor: Colors.grey[900], title: const Text("Cor", style: TextStyle(color: Colors.white)), content: Wrap(spacing: 12, runSpacing: 12, children: [Colors.red, Colors.blue, Colors.green, Colors.yellow, Colors.white, Colors.purple, Colors.orange, Colors.cyan].map((c) => IconButton(icon: Icon(Icons.circle, color: c, size: 48), onPressed: () { setState(() => _corSelecionada = c); Navigator.pop(context); })).toList())));
}

class _SeletorInteligente extends StatefulWidget {
  final TextEditingController controller;
  final String label;
  const _SeletorInteligente({required this.controller, required this.label});
  @override
  State<_SeletorInteligente> createState() => _SeletorInteligenteState();
}

class _SeletorInteligenteState extends State<_SeletorInteligente> {
  Timer? _timer;
  void _update(int delta) {
    int val = int.tryParse(widget.controller.text) ?? 0;
    if (val + delta >= 0) widget.controller.text = (val + delta).toString();
  }
  void _startTimer(int delta) {
    _update(delta);
    _timer = Timer.periodic(const Duration(milliseconds: 100), (t) => _update(delta));
  }
  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(widget.label, style: const TextStyle(color: Colors.grey, fontSize: 12)),
      const SizedBox(height: 4),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.white24)),
        child: Row(children: [
          GestureDetector(onLongPressStart: (_) => _startTimer(-1), onLongPressEnd: (_) => _timer?.cancel(), child: IconButton(icon: const Icon(Icons.remove_circle_outline, color: Colors.blueAccent), onPressed: () => _update(-1))),
          Expanded(child: TextField(controller: widget.controller, keyboardType: TextInputType.number, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold), decoration: const InputDecoration(isDense: true, border: InputBorder.none))),
          GestureDetector(onLongPressStart: (_) => _startTimer(1), onLongPressEnd: (_) => _timer?.cancel(), child: IconButton(icon: const Icon(Icons.add_circle_outline, color: Colors.blueAccent), onPressed: () => _update(1))),
        ]),
      ),
    ]);
  }
}
