import 'dart:async';

import 'package:background_location_tracker/background_location_tracker.dart'
    as bg;
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;

// class Repo {
//   static Repo? _instance;

//   Repo._();

//   factory Repo() => _instance ??= Repo._();

//   Future<void> update(bg.BackgroundLocationUpdateData data) async {
//     // final text = 'Location Update: Lat: ${data.lat} Lon: ${data.lon}';
//     // print(text); // ignore: avoid_print
//     // sendNotification(text);
//     // await LocationDao().saveLocation(data);
//   }
// }

@pragma('vm:entry-point')
void backgroundCallback() {
  bg.BackgroundLocationTrackerManager.handleBackgroundUpdated(
    (data) async => print("ddd"),
    //  Repo().update(data),
  );
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await bg.BackgroundLocationTrackerManager.initialize(
    backgroundCallback,
    config: const bg.BackgroundLocationTrackerConfig(
      loggingEnabled: true,
      androidConfig: bg.AndroidConfig(
        notificationIcon: 'explore',
        trackingInterval: Duration(seconds: 5),
        distanceFilterMeters: null,
      ),
      iOSConfig: bg.IOSConfig(
        activityType: bg.ActivityType.AUTOMOTIVE,
        distanceFilterMeters: null,
        restartAfterKill: true,
      ),
    ),
  );

  runApp(const SenderApp());
}

class SenderApp extends StatefulWidget {
  const SenderApp({super.key});

  @override
  _SenderAppState createState() => _SenderAppState();
}

class _SenderAppState extends State<SenderApp> {
  Position? _currentPosition;
  IO.Socket? socket;

  var isTracking = false;

  Timer? _timer;

  Future<void> _getTrackingStatus() async {
    isTracking = await bg.BackgroundLocationTrackerManager.isTracking();
    setState(() {});
    await bg.BackgroundLocationTrackerManager.startTracking();
  }

  @override
  void initState() {
    super.initState();
    _getTrackingStatus();
    _getCurrentLocation();
    initSocket();
    startSendingLocation();
  }

  @override
  void dispose() {
    _timer?.cancel();
    // socket?.disconnect();
    super.dispose();

    print("close");
  }

  void initSocket() {
    socket = IO.io('http://127.0.0.1:3000', <String, dynamic>{
      'transports': ['websocket'],
      'forceNew': true,
    });

    socket?.onConnect((_) {
      print('Connected to server');
    });

    socket?.onError((err) {
      print('onError: ${err.toString()}');
      if (err.toString().contains('timeout')) {
        print('Connection timeout. Check server availability.');
      }
    });

    socket?.onDisconnect((_) {
      print('Disconnected from server');
    });
  }

  void startSendingLocation() {
    Timer.periodic(const Duration(seconds: 5), (Timer timer) async {
      _getCurrentLocation();

      if (_currentPosition != null) {
        // Send location data to the server
        socket?.emit('location', {
          'latitude': _currentPosition?.latitude,
          'longitude': _currentPosition?.longitude,
        });
        print(
            'Location sent to server: ${_currentPosition?.latitude}, ${_currentPosition?.longitude}');
      } else {
        print('Location is null');
      }
    });
  }

  void _getCurrentLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        print('Location services disabled');
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        print('Location permission denied');
        return;
      }

      Position position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high);
      setState(() {
        _currentPosition = position;
      });
    } catch (e) {
      print(e);
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          backgroundColor: Colors.green,
          title: const Text('Sender App'),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: Column(
              // mainAxisAlignment: MainAxisAlignment.center,
              children: const [
                Text('Sending Location...'),

                // MaterialButton(
                //   onPressed: isTracking
                //       ? null
                //       : () async {
                //     await bg.BackgroundLocationTrackerManager
                //         .startTracking();
                //     setState(() => isTracking = true);
                //   },
                //   child: const Text('Start Tracking'),
                // ),
                // MaterialButton(
                //   onPressed:
                //       //  isTracking
                //       //     ?
                //       () async {
                //     // await LocationDao().clear();
                //     // await _getLocations();
                //     await bg.BackgroundLocationTrackerManager.stopTracking();
                //     socket?.disconnect;
                //     _timer?.cancel;
                //     isTracking = false;
                //     setState(() => isTracking = false);
                //   },
                //   // : null,
                //   child: const Text('Stop Tracking'),
                // ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
