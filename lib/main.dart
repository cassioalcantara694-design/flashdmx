import 'dart:convert';
import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:file_saver/file_saver.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';
import 'package:csv/csv.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:syncfusion_flutter_xlsio/xlsio.dart' as xls;
import 'package:file_picker/file_picker.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  MobileAds.instance.initialize();
  runApp(const MaterialApp(debugShowCheckedModeBanner: false, home: PatchScreen()));
}

class PatchScreen extends StatefulWidget {
  const PatchScreen({super.key});
  @override
  State<PatchScreen> createState() => _PatchScreenState();
}

class _PatchScreenState extends State<PatchScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final DraggableScrollableController _sheetController = DraggableScrollableController();
  ScrollController? _activeScrollController;
  BannerAd? _bannerAd;
  bool _bannerLoaded = false;
  int currentUniverse = 1;
  bool _mostrarFormulario = true;
  Map<int, List<Map<String, dynamic>>> patchesPorUniverso = {for (int i = 1; i <= 16; i++) i: []};
  Color _corSelecionada = Colors.white;
  List<int> _idsRecemAdicionados = []; // Para o efeito de flash

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
    _loadBanner();
    _tabController = TabController(length: 16, vsync: this);
    _carregarDados();
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        setState(() => currentUniverse = _tabController.index + 1);
      }
    });
  }

  void _loadBanner() {
    _bannerAd = BannerAd(
      adUnitId: 'ca-app-pub-3940256099942544/6300978111', // ID de Teste do Google
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (_) => setState(() => _bannerLoaded = true),
        onAdFailedToLoad: (ad, err) {
          ad.dispose();
          print('Banner error: $err');
        },
      ),
    )..load();
  }

  @override
  void dispose() {
    _bannerAd?.dispose();
    _tabController.dispose();
    super.dispose();
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
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_mostrarFormulario && patchesPorUniverso[currentUniverse]!.isNotEmpty) {
        _sheetController.animateTo(0.9, duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
      } else if (_mostrarFormulario) {
        _sheetController.animateTo(0.35, duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
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
      List<int> novosIds = [];
      for (int i = 0; i < qty; i++) {
        if (start > 512) {
          _showMsg("Limite de 512 atingido. Adicionados $adicionados.", Colors.orange);
          break;
        }
        
        bool sobreposto = patchesPorUniverso[currentUniverse]!.any((e) => e['inicio'] == start);
        if (sobreposto) _showMsg("Aviso: Canal $start já ocupado!", Colors.redAccent);

        final novoItem = {
          "id_unico": DateTime.now().millisecondsSinceEpoch + i, // ID temporário para animação
          "nome": "${_nome.text.toUpperCase()} ID ${fixtureId + i}",
          "inicio": start,
          "cor": _corSelecionada.toARGB32()
        };
        
        patchesPorUniverso[currentUniverse]!.add(novoItem);
        novosIds.add(novoItem['id_unico'] as int);
        start += off;
        adicionados++;
      }
      
      _idsRecemAdicionados = novosIds;
      _start.text = start.toString();
      _id.text = (fixtureId + adicionados).toString();
      _salvarDados();
      
      // Remove o destaque após 2 segundos
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) setState(() => _idsRecemAdicionados = []);
      });

      // Scroll automático para o final
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_activeScrollController != null && _activeScrollController!.hasClients) {
          _activeScrollController!.animateTo(
            _activeScrollController!.position.maxScrollExtent,
            duration: const Duration(milliseconds: 600),
            curve: Curves.easeOut,
          );
        }
      });
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
          TextButton(
            onPressed: () => Navigator.pop(c), 
            child: const Text("CANCELAR", style: TextStyle(color: Colors.white70))
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () {
              setState(() { for (int i = 1; i <= 16; i++) patchesPorUniverso[i] = []; });
              _salvarDados();
              _showMsg("Todos os universos foram limpos!", Colors.red);
              Navigator.pop(c);
            }, 
            child: const Text("LIMPAR TUDO", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))
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
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 10, bottom: 10),
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blueAccent,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () => Navigator.pop(c), 
              child: const Text("GERAR", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))
            ),
          )
        ],
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
    List<List<dynamic>> rows = [
      [
        "Channel", "Patch", "Dimmer", "Spot", "Position", "Unit", "Type", "Lens", "Hookup", "Purpose",
        "Color", "Gobo", "Focus", "Circuit Name", "Circuit Number", "Fixture Options", "Mode", "Wattage",
        "Lamp Type", "Offset", "X", "Y", "Z", "Pan", "Tilt", "Spin", "Weight", "Notes", "FootNotes",
        "# of Data Channels", "# of Color Frames", "# of Lamps", "Circuit Type", "Model", "Cost",
        "Status", "Console", "Layer", "Tag", "Owner", "Manufacturer", "Notes2", "Notes3", "Notes4",
        "RotX", "RotY", "RotZ", "Patch Address", "Patch Universe"
      ]
    ];

    patchesPorUniverso.forEach((universo, lista) {
      for (var item in lista) {
        String nomeFull = item['nome'];
        String base = nomeFull.contains(" ID ") ? nomeFull.split(" ID ")[0] : nomeFull;
        String id = nomeFull.contains(" ID ") ? nomeFull.split(" ID ")[1] : "-";
        String ch = item['inicio'].toString();
        String patchStr = "$universo.${ch.padLeft(3, '0')}";

        rows.add([
          ch, patchStr, "", id, "", "1", base, "", "Control", "",
          "O/W", "", "", "", "", "", "N/A", "400 W", "MSD400 HR", "",
          "0.00m", "0.00m", "0.00m", "0.00", "0.00", "0.00", "0.00", "", "N/A",
          "1", "1", "1", "AC208ND", base, "0.00", "HUNG", "", "Main", "", "0",
          "Generic", "", "", "", "0.00", "0.00", "0.00", ch, universo
        ]);
      }
    });

    String csv = const ListToCsvConverter(fieldDelimiter: ',').convert(rows);
    await FileSaver.instance.saveFile(name: "patch_professional", bytes: utf8.encode(csv), ext: "csv", mimeType: MimeType.csv);
    _showMsg("CSV salvo na pasta Downloads!", Colors.green);
  }

  Future<void> _exportarExcel() async {
    final xls.Workbook workbook = xls.Workbook();
    final xls.Worksheet sheet = workbook.worksheets[0];
    sheet.getRangeByIndex(1, 1).setText("Universe");
    sheet.getRangeByIndex(1, 2).setText("Fixture");
    sheet.getRangeByIndex(1, 3).setText("ID");
    sheet.getRangeByIndex(1, 4).setText("Channel");

    int row = 2;
    patchesPorUniverso.forEach((universo, lista) {
      for (var item in lista) {
        String nome = item['nome'];
        String base = nome.contains(" ID ") ? nome.split(" ID ")[0] : nome;
        String id = nome.contains(" ID ") ? nome.split(" ID ")[1] : "-";
        sheet.getRangeByIndex(row, 1).setNumber(universo.toDouble());
        sheet.getRangeByIndex(row, 2).setText(base);
        sheet.getRangeByIndex(row, 3).setText(id);
        sheet.getRangeByIndex(row, 4).setNumber(item['inicio'].toDouble());
        row++;
      }
    });

    final List<int> bytes = workbook.saveAsStream();
    workbook.dispose();
    await FileSaver.instance.saveFile(name: "patch_flashdmx", bytes: Uint8List.fromList(bytes), ext: "xlsx", mimeType: MimeType.microsoftExcel);
    _showMsg("Excel salvo na pasta Downloads!", Colors.green);
  }

  Future<void> _exportarJSON() async {
    String data = jsonEncode(patchesPorUniverso.map((k, v) => MapEntry(k.toString(), v)));
    // Usando MimeType.other para forçar o Android a salvar e mostrar o arquivo sem restrições
    await FileSaver.instance.saveFile(name: "backup_flashdmx", bytes: Uint8List.fromList(utf8.encode(data)), ext: "json", mimeType: MimeType.other);
    _showMsg("Backup JSON salvo na pasta Downloads!", Colors.green);
  }

  Future<void> _importarJSON() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['json']);
    if (result != null) {
      try {
        String content = utf8.decode(result.files.first.bytes!);
        Map<String, dynamic> decoded = jsonDecode(content);
        setState(() => patchesPorUniverso = decoded.map((k, v) => MapEntry(int.parse(k), List<Map<String, dynamic>>.from(v))));
        _salvarDados();
        _showMsg("Patch restaurado!", Colors.green);
      } catch (e) { _showMsg("Erro ao restaurar JSON.", Colors.red); }
    }
  }

  void _abrirMenuMais() {
    showModalBottomSheet(
      context: context, backgroundColor: Colors.grey[900],
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (c) => Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          _menuItem(Icons.table_chart, "CSV (Planilha)", () { Navigator.pop(c); _exportarCSV(); }),
          _menuItem(Icons.table_view, "Excel (XLSX)", () { Navigator.pop(c); _exportarExcel(); }),
          _menuItem(Icons.backup, "Exportar Backup (JSON)", () { Navigator.pop(c); _exportarJSON(); }),
          _menuItem(Icons.restore, "Importar Backup (JSON)", () { Navigator.pop(c); _importarJSON(); }),
        ]),
      )
    );
  }

  Widget _menuItem(IconData icon, String text, VoidCallback tap) => ListTile(
    leading: Icon(icon, color: Colors.blueAccent),
    title: Text(text, style: const TextStyle(color: Colors.white)),
    onTap: tap,
  );

  InputDecoration _inputStyle(String label) => InputDecoration(
    labelText: label, labelStyle: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
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
          title: const Text("FLASH DMX", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 22, letterSpacing: 1.2)),
          backgroundColor: Colors.black,
          elevation: 0,
          actions: [
            _actionBtn(Icons.picture_as_pdf, _exportarPDF, isPdf: true),
            _actionBtn(Icons.exit_to_app, _importarJSON),
            _actionBtn(Icons.more_horiz, _abrirMenuMais),
            const SizedBox(width: 15),
          ],
        ),
        body: Column(
          children: [
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 15, vertical: 5),
              decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(15)),
              child: Column(
                children: [
                  const Padding(
                    padding: EdgeInsets.only(top: 8),
                    child: Text("PATCH UNIVERSOS [1-16]", style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1)),
                  ),
                  Row(
                    children: [
                      const Padding(padding: EdgeInsets.symmetric(horizontal: 5), child: Icon(Icons.chevron_left, color: Colors.white24, size: 20)),
                      Expanded(
                        child: TabBar(
                          controller: _tabController, isScrollable: true, onTap: _handleTabTap,
                          indicator: BoxDecoration(borderRadius: BorderRadius.circular(8), color: Colors.blueAccent),
                          indicatorSize: TabBarIndicatorSize.tab, labelColor: Colors.white, unselectedLabelColor: Colors.white70,
                          dividerColor: Colors.transparent, tabAlignment: TabAlignment.start,
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          tabs: List.generate(16, (i) => Tab(height: 30, child: Padding(padding: const EdgeInsets.symmetric(horizontal: 12), child: Text("U${i + 1}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13))))),
                        ),
                      ),
                      const Padding(padding: EdgeInsets.symmetric(horizontal: 5), child: Icon(Icons.chevron_right, color: Colors.white24, size: 20)),
                    ],
                  ),
                ],
              ),
            ),
            
            Expanded(
              child: Stack(
                children: [
                  if (_mostrarFormulario)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
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
                              child: Container(
                                width: 46, height: 46,
                                decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 1.5)),
                                padding: const EdgeInsets.all(4),
                                child: Container(decoration: BoxDecoration(color: _corSelecionada, shape: BoxShape.circle)),
                              ),
                            )
                          ]),
                          const SizedBox(height: 20),
                          Row(children: [
                            Expanded(child: _SeletorInteligente(controller: _start, label: "Endereço Inicial")),
                            const SizedBox(width: 20),
                            Expanded(child: _SeletorInteligente(controller: _id, label: "ID Inicial")),
                          ]),
                          const SizedBox(height: 20),
                          Row(children: [
                            Expanded(child: _SeletorInteligente(controller: _qty, label: "Quantidade")),
                            const SizedBox(width: 20),
                            Expanded(child: _SeletorInteligente(controller: _off, label: "Offset / Channel")),
                          ]),
                          const SizedBox(height: 30),
                          SizedBox(width: double.infinity, height: 55, child: ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))), onPressed: _executar, child: const Text("ADICIONAR APARELHOS", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)))),
                          const SizedBox(height: 15),
                          Row(children: [
                            Expanded(child: OutlinedButton.icon(onPressed: () { setState(() => patchesPorUniverso[currentUniverse]!.clear()); _salvarDados(); }, icon: const Icon(Icons.delete_sweep, color: Colors.redAccent, size: 18), label: Text("LIMPAR U$currentUniverse", style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold, fontSize: 11)), style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.redAccent), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25))))),
                            const SizedBox(width: 10),
                            Expanded(child: OutlinedButton.icon(onPressed: _confirmarLimparTudo, icon: const Icon(Icons.delete_forever, color: Colors.red, size: 18), label: const Text("LIMPAR TUDO", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 11)), style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.red), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25))))),
                          ]),
                        ]),
                      ),
                    ),

                  DraggableScrollableSheet(
                    controller: _sheetController,
                    initialChildSize: _mostrarFormulario ? 0.35 : 0.9, 
                    minChildSize: _mostrarFormulario ? 0.30 : 0.8,
                    maxChildSize: 0.95,
                    builder: (context, scrollController) {
                _activeScrollController = scrollController;
                final items = patchesPorUniverso[currentUniverse]!;
                Map<String, List<Map<String, dynamic>>> agrupados = {};
                for (var item in items) {
                  String base = item['nome'].contains(" ID ") ? item['nome'].split(" ID ")[0] : item['nome'];
                  agrupados.putIfAbsent(base, () => []).add(item);
                }
                return Container(
                  decoration: BoxDecoration(color: const Color(0xFF111111), borderRadius: const BorderRadius.vertical(top: Radius.circular(30)), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.8), blurRadius: 20, spreadRadius: 5)]),
                  child: Column(children: [
                    const SizedBox(height: 12),
                    Container(width: 60, height: 5, decoration: BoxDecoration(color: Colors.grey[700], borderRadius: BorderRadius.circular(10))),
                    Padding(padding: const EdgeInsets.symmetric(vertical: 15), child: Text("PATCH - UNIVERSO $currentUniverse", style: const TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.bold, letterSpacing: 2))),
                    Expanded(child: ListView.builder(controller: scrollController, padding: const EdgeInsets.fromLTRB(15, 0, 15, 40), itemCount: agrupados.length, itemBuilder: (context, idx) {
                      String base = agrupados.keys.elementAt(idx);
                      List<Map<String, dynamic>> fixtures = agrupados[base]!;
                      return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Padding(padding: const EdgeInsets.only(top: 15, bottom: 8, left: 5), child: Text(base, style: TextStyle(color: Colors.blueAccent.withOpacity(0.8), fontSize: 12, fontWeight: FontWeight.bold))),
                        ...fixtures.map((item) {
                          bool isNovo = item.containsKey('id_unico') && _idsRecemAdicionados.contains(item['id_unico']);
                          return AnimatedContainer(
                            duration: const Duration(milliseconds: 500),
                            margin: const EdgeInsets.only(bottom: 6),
                            decoration: BoxDecoration(
                              color: isNovo ? Colors.blueAccent.withOpacity(0.2) : Colors.white.withOpacity(0.04),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.symmetric(vertical: BorderSide(color: isNovo ? Colors.blueAccent : Color(item['cor']), width: 4)),
                              boxShadow: isNovo ? [BoxShadow(color: Colors.blueAccent.withOpacity(0.3), blurRadius: 10)] : null,
                            ),
                            child: ListTile(dense: true, title: Text("${item['nome']} - CH ${item['inicio'].toString().padLeft(3, '0')}", style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500)), trailing: IconButton(icon: const Icon(Icons.close, color: Colors.redAccent, size: 18), onPressed: () { setState(() => items.remove(item)); _salvarDados(); }))
                          );
                        }).toList()
                      ]);
                    })),
                  ]),
                );
              },
                  ),
                ],
              ),
            ),
            if (_bannerAd != null && _bannerLoaded)
              SizedBox(
                width: _bannerAd!.size.width.toDouble(),
                height: _bannerAd!.size.height.toDouble(),
                child: AdWidget(ad: _bannerAd!),
              ),
          ],
        ),
      ),
    );
  }

  Widget _actionBtn(IconData icon, VoidCallback press, {bool isPdf = false}) {
    return GestureDetector(
      onTap: press,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
        height: 44, width: 44, // Aumentado para melhor toque
        decoration: BoxDecoration(
          color: isPdf ? Colors.red : Colors.white10,
          borderRadius: BorderRadius.circular(12), // Mais arredondado
          border: Border.all(color: isPdf ? Colors.redAccent : Colors.white24, width: 1.5),
          boxShadow: isPdf ? [
            BoxShadow(
              color: Colors.red.withOpacity(0.6), 
              blurRadius: 12, 
              spreadRadius: 2
            )
          ] : null,
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Padding(
              padding: EdgeInsets.only(bottom: isPdf ? 10 : 0),
              child: Icon(icon, color: Colors.white, size: isPdf ? 22 : 24),
            ),
            if (isPdf) 
              Positioned(
                bottom: 4, 
                child: Text(
                  "PDF", 
                  style: TextStyle(
                    color: Colors.white, 
                    fontSize: 8, // Fonte maior e mais legível
                    fontWeight: FontWeight.bold,
                    shadows: [Shadow(color: Colors.black45, blurRadius: 2)]
                  )
                )
              ),
          ],
        ),
      ),
    );
  }

  void _escolherCor() => showDialog(
    context: context, 
    builder: (c) => AlertDialog(
      backgroundColor: Colors.grey[900], 
      title: const Text("Cor", style: TextStyle(color: Colors.white)), 
      content: Wrap(
        spacing: 12, 
        runSpacing: 12, 
        children: [Colors.red, Colors.blue, Colors.green, Colors.yellow, Colors.white, Colors.purple, Colors.orange, Colors.cyan].map((c) => IconButton(
          icon: Icon(Icons.circle, color: c, size: 48), 
          onPressed: () { setState(() => _corSelecionada = c); Navigator.pop(context); }
        )).toList()
      )
    )
  );
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
      Text(widget.label, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
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
