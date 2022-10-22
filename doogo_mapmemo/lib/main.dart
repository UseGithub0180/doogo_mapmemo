import 'dart:convert';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:for_jaeheon/model/my_marker.dart';
import 'package:for_jaeheon/take_picture_screen.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:location/location.dart';

import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'dart:math';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {

  final Future<FirebaseApp> _initialization = Firebase.initializeApp();
  late GoogleMapController mapController;
  final TextEditingController _textEditingController = TextEditingController();

  late double lat = 37.5666805;
  late double lng = 126.9784147;
  Map<MarkerId, Marker> markers = <MarkerId, Marker>{};
  Location location = Location();
  late bool _serviceEnabled;
  late PermissionStatus _permissionGranted;
  String memoValue = '';
  LatLng _center = const LatLng(37.5666805, 126.9784147);
  List<String> markerList = [];

  void _onMapCreated(GoogleMapController controller) {
    mapController = controller;
  }

  _markAll() async {
    await for (var myMarkers in FirebaseFirestore.instance.collection('markers-v5').snapshots()) {
      for (var marker in myMarkers.docs.toList()) {
        setState(() {
          print(marker);
          Marker tempMarker = Marker(
            markerId: MarkerId(marker['current']),
            position: LatLng(marker['lat'], marker['lng']),
            infoWindow: const InfoWindow(
              title: '최근 제보 위치',
              snippet: '불편사항 제보 위치입니다.'
            )
          );
          markers[MarkerId(marker['current'])] = tempMarker;
        });
      }
    }
  }

  _locateMe() async {
    _serviceEnabled = await location.serviceEnabled();
    if (!_serviceEnabled) {
      _serviceEnabled = await location.requestService();
      if (!_serviceEnabled) {
        return;
      }
    }

    _permissionGranted = await location.hasPermission();
    if (_permissionGranted == PermissionStatus.denied) {
      _permissionGranted = await location.requestPermission();
      if (_permissionGranted != PermissionStatus.granted) {
        return;
      }
    }

    // Track user Movements
    location.onLocationChanged.listen((res) {
      setState(() {
        lat = res.latitude!;
        lng = res.longitude!;
        _center = LatLng(lat, lng);
      });
    });
  }

  // 메모하기 버튼을 눌렀을 때, AlertDialog 띄운다.
  _onCallMemo(BuildContext context) {
    showDialog(context: context, builder: (context) {
      return AlertDialog(
        title: Text("메모하기"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Column(
              children: [
                Text("정확한 위도: ${lat.toStringAsFixed(5)}"),
                const SizedBox(height: 10.0),
                Text("정확한 경도: ${lng.toStringAsFixed(5)}"),
                TextField(
                  onChanged: (value) {
                    setState(() {
                      memoValue = value;
                    });
                  },
                  controller: _textEditingController,
                  decoration: const InputDecoration(
                    hintText: "메모하고 싶은 내용을 적으세요."
                  ),
                )
              ],
            )
          ],
        ),
        actions: [
          TextButton(
            style: TextButton.styleFrom(
              backgroundColor: Colors.red
            ),
            onPressed: () {
              setState(() {
                Navigator.pop(context);
              });
            },
            child: const Text("취소", style: TextStyle(color: Colors.white))
          ),
          ElevatedButton(
              style: TextButton.styleFrom(
                  backgroundColor: Colors.green[700]
              ),
              onPressed: () async {
                // 메모 로직 작성

                final prefs = await SharedPreferences.getInstance();
                String? myUuid = prefs.getString('my_uuid');

                print(myUuid);

                final marker = Marker(
                    markerId: MarkerId(DateTime.now().millisecondsSinceEpoch.toString()),
                    position: LatLng(lat, lng),
                    infoWindow: const InfoWindow(
                        title: '최근 제보 위치',
                        snippet: '불편사항 제보 위치입니다.'
                    )
                );

                CollectionReference firebaseMarkers = FirebaseFirestore.instance.collection('markers-v5');

                MyMarker myMarker = MyMarker(
                    timestamp: DateTime.now().millisecondsSinceEpoch.toString(),
                    lat: lat,
                    lng: lng,
                    memo: memoValue
                );

                firebaseMarkers.doc(myUuid).set(myMarker.toJson());

                setState(() {
                  memoValue = '';
                  markers[MarkerId(DateTime.now().millisecondsSinceEpoch.toString())] = marker;
                });

                Navigator.of(context).pop();
              },
              child: const Text("저장", style: TextStyle(color: Colors.white))
          ),
          ElevatedButton(
              style: TextButton.styleFrom(
                  backgroundColor: Colors.green[700]
              ),
              onPressed: () {
                // 사진 찍는 로직
                _getCamera(context);
              },
              child: const Text("사진찍기", style: TextStyle(color: Colors.white))
          ),
        ],
      );
    });
  }

  _saveMe() async {
    final prefs = await SharedPreferences.getInstance();
    String? myUuid = prefs.getString('my_uuid');

    if (myUuid == null) {
      String generateRandomString(int len) {
        var r = Random();
        String randomString =String.fromCharCodes(List.generate(len, (index)=> r.nextInt(33) + 89));
        return randomString;
      }
      prefs.setString('my_uuid', generateRandomString(16));
    }

  }

  _getCamera(BuildContext context) async {
    // Obtain a list of the available cameras on the device.
    final cameras = await availableCameras();

    // Get a specific camera from the list of available cameras.
    final firstCamera = cameras.first;

    if (!mounted) return;

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => TakePictureScreen(
          camera: firstCamera,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: FutureBuilder(
        future: _initialization,
        builder: (context, snapshot) {

          if (snapshot.hasError) {
            print("Something went wrong");
          }

          if (snapshot.connectionState == ConnectionState.done) {
            _markAll();
            return Scaffold(
                appBar: AppBar(
                  title: const Text('이륜차 사고 추적 앱'),
                  backgroundColor: Colors.green[700],
                ),
                body: Column(
                  children: [
                    Expanded(child: GoogleMap(
                      onMapCreated: _onMapCreated,
                      initialCameraPosition: CameraPosition(
                        target: _center,
                        zoom: 11.0,
                      ),
                      markers: Set<Marker>.of(markers.values),
                    )),
                    Container(
                      width: double.infinity,
                      height: 60.0,
                      color: Colors.green[700],
                      child: Row(
                        children: [
                          Padding(
                              padding: const EdgeInsets.all(12.0),
                              child: Row(
                                children: [
                                  Text("위도: ${lat.toStringAsFixed(1)}", style: TextStyle(color: Colors.white)),
                                  Container(width: 10.0),
                                  Text("경도: ${lng.toStringAsFixed(1)}", style: TextStyle(color: Colors.white))
                                ],
                              )
                          ),
                          Expanded(child: Container()),
                          Padding(
                            padding: const EdgeInsets.all(12.0),
                            child: ElevatedButton(
                              onPressed: () => _onCallMemo(context),
                              child: const Text('메모하기'),
                            ),
                          ),
                          Expanded(child: Container()),
                          Padding(
                            padding: const EdgeInsets.all(12.0),
                            child: ElevatedButton(
                              onPressed: () => _getCamera(context),
                              child: const Text('사진 찍기'),
                            ),
                          ),
                        ],
                      ),
                    )
                  ],
                )
            );
          }

          return const Center(
            child: CircularProgressIndicator(),
          );
        }
      )
    );
  }

  @override
  void initState() {
    super.initState();
    _locateMe();
    _saveMe();
    _markAll();
  }
}