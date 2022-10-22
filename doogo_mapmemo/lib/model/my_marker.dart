import 'dart:ffi';

class MyMarker {
  final String timestamp;
  final double lat;
  final double lng;
  final String memo;

  MyMarker({
    required this.timestamp,
    required this.lat,
    required this.lng,
    required this.memo
  });

  Map<String, dynamic> toJson() => {
    'current': timestamp,
    'lat': lat,
    'lng': lng,
    'memo': memo
  };
}