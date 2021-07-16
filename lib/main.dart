import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:quakeapp/quake_dataclass.dart';
import 'package:sqflite/sqflite.dart';
import 'package:xml2json/xml2json.dart';
import 'package:time_ago_provider/time_ago_provider.dart' as timeago;

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Quake App',
      theme: ThemeData(
        primarySwatch: Colors.orange,
      ),
      home: MyHomePage(title: 'Quake App'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  MyHomePage({Key? key, required this.title}) : super(key: key);

  final String title;

  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  List<QuakeData> qRawData = [];
  List<QuakeData> qData = [];
  late Database dataBase;
  DateTime minDate = DateTime.now().subtract(Duration(days: 7));
  DateTime maxDate = DateTime.now();
  double minIntensity = 2;
  @override
  void initState() {
    _firstLoad();
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.title,
          style: TextStyle(color: Colors.white),
        ),
        elevation: 0,
      ),
      body: Center(
        child: Column(
          children: <Widget>[
            Container(
              height: 50,
              decoration: BoxDecoration(color: Colors.orange),
              child: _renderFilter(),
            ),
            Expanded(child: _renderQuakeList())
          ],
        ),
      ),
    );
  }

  void _firstLoad() async {
    dataBase = await _loadDataBase();
    var response =
        await http.get(Uri.parse("http://www.koeri.boun.edu.tr/rss/"));
    Xml2Json converter = new Xml2Json()..parse(utf8.decode(response.bodyBytes));
    Map<String, dynamic> jsonData = json.decode(converter.toParker());
    List<dynamic> nData = jsonData["rss"]["channel"]["item"];
    List<dynamic> oData =
        await dataBase.rawQuery('SELECT * FROM quake_list ORDER BY id desc');
    List<QuakeData> newData =
        nData.map((e) => QuakeData.fromRequest(e)).toList();
    List<QuakeData> oldData = oData.map((e) => QuakeData.fromSql(e)).toList();
    List<QuakeData> merged = await _compareQuakeData(newData, oldData);
    qRawData = merged;
    _doFilter();
  }

  Future<Database> _loadDataBase() async {
    var databasesPath = await getDatabasesPath();
    String path = databasesPath + '/database.db';
    // await deleteDatabase(path);// for Debug
    return await openDatabase(path, version: 1,
        onCreate: (Database db, int version) async {
      // Database ilk oluştuğunda tablolar oluşturulur.
      await db.execute(
          'CREATE TABLE quake_list (id INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL,intensity DOUBLE NOT NULL, depth DOUBLE NOT NULL,location  VARCHAR (500) NOT NULL, latitude  DOUBLE        NOT NULL,longitude DOUBLE        NOT NULL,dateTime  VARCHAR (500) NOT NULL)');
    });
  }

  Future<List<QuakeData>> _compareQuakeData(
      List<QuakeData> newData, List<QuakeData> oldData) async {
    List<QuakeData> diff = [];
    List<QuakeData> merged = [];
    if (oldData.length == 0) {
      diff = newData;
      merged = diff;
    } else {
      QuakeData lastAdded = oldData.first;
      for (int i = 0; i < newData.length; i++) {
        QuakeData item = newData[i];
        if (item.dateTime.isAfter(lastAdded.dateTime)) {
          diff.add(item);
        } else
          break;
      }
      merged.addAll(diff);
      merged.addAll(oldData);
    }
    await _insertDb2Data(diff);
    return merged;
  }

  Future _insertDb2Data(List<QuakeData> diff) async {
    return await dataBase.transaction((txn) async {
      diff.forEach((element) async {
        await txn.rawInsert(
            'INSERT INTO quake_list(intensity, depth, location,latitude,longitude,dateTime)'
            ' VALUES(${element.intensity}, ${element.depth},"${element.location}",${element.latitude},${element.longitude},"${element.sqlDateTime}")');
      });
    });
  }

  Widget _renderQuakeList() {
    return ListView.separated(
        itemCount: qData.length,
        separatorBuilder: (BuildContext context, int index) => const Divider(),
        itemBuilder: (BuildContext context, int index) {
          QuakeData item = qData[index];
          return InkWell(
            onTap: () {
              Navigator.push(context,
                  MaterialPageRoute(builder: (context) => MapPage(item)));
            },
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        width: 250,
                        child: Text(
                          item.location.toString(),
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            vertical: 4, horizontal: 8),
                        decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(5),
                            color: Colors.redAccent),
                        child: Text(
                          item.intensity.toString(),
                          style: TextStyle(fontSize: 12, color: Colors.white),
                        ),
                      )
                    ],
                  ),
                  SizedBox(
                    height: 5,
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Text(
                        timeago.format(item.dateTime, locale: 'tr'),
                        style: TextStyle(fontSize: 12),
                      )
                    ],
                  ),
                ],
              ),
            ),
          );
        });
  }

  Widget _renderFilter() {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          InkWell(
            onTap: () async {
              DateTimeRange? range = await showDateRangePicker(
                  context: context,
                  firstDate: DateTime(2015),
                  lastDate: DateTime.now(),
                  confirmText: "Tamam",
                  saveText: "Kaydet",
                  fieldStartHintText: "Başlangıç",
                  fieldStartLabelText: "Başlangıç",
                  fieldEndHintText: "Bitiş",
                  fieldEndLabelText: "Bitiş",
                  helpText: "Tarih Seçin",
                  initialDateRange:
                      DateTimeRange(start: minDate, end: maxDate));
              if (range != null) {
                setState(() {
                  minDate = range.start;
                  maxDate = range.end;
                });
                _doFilter();
              }
            },
            child: Row(
              children: [
                Text(DateFormat("dd.MM.yyyy").format(minDate),
                    style: TextStyle(color: Colors.white)),
                Icon(
                  Icons.keyboard_arrow_right,
                  color: Colors.white,
                ),
                Text(DateFormat("dd.MM.yyyy").format(maxDate),
                    style: TextStyle(color: Colors.white))
              ],
            ),
          ),
          Theme(
            data: Theme.of(context).copyWith(canvasColor: Colors.orange),
            child: DropdownButton<double>(
              value: minIntensity,
              icon: Row(
                children: [
                  Text(
                    "+ Büyüklük",
                  ),
                  Icon(
                    Icons.arrow_drop_down_rounded,
                    color: Colors.white,
                  )
                ],
              ),
              style: const TextStyle(color: Colors.white),
              underline: Container(),
              items: <double>[1.0, 2.0, 3.0, 4.0, 5.0, 6.0, 7.0, 8.0, 9.0, 10.0]
                  .map((double value) {
                return DropdownMenuItem(
                  value: value,
                  child: new Text(
                    value.toString(),
                    style: TextStyle(color: Colors.white),
                  ),
                );
              }).toList(),
              onChanged: (value) {
                if (value != null)
                  setState(() {
                    minIntensity = value;
                  });
                _doFilter();
              },
            ),
          )
        ],
      ),
    );
  }

  void _doFilter() {
    List<QuakeData> filtered = [];
    qRawData.forEach((element) {
      if (element.dateTime.isAfter(minDate) &&
          element.dateTime.isBefore(maxDate) &&
          element.intensity > minIntensity) filtered.add(element);
    });
    setState(() {
      qData = filtered;
    });
  }
}

