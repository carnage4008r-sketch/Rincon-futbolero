import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image_picker/image_picker.dart';

void main() => runApp(const RinconApp());

class RinconApp extends StatelessWidget {
  const RinconApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Rincón Futbolero',
      theme: ThemeData(brightness: Brightness.dark, scaffoldBackgroundColor: const Color(0xFF080D08)),
      home: const HomePage(),
    );
  }
}

// Modelos iguales a tu HTML
class Equipo { String nombre; String logo; Equipo({required this.nombre, this.logo=''}); Map toJson()=>{'nombre':nombre,'logo':logo}; static fromJson(m)=>Equipo(nombre:m['nombre'],logo:m['logo']??''); }
class Partido { int jor; String fecha; String local; String visita; Partido({required this.jor, required this.fecha, required this.local, required this.visita}); Map toJson()=>{'jor':jor,'fecha':fecha,'local':local,'visita':visita}; static fromJson(m)=>Partido(jor:m['jor'],fecha:m['fecha'],local:m['local'],visita:m['visita']); }
class Goleador { String jug; String eq; int gol; Goleador({required this.jug, required this.eq, required this.gol}); Map toJson()=>{'jug':jug,'eq':eq,'gol':gol}; static fromJson(m)=>Goleador(jug:m['jug'],eq:m['eq'],gol:m['gol']); }

class HomePage extends StatefulWidget { const HomePage({super.key}); @override State<HomePage> createState()=>_HomeState(); }

class _HomeState extends State<HomePage> {
  List<Equipo> equipos=[];
  List<Partido> fixture=[];
  Map<String,Map<String,String>> resultados={};
  List<Goleador> goleadores=[];
  String tempLogo='';
  int tab=0;
  int selJor=1;
  String? selLocal, selVisita, selEqGol;
  String fecha=DateTime.now().toIso8601String().split('T')[0];
  final _nameCtrl=TextEditingController();
  final _jugCtrl=TextEditingController();
  final _golCtrl=TextEditingController();
  final ImagePicker _picker=ImagePicker();

  String normaliza(String s)=>s.trim().toUpperCase().replaceAll(RegExp(r'\s+'), ' ');

  @override void initState(){ super.initState(); _loadAll(); }

  // FIX DEFINITIVO 1: Carga todo al abrir, goleo incluido
  Future<void> _loadAll() async {
    final sp=await SharedPreferences.getInstance();
    final eq=sp.getString('equipos_rf');
    final fx=sp.getString('fixture_rf');
    final res=sp.getString('resultados_rf');
    final gol=sp.getString('goleadores_rf');
    setState((){
      if(eq!=null){ equipos=(jsonDecode(eq) as List).map((e)=>Equipo.fromJson(e)).toList(); }
      else { equipos=[Equipo(nombre:"TEHUITZINGO"),Equipo(nombre:"CHINANTLA"),Equipo(nombre:"TECOMATLAN"),Equipo(nombre:"AHUEHUETITLA"),Equipo(nombre:"VET. PIAXTLA"),Equipo(nombre:"PIAXTLA"),Equipo(nombre:"CUICATLAN"),Equipo(nombre:"SAN JUAN FC")]; }
      if(fx!=null) fixture=(jsonDecode(fx) as List).map((e)=>Partido.fromJson(e)).toList();
      if(res!=null){ final m=jsonDecode(res) as Map; resultados=m.map((k,v)=>MapEntry(k, Map<String,String>.from(v))); }
      if(gol!=null) goleadores=(jsonDecode(gol) as List).map((e)=>Goleador.fromJson(e)).toList(); // <-- FIX: ahora si carga al abrir
      if(equipos.isNotEmpty){ selLocal=equipos.first.nombre; selVisita=equipos.length>1?equipos[1].nombre:equipos.first.nombre; selEqGol=equipos.first.nombre; }
    });
  }

  Future<void> _save() async {
    final sp=await SharedPreferences.getInstance();
    await sp.setString('equipos_rf', jsonEncode(equipos.map((e)=>e.toJson()).toList()));
    await sp.setString('fixture_rf', jsonEncode(fixture.map((e)=>e.toJson()).toList()));
    await sp.setString('resultados_rf', jsonEncode(resultados));
    await sp.setString('goleadores_rf', jsonEncode(goleadores.map((e)=>e.toJson()).toList()));
  }

  // Logo igual que tu HTML: convierte a base64 80x80
  Future<void> _pickLogo() async {
    final XFile? file=await _picker.pickImage(source: ImageSource.gallery, imageQuality: 60, maxWidth: 80, maxHeight: 80);
    if(file==null) return;
    final bytes=await file.readAsBytes();
    setState(()=> tempLogo='data:image/jpeg;base64,${base64Encode(bytes)}');
  }

