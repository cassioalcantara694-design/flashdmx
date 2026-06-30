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
          "nome": "${_nome.text.toUpperCase()} ID ${fixtureId + i}",
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
          ...patchesPorUniverso.entries.where((e) => e.value.isNotEmpty).expand((universoEntry) {
            final int universo = universoEntry.key;
            final List<Map<String, dynamic>> items = universoEntry.value;

            Map<String, List<Map<String, dynamic>>> agrupados = {};
            for (var item in items) {
              String nome = item['nome'] as String;
              String base = nome.contains(" ID ") ? nome.split(" ID ")[0] : nome;
              agrupados.putIfAbsent(base, () => []).add(item);
            }

            return [
              pw.Header(level: 1, text: "Universo $universo", textStyle: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
              ...agrupados.entries.expand((grupo) => [
                pw.Padding(
                  padding: const pw.EdgeInsets.only(top: 10, bottom: 5),
                  child: pw.Text(grupo.key, style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: PdfColors.blueGrey800)),
                ),
                pw.TableHelper.fromTextArray(
                  context: context,
                  headers: ['Equipamento', 'Endereço DMX'],
                  data: grupo.value.map((item) => [item['nome'], "CH: ${item['inicio']}"]).toList(),
                  border: pw.TableBorder.all(),
                  headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white),
                  headerDecoration: const pw.BoxDecoration(color: PdfColors.grey700),
                  cellAlignment: pw.Alignment.centerLeft,
                  cellStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                ),
              ]).toList(),
              pw.SizedBox(height: 20),
            ];
          }).toList()
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
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.white24)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.blueAccent, width: 2)),
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
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white24),
          ),
          child: Row(
            children: [
              IconButton(
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                icon: const Icon(Icons.remove_circle_outline, color: Colors.blueAccent, size: 24),
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
                  style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                  decoration: const InputDecoration(
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(vertical: 12),
                    border: InputBorder.none,
                  ),
                ),
              ),
              IconButton(
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                icon: const Icon(Icons.add_circle_outline, color: Colors.blueAccent, size: 24),
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
          title: const Text("FLASHDMX", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 20)),
          backgroundColor: const Color(0xFF0D0D0D),
          elevation: 0,
          actions: [
            IconButton(icon: const Icon(Icons.picture_as_pdf, color: Colors.white70), onPressed: _exportarPDF),
            IconButton(icon: const Icon(Icons.table_chart, color: Colors.white70), onPressed: _exportarCSV),
          ],
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(50),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: TabBar(
                controller: _tabController,
                isScrollable: true,
                onTap: _handleTabTap,
                indicator: BoxDecoration(
                  borderRadius: BorderRadius.circular(25),
                  color: Colors.blueAccent.withOpacity(0.2),
                  border: Border.all(color: Colors.blueAccent, width: 1.5)
                ),
                indicatorSize: TabBarIndicatorSize.tab,
                labelColor: Colors.white,
                unselectedLabelColor: Colors.grey,
                dividerColor: Colors.transparent,
                tabs: List.generate(16, (i) => Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Tab(child: Text("U${i + 1}", style: const TextStyle(fontWeight: FontWeight.bold))),
                ))
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
                    Expanded(
                      child: Autocomplete<String>(
                        optionsBuilder: (TextEditingValue textEditingValue) {
                          if (textEditingValue.text == '') return _opcoesNomes;
                          return _opcoesNomes.where((String option) => option.contains(textEditingValue.text.toUpperCase()));
                        },
                        onSelected: (String selection) => _nome.text = selection,
                        fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
                          if (controller.text.isEmpty && _nome.text.isNotEmpty) controller.text = _nome.text;
                          controller.addListener(() => _nome.text = controller.text.toUpperCase());
                          return TextField(
                            controller: controller,
                            focusNode: focusNode,
                            style: const TextStyle(color: Colors.white),
                            decoration: _inputStyle("Aparelho").copyWith(
                              suffixIcon: const Icon(Icons.arrow_drop_down, color: Colors.grey),
                            ),
                            onSubmitted: (val) => onFieldSubmitted(),
                          );
                        },
                        optionsViewBuilder: (context, onSelected, options) {
                          return Align(
                            alignment: Alignment.topLeft,
                            child: Material(
                              elevation: 4.0,
                              color: Colors.grey[900],
                              borderRadius: BorderRadius.circular(12),
                              child: Container(
                                width: 250,
                                constraints: const BoxConstraints(maxHeight: 250),
                                child: ListView.builder(
                                  padding: EdgeInsets.zero,
                                  shrinkWrap: true,
                                  itemCount: options.length,
                                  itemBuilder: (context, index) {
                                    final String option = options.elementAt(index);
                                    return ListTile(
                                      title: Text(option, style: const TextStyle(color: Colors.white, fontSize: 14)),
                                      onTap: () => onSelected(option),
                                    );
                                  },
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(width: 15),
                    GestureDetector(
                      onTap: () => showDialog(context: context, builder: (c) => AlertDialog(backgroundColor: Colors.grey[900], title: const Text("Selecione a Cor", style: TextStyle(color: Colors.white)), content: Wrap(spacing: 12, runSpacing: 12, children: [Colors.red, Colors.blue, Colors.green, Colors.yellow, Colors.white, Colors.purple, Colors.orange, Colors.cyan].map((c) => IconButton(icon: Icon(Icons.circle, color: c, size: 48), onPressed: () { setState(() => _corSelecionada = c); Navigator.pop(context); })).toList()))),
                      child: Container(
                        padding: const EdgeInsets.all(3),
                        decoration: BoxDecoration(color: Colors.white10, shape: BoxShape.circle, border: Border.all(color: _corSelecionada, width: 2.5)),
                        child: CircleAvatar(backgroundColor: _corSelecionada, radius: 20),
                      ),
                    )
                  ]),
                  const SizedBox(height: 20),
                  Row(children: [
                    Expanded(child: _seletorNumerico(_start, "End. Inicial")),
                    const SizedBox(width: 25),
                    Expanded(child: _seletorNumerico(_id, "ID Inicial")),
                  ]),
                  const SizedBox(height: 20),
                  Row(children: [
                    Expanded(child: _seletorNumerico(_qty, "Quantidade")),
                    const SizedBox(width: 25),
                    Expanded(child: _seletorNumerico(_off, "Offset")),
                  ]),
                  const SizedBox(height: 25),
                  SizedBox(
                    width: double.infinity,
                    height: 55,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent, elevation: 4, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                      onPressed: _executar, 
                      child: const Text("ADICIONAR APARELHOS", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold))
                    ),
                  ),
                  const SizedBox(height: 15),
                  Center(
                    child: TextButton.icon(
                      onPressed: () {
                        setState(() => patchesPorUniverso[currentUniverse]!.clear());
                        _salvarDados();
                      },
                      icon: const Icon(Icons.delete_sweep, color: Colors.redAccent, size: 20),
                      label: const Text("LIMPAR UNIVERSO ATUAL", style: TextStyle(color: Colors.redAccent, fontSize: 13, fontWeight: FontWeight.bold)),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: const BorderSide(color: Colors.redAccent, width: 1)),
                      ),
                    ),
                  )
                ]),
              ),
            ),

          DraggableScrollableSheet(
            initialChildSize: _mostrarFormulario ? 0.45 : 0.9,
            minChildSize: 0.15,
            maxChildSize: 0.95,
            builder: (context, scrollController) {
              final items = patchesPorUniverso[currentUniverse]!;
              Map<String, List<Map<String, dynamic>>> agrupados = {};
              for (var item in items) {
                String nome = item['nome'] as String;
                String base = nome.contains(" ID ") ? nome.split(" ID ")[0] : nome;
                agrupados.putIfAbsent(base, () => []).add(item);
              }
              final nomesBases = agrupados.keys.toList();

              return Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF111111),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.8), blurRadius: 20, spreadRadius: 5)],
                ),
                child: Column(children: [
                  const SizedBox(height: 12),
                  Container(width: 50, height: 4, decoration: BoxDecoration(color: Colors.grey[800], borderRadius: BorderRadius.circular(10))),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    child: Text("PATCH - UNIVERSO $currentUniverse", style: const TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.bold, letterSpacing: 2)),
                  ),
                  Expanded(
                    child: ListView.builder(
                        controller: scrollController,
                        padding: const EdgeInsets.fromLTRB(15, 0, 15, 40),
                        itemCount: nomesBases.length,
                        itemBuilder: (context, groupIndex) {
                          final base = nomesBases[groupIndex];
                          final fixtures = agrupados[base]!;
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Padding(
                                padding: const EdgeInsets.only(top: 15, bottom: 8, left: 5),
                                child: Text(base, style: TextStyle(color: Colors.blueAccent.withOpacity(0.8), fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
                              ),
                              ...fixtures.map((item) {
                                String endStr = item['inicio'].toString().padLeft(3, '0');
                                return Container(
                                  margin: const EdgeInsets.only(bottom: 6),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.04),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.symmetric(vertical: BorderSide(color: Color(item['cor']), width: 4))
                                  ),
                                  child: ListTile(
                                    dense: true,
                                    visualDensity: const VisualDensity(vertical: -2),
                                    title: Text("${item['nome']} - CH $endStr", style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500)),
                                    trailing: IconButton(
                                      icon: const Icon(Icons.close, color: Colors.redAccent, size: 18),
                                      onPressed: () {
                                        setState(() => items.remove(item));
                                        _salvarDados();
                                      }
                                    ),
                                  ),
                                );
                              }).toList(),
                            ],
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