class MapPage extends StatefulWidget {
  final QuakeData selected;
  const MapPage(this.selected);

  @override
  _MapPageState createState() => _MapPageState();
}

class _MapPageState extends State<MapPage> {
  Completer<GoogleMapController> _controller = Completer();
  @override
  Widget build(BuildContext context) {
    final CameraPosition unZoom = CameraPosition(
        target: LatLng(widget.selected.latitude, widget.selected.longitude),
        zoom: 6);
    final CameraPosition zoomed = CameraPosition(
        target: LatLng(widget.selected.latitude, widget.selected.longitude),
        zoom: 10);
    final List<Marker> markers = [
      Marker(
          markerId: MarkerId("mid"),
          position: LatLng(widget.selected.latitude, widget.selected.longitude))
    ];
    Future<void> _zoomIn() async {
      final GoogleMapController controller = await _controller.future;
      controller.animateCamera(CameraUpdate.newCameraPosition(zoomed));
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.selected.location,
          style: TextStyle(color: Colors.white),
        ),
        elevation: 0,
      ),
      body: Stack(
        children: [
          GoogleMap(
            mapType: MapType.normal,
            initialCameraPosition: unZoom,
            markers: markers.toSet(),
            onMapCreated: (GoogleMapController controller) {
              _controller.complete(controller);
              Future.delayed(Duration(milliseconds: 500), () => _zoomIn());
            },
          ),
          Positioned(
            child: Container(
              padding: EdgeInsets.all(8),
              color: Colors.white,
              height: 150,
              child: Column(
                children: [
                  Row(
                    children: [
                      Container(
                        height: 50,
                        width: 50,
                        decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(50),
                            color: Colors.red),
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                "1.2",
                                style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold),
                              )
                            ],
                          ),
                        ),
                      ),
                      SizedBox(
                        width: 45,
                      ),
                      Text("Richter Ölçeği",
                          style: TextStyle(
                              color: Colors.red, fontWeight: FontWeight.bold))
                    ],
                  ),
                  Divider(),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      IconInfo(
                          icon: Icons.timer_outlined,
                          title: "Zaman",
                          desc: widget.selected.dateTime.toString()),
                      IconInfo(
                          icon: Icons.arrow_downward,
                          title: "Derinlik",
                          desc: widget.selected.depth.toString() + " km")
                    ],
                  )
                ],
              ),
            ),
            bottom: 0,
            left: 0,
            right: 0,
          )
        ],
      ),
    );
  }
}

class IconInfo extends StatelessWidget {
  final IconData icon;
  final String title;
  final String desc;
  const IconInfo({required this.icon, required this.title, required this.desc});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Icon(
          icon,
          size: 25,
        ),
        SizedBox(
          width: 10,
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
            ),
            Text(
              desc,
              style: TextStyle(fontSize: 12),
            )
          ],
        ),
      ],
    );
  }
}
