import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:adhan/adhan.dart';
import 'package:intl/intl.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Prayer Times (MVP)',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(primarySwatch: Colors.indigo),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  Coordinates? _coords;
  PrayerTimes? _prayerTimes;
  Timer? _ticker;
  String _nextName = '';
  DateTime? _nextTime;
  final _fmt = DateFormat.jm();

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final ok = await _ensureLocationPermission();
    if (!ok) return;
    final pos = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.low);
    setState(() => _coords = Coordinates(pos.latitude, pos.longitude));
    _compute();
    _startTicker();
  }

  Future<bool> _ensureLocationPermission() async {
    LocationPermission p = await Geolocator.checkPermission();
    if (p == LocationPermission.denied) {
      p = await Geolocator.requestPermission();
      if (p == LocationPermission.denied) return false;
    }
    if (p == LocationPermission.deniedForever) return false;
    return true;
  }

  void _compute() {
    if (_coords == null) return;
 final params = CalculationMethod.muslim_world_league.getParameters();
    final pt = PrayerTimes.today(_coords!, params);
    setState(() => _prayerTimes = pt);
    _updateNext();
  }

  void _updateNext() {
    if (_prayerTimes == null) return;
    final next = _prayerTimes!.nextPrayer();
    final dt = _prayerTimes!.timeForPrayer(next);
    setState(() {
      _nextName = next.name;
      _nextTime = dt;
    });
  }

  void _startTicker() {
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      _updateNext();
      setState(() {}); // update countdown text
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  String _countdown() {
    if (_nextTime == null) return '--:--:--';
    final diff = _nextTime!.difference(DateTime.now());
    if (diff.isNegative) return '00:00:00';
    final h = diff.inHours.toString().padLeft(2, '0');
    final m = (diff.inMinutes % 60).toString().padLeft(2, '0');
    final s = (diff.inSeconds % 60).toString().padLeft(2, '0');
    return '$h:$m:$s';
  }

  Widget _body() {
    if (_prayerTimes == null) return const Center(child: Text('Getting location & times...'));
    final map = {
      'Fajr': _prayerTimes!.fajr,
      'Sunrise': _prayerTimes!.sunrise,
      'Dhuhr': _prayerTimes!.dhuhr,
      'Asr': _prayerTimes!.asr,
      'Maghrib': _prayerTimes!.maghrib,
      'Isha': _prayerTimes!.isha,
    };
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        Card(
          child: ListTile(
            title: Text('Next: $_nextName'),
            subtitle: Text(_nextTime == null ? '-' : _fmt.format(_nextTime!)),
            trailing: Text(_countdown(), style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
        ),
        const SizedBox(height: 12),
        ...map.entries.map((e) => ListTile(
          title: Text(e.key),
          trailing: Text(_fmt.format(e.value)),
        )),
        const SizedBox(height: 24),
        ElevatedButton.icon(
          onPressed: () async {
            setState(() {
              _prayerTimes = null;
              _nextName = '';
              _nextTime = null;
            });
            await _init();
          },
          icon: const Icon(Icons.refresh),
          label: const Text('Refresh'),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(appBar: AppBar(title: const Text('Prayer Times (MVP)')), body: _body());
  }
}