  Widget _logoImg(String logo, {double s=38}){
    if(logo.isEmpty) return CircleAvatar(radius: s/2, backgroundColor: Colors.white, child: const Icon(Icons.shield, color: Colors.green));
    try{
      if(logo.startsWith('data:')){ final b64=logo.split(',').last; return CircleAvatar(radius: s/2, backgroundImage: MemoryImage(base64Decode(b64))); }
    }catch(_){}
    return CircleAvatar(radius: s/2, backgroundColor: Colors.white, child: Text(logo[0]));
  }

  void _addEquipo(){
    final n=normaliza(_nameCtrl.text);
    if(n.isEmpty) return;
    if(equipos.any((e)=>normaliza(e.nombre)==n)) { ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('"$n" ya existe'))); return; }
    if(equipos.length>=16) return;
    setState(()=> equipos.add(Equipo(nombre:n, logo:tempLogo)));
    _nameCtrl.clear(); tempLogo=''; _save();
  }

  void _addPartido(){ if(selLocal==selVisita) return; setState(()=> fixture.add(Partido(jor:selJor, fecha:fecha, local:selLocal!, visita:selVisita!))); _save(); }
  void _addGoles(){ final j=normaliza(_jugCtrl.text); final g=int.tryParse(_golCtrl.text)??0; if(j.isEmpty||g<=0) return; setState(()=> goleadores.add(Goleador(jug:j, eq:selEqGol!, gol:g))); _jugCtrl.clear(); _golCtrl.clear(); _save(); }

  Map<String,Map<String,dynamic>> calcTabla(){
    Map<String,Map<String,dynamic>> t={}; for(var e in equipos){ t[e.nombre]={'JJ':0,'JG':0,'JE':0,'JP':0,'GF':0,'GC':0,'PTS':0,'logo':e.logo}; }
    for(int i=0;i<fixture.length;i++){
      final f=fixture[i]; final r=resultados[i.toString()]; if(r==null) continue;
      final gl=int.tryParse(r['gl']??'')??-1; final gv=int.tryParse(r['gv']??'')??-1; if(gl<0||gv<0) continue;
      if(!t.containsKey(f.local)||!t.containsKey(f.visita)) continue;
      t[f.local]!['JJ']++; t[f.visita]!['JJ']++;
      t[f.local]!['GF']+=gl; t[f.local]!['GC']+=gv; t[f.visita]!['GF']+=gv; t[f.visita]!['GC']+=gl;
      if(gl>gv){t[f.local]!['JG']++; t[f.visita]!['JP']++; t[f.local]!['PTS']+=3;}
      else if(gv>gl){t[f.visita]!['JG']++; t[f.local]!['JP']++; t[f.visita]!['PTS']+=3;}
      else {t[f.local]!['JE']++; t[f.visita]!['JE']++; t[f.local]!['PTS']++; t[f.visita]!['PTS']++;}
    }
    return t;
  }

  @override Widget build(BuildContext context){
    return Scaffold(
      appBar: AppBar(backgroundColor: const Color(0xFF0a140a), title: Row(children:[Image.asset('assets/logo.png', width:40, errorBuilder: (_,__,___)=>const Icon(Icons.sports_soccer, color: Colors.orange)), const SizedBox(width:10), const Column(crossAxisAlignment: CrossAxisAlignment.start, children:[Text('RINCÓN FUTBOLERO', style: TextStyle(color: Color(0xFFFF6B2B), fontSize:16, fontWeight:FontWeight.w900)), Text('LIGA VETERANOS CHINANTLA', style: TextStyle(fontSize:10))])])),
      body: tab==0? _buildConfig() : tab==1? _buildRol() : tab==2? _buildTabla() : _buildGoleo(),
      bottomNavigationBar: BottomNavigationBar(currentIndex: tab, onTap: (i)=>setState(()=>tab=i), selectedItemColor: const Color(0xFFFF6B2B), backgroundColor: const Color(0xFF0a140a), items: const [BottomNavigationBarItem(icon: Icon(Icons.settings), label: 'CONFIG'), BottomNavigationBarItem(icon: Icon(Icons.list_alt), label: 'ROL'), BottomNavigationBarItem(icon: Icon(Icons.table_chart), label: 'TABLA'), BottomNavigationBarItem(icon: Icon(Icons.sports_soccer), label: 'GOLEO')]),
    );
  }

  Widget _buildConfig(){
    return ListView(padding: const EdgeInsets.all(12), children:[
      Text('${equipos.length} equipos', style: const TextStyle(color: Color(0xFFFF6B2B), fontWeight: FontWeight.bold)),
     ...equipos.asMap().entries.map((e)=>Card(color: const Color(0xFF121a12), child: ListTile(leading: _logoImg(e.value.logo), title: Text(e.value.nombre), trailing: IconButton(icon: const Icon(Icons.close, color: Colors.red), onPressed: (){ setState(()=>equipos.removeAt(e.key)); _save(); })))),
      Card(color: const Color(0xFF0a140a), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18), side: const BorderSide(color: Color(0xFF0a5c2e))), child: Padding(padding: const EdgeInsets.all(12), child: Column(children:[
        TextField(controller: _nameCtrl, decoration: const InputDecoration(hintText: 'Nombre del equipo')),
        const SizedBox(height:8),
        Row(children:[ElevatedButton(onPressed: _pickLogo, child: const Text('Elegir logo')), const SizedBox(width:10), if(tempLogo.isNotEmpty) _logoImg(tempLogo, s:52)]),
        const SizedBox(height:8),
        ElevatedButton(onPressed: _addEquipo, style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0a5c2e)), child: const Text('+ Agregar equipo')),
      ]))),
      const Divider(),
      const Text('Rol de juegos', style: TextStyle(color: Colors.orange, fontWeight: FontWeight.bold)),
      Row(children:[Expanded(child: DropdownButton<int>(value: selJor, isExpanded: true, items: List.generate(30, (i)=>DropdownMenuItem(value:i+1, child: Text('Jornada ${i+1}'))), onChanged: (v)=>setState(()=>selJor=v!))), const SizedBox(width:8), Expanded(child: TextField(decoration: InputDecoration(labelText: fecha, border: const OutlineInputBorder()), onChanged: (v)=>fecha=v))]),
      Row(children:[Expanded(child: DropdownButton<String>(value: selLocal, isExpanded: true, items: equipos.map((e)=>DropdownMenuItem(value:e.nombre, child: Text(e.nombre, overflow: TextOverflow.ellipsis))).toList(), onChanged: (v)=>setState(()=>selLocal=v))), const Padding(padding: EdgeInsets.all(8), child: Text('VS', style: TextStyle(color: Colors.orange))), Expanded(child: DropdownButton<String>(value: selVisita, isExpanded: true, items: equipos.map((e)=>DropdownMenuItem(value:e.nombre, child: Text(e.nombre, overflow: TextOverflow.ellipsis))).toList(), onChanged: (v)=>setState(()=>selVisita=v)))]),
      ElevatedButton(onPressed: _addPartido, child: const Text('+ Agregar partido')),
     ...fixture.asMap().entries.map((e)=>ListTile(title: Text('J${e.value.jor} ${e.value.local} vs ${e.value.visita}'), subtitle: Text(e.value.fecha), trailing: IconButton(icon: const Icon(Icons.delete), onPressed: (){ setState(()=>fixture.removeAt(e.key)); _save(); }))),
      const SizedBox(height:20),
      ElevatedButton(onPressed: (){ setState(()=>tab=1); }, style: ElevatedButton.styleFrom(backgroundColor: Colors.orange, foregroundColor: Colors.black), child: const Text('Guardar liga', style: TextStyle(fontWeight: FontWeight.w900))),
    ]);
  }

  Widget _buildRol(){
    var jors=fixture.map((f)=>f.jor).toSet().toList()..sort();
    return ListView(padding: const EdgeInsets.all(12), children:[
      for(var j in jors)...[
        Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: Colors.orange, borderRadius: BorderRadius.circular(12)), child: Text('JORNADA $j • ${fixture.firstWhere((f)=>f.jor==j).fecha}', style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold))),
       ...fixture.asMap().entries.where((e)=>e.value.jor==j).map((en){
          int idx=en.key; var f=en.value; var r=resultados[idx.toString()]??{'gl':'','gv':''};
          return Card(color: const Color(0xFF121a12), child: Padding(padding: const EdgeInsets.all(8), child: Row(children:[
            _logoImg(equipos.firstWhere((e)=>e.nombre==f.local, orElse: ()=>Equipo(nombre:f.local)).logo, s:26),
            Expanded(child: Text(f.local, textAlign: TextAlign.right, style: const TextStyle(fontSize:11))),
            SizedBox(width:45, child: TextFormField(initialValue: r['gl'], textAlign: TextAlign.center, style: const TextStyle(color: Colors.orange, fontWeight: FontWeight.bold), decoration: const InputDecoration(border: OutlineInputBorder()), onChanged: (v){ resultados[idx.toString()]={'gl':v,'gv':resultados[idx.toString()]?['gv']??''}; _save(); })),
            const Text(' - '),
            SizedBox(width:45, child: TextFormField(initialValue: r['gv'], textAlign: TextAlign.center, style: const TextStyle(color: Colors.orange, fontWeight: FontWeight.bold), decoration: const InputDecoration(border: OutlineInputBorder()), onChanged: (v){ resultados[idx.toString()]={'gl':resultados[idx.toString()]?['gl']??'','gv':v}; _save(); })),
            Expanded(child: Text(f.visita, style: const TextStyle(fontSize:11))),
            _logoImg(equipos.firstWhere((e)=>e.nombre==f.visita, orElse: ()=>Equipo(nombre:f.visita)).logo, s:26),
          ]))),
        })
      ]
    ]);
  }

  Widget _buildTabla(){
    final t=calcTabla();
    final arr=t.entries.toList()..sort((a,b){ int pts=(b.value['PTS'] as int)-(a.value['PTS'] as int); if(pts!=0) return pts; return ((b.value['GF']-b.value['GC']) as int)-((a.value['GF']-a.value['GC']) as int); });
    return ListView(padding: const EdgeInsets.all(8), children:[
      SingleChildScrollView(scrollDirection: Axis.horizontal, child: DataTable(columns: const [DataColumn(label: Text('#')), DataColumn(label: Text('')), DataColumn(label: Text('EQUIPO')), DataColumn(label: Text('JJ')), DataColumn(label: Text('JG')), DataColumn(label: Text('JE')), DataColumn(label: Text('JP')), DataColumn(label: Text('GF')), DataColumn(label: Text('GC')), DataColumn(label: Text('DIF')), DataColumn(label: Text('PTS'))], rows: List.generate(arr.length, (i){ var e=arr[i]; int dif=e.value['GF']-e.value['GC']; return DataRow(cells: [DataCell(Text('${i+1}')), DataCell(_logoImg(e.value['logo'], s:26)), DataCell(Text(e.key)), DataCell(Text('${e.value['JJ']}')), DataCell(Text('${e.value['JG']}')), DataCell(Text('${e.value['JE']}')), DataCell(Text('${e.value['JP']}')), DataCell(Text('${e.value['GF']}')), DataCell(Text('${e.value['GC']}')), DataCell(Text('$dif')), DataCell(Text('${e.value['PTS']}', style: const TextStyle(color: Colors.orange, fontWeight: FontWeight.bold)))]); }))),
    ]);
  }

  Widget _buildGoleo(){
    Map<String,Map<String,dynamic>> agg={};
    for(var g in goleadores){ agg.putIfAbsent(g.jug, ()=>{'eq':g.eq,'goles':0}); agg[g.jug]!['goles']+=g.gol; }
    final arr=agg.entries.toList()..sort((a,b)=>(b.value['goles'] as int)-(a.value['goles'] as int));
    return ListView(padding: const EdgeInsets.all(12), children:[
      if(arr.isNotEmpty) Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(gradient: const LinearGradient(colors:[Color(0xFFFF6B2B), Color(0xFFFF8A4A)]), borderRadius: BorderRadius.circular(16)), child: Text('🏆 ${arr.first.key} • ${arr.first.value['eq']} • ${arr.first.value['goles']} GOLES', style: const TextStyle(color: Colors.black, fontWeight: FontWeight.w900), textAlign: TextAlign.center)) else Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: Colors.orange, borderRadius: BorderRadius.circular(16)), child: const Text('Sin goles registrados', style: TextStyle(color: Colors.black), textAlign: TextAlign.center)),
      const SizedBox(height:12),
      Row(children:[Expanded(child: TextField(controller: _jugCtrl, decoration: const InputDecoration(labelText: 'Jugador', border: OutlineInputBorder()))), const SizedBox(width:6), Expanded(child: DropdownButton<String>(value: selEqGol, isExpanded: true, items: equipos.map((e)=>DropdownMenuItem(value:e.nombre, child: Text(e.nombre, overflow: TextOverflow.ellipsis))).toList(), onChanged: (v)=>setState(()=>selEqGol=v))), SizedBox(width:60, child: TextField(controller: _golCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'G', border: OutlineInputBorder())))]),
      const SizedBox(height:8),
      ElevatedButton(onPressed: _addGoles, style: ElevatedButton.styleFrom(backgroundColor: Colors.orange, foregroundColor: Colors.black), child: const Text('Agregar goles')),
      const SizedBox(height:12),
     ...arr.map((e)=>Card(color: const Color(0xFF121a12), child: ListTile(leading: _logoImg(equipos.firstWhere((eq)=>eq.nombre==e.value['eq'], orElse: ()=>Equipo(nombre:e.value['eq'])).logo, s:26), title: Text(e.key), subtitle: Text(e.value['eq']), trailing: Row(mainAxisSize: MainAxisSize.min, children:[Text('${e.value['goles']}', style: const TextStyle(fontSize:18, fontWeight:FontWeight.bold)), IconButton(icon: const Icon(Icons.close, color: Colors.red), onPressed: (){ setState(()=>goleadores.removeWhere((g)=>g.jug==e.key)); _save(); })])))),
      if(arr.isNotEmpty) OutlinedButton(onPressed: (){ setState(()=>goleadores=[]); _save(); }, child: const Text('Borrar goleo')),
    ]);
  }
}
