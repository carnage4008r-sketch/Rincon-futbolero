import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() { runApp(const MyApp()); }

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Rincon Futbolero',
      theme: ThemeData(primarySwatch: Colors.green, useMaterial3: true),
      home: const RinconApp(),
    );
  }
}

class Equipo { String nombre; int pj, g, e, p, gf, gc; Equipo({required this.nombre, this.pj=0, this.g=0, this.e=0, this.p=0, this.gf=0, this.gc=0}); int get pts => g*3+e; int get dg => gf-gc; Map<String,dynamic> toJson() => {'nombre':nombre,'pj':pj,'g':g,'e':e,'p':p,'gf':gf,'gc':gc}; factory Equipo.fromJson(Map<String,dynamic> j) => Equipo(nombre: j['nombre'], pj: j['pj']??0, g: j['g']??0, e: j['e']??0, p: j['p']??0, gf: j['gf']??0, gc: j['gc']??0); }
class Partido { String local, visita; int golL, golV; bool jugado; Partido({required this.local, required this.visita, this.golL=0, this.golV=0, this.jugado=false}); Map<String,dynamic> toJson() => {'local':local,'visita':visita,'golL':golL,'golV':golV,'jugado':jugado}; factory Partido.fromJson(Map<String,dynamic> j) => Partido(local: j['local'], visita: j['visita'], golL: j['golL']??0, golV: j['golV']??0, jugado: j['jugado']??false); }
class Goleador { String nombre, equipo; int goles; Goleador({required this.nombre, required this.equipo, this.goles=0}); Map<String,dynamic> toJson() => {'nombre':nombre,'equipo':equipo,'goles':goles}; factory Goleador.fromJson(Map<String,dynamic> j) => Goleador(nombre: j['nombre'], equipo: j['equipo'], goles: j['goles']??0); }

class RinconApp extends StatefulWidget { const RinconApp({super.key}); @override State<RinconApp> createState() => _RinconAppState(); }

class _RinconAppState extends State<RinconApp> {
  List<Equipo> equipos = [];
  List<Partido> fixture = [];
  List<Goleador> goleadores = [];

  @override
  void initState() { super.initState(); _cargar(); }

  Future<void> _cargar() async {
    final prefs = await SharedPreferences.getInstance();
    final eq = prefs.getString('equipos');
    final fx = prefs.getString('fixture');
    final gol = prefs.getString('goleadores');
    setState(() {
      if(eq!=null){ equipos=(jsonDecode(eq) as List).map<Equipo>((e)=>Equipo.fromJson(e as Map<String,dynamic>)).toList(); }
      if(fx!=null){ fixture=(jsonDecode(fx) as List).map<Partido>((e)=>Partido.fromJson(e as Map<String,dynamic>)).toList(); }
      if(gol!=null){ goleadores=(jsonDecode(gol) as List).map<Goleador>((e)=>Goleador.fromJson(e as Map<String,dynamic>)).toList(); }
    });
  }

  Future<void> _guardar() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('equipos', jsonEncode(equipos.map((e)=>e.toJson()).toList()));
    await prefs.setString('fixture', jsonEncode(fixture.map((e)=>e.toJson()).toList()));
    await prefs.setString('goleadores', jsonEncode(goleadores.map((e)=>e.toJson()).toList()));
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('RINCON FUTBOLERO - Veteranos Chinantla', style: TextStyle(fontWeight: FontWeight.bold)),
          backgroundColor: Colors.green[800],
          foregroundColor: Colors.white,
          bottom: const TabBar(tabs: [Tab(text: 'Tabla'), Tab(text: 'Fixture'), Tab(text: 'Goleo')]),
          actions: [IconButton(onPressed: _guardar, icon: const Icon(Icons.save))],
        ),
        body: TabBarView(
          children: [
            _tabla(),
            _fixture(),
            _goleo(),
          ],
        ),
        floatingActionButton: FloatingActionButton(onPressed: _addEquipo, backgroundColor: Colors.green[800], child: const Icon(Icons.add, color: Colors.white)),
      ),
    );
  }

  Widget _tabla() {
    final tabla = [...equipos]..sort((a,b){ if(b.pts!=a.pts) return b.pts.compareTo(a.pts); return b.dg.compareTo(a.dg); });
    return ListView.builder(itemCount: tabla.length, itemBuilder: (c,i){ final eq=tabla[i]; return ListTile(leading: Text('${i+1}', style: const TextStyle(fontWeight: FontWeight.bold)), title: Text(eq.nombre), subtitle: Text('PJ:${eq.pj} G:${eq.g} E:${eq.e} P:${eq.p} GF:${eq.gf} GC:${eq.gc}'), trailing: Text('${eq.pts} PTS', style: const TextStyle(fontWeight: FontWeight.bold))); });
  }
  Widget _fixture() { return ListView.builder(itemCount: fixture.length, itemBuilder: (c,i){ final p=fixture[i]; return ListTile(title: Text('${p.local} ${p.jugado? p.golL : "-"} vs ${p.jugado? p.golV : "-"} ${p.visita}'), trailing: Icon(p.jugado? Icons.check_circle : Icons.schedule, color: p.jugado? Colors.green : Colors.grey)); }); }
  Widget _goleo() { final g=[...goleadores]..sort((a,b)=>b.goles.compareTo(a.goles)); return ListView.builder(itemCount: g.length, itemBuilder: (c,i){ final go=g[i]; return ListTile(leading: Text('${i+1}'), title: Text(go.nombre), subtitle: Text(go.equipo), trailing: Text('${go.goles}')); }); }

  void _addEquipo() {
    final ctrl = TextEditingController();
    showDialog(context: context, builder: (c)=>AlertDialog(title: const Text('Nuevo Equipo'), content: TextField(controller: ctrl, decoration: const InputDecoration(hintText: 'Nombre')), actions: [TextButton(onPressed: (){ if(ctrl.text.isNotEmpty){ setState(()=>equipos.add(Equipo(nombre: ctrl.text))); _guardar(); } Navigator.pop(context); }, child: const Text('Agregar'))]));
  }
}
