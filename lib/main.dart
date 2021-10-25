import 'package:flutter/material.dart';
import 'package:flutter_blue/flutter_blue.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

const AndroidNotificationChannel channel = AndroidNotificationChannel(
    'high_importance_channel', // id
    'High Importance Notifications', // title
    'This channel is used for important notifications.', // description
    importance: Importance.high,
    playSound: true);

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
FlutterLocalNotificationsPlugin();

Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  print('A bg message just showed up :  ${message.messageId}');
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  await flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(channel);

  await FirebaseMessaging.instance.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
  );
  runApp(MyApp());
}

const String SERVICE_UUID = "0000FFE0-0000-1000-8000-00805F9B34FB";
const String CHARACTERISTIC_UUID = "0000FFE1-0000-1000-8000-00805F9B34FB";

bool equalsIc(String string1, String string2) {
  return string1?.toLowerCase() == string2?.toLowerCase();
}

BluetoothCharacteristic hm10NotifyCharacteristic;

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'DEMO',
    theme: ThemeData(
      primarySwatch: Colors.blue,
    ),
    home: HomeSc(title: 'Pet-Era'),
  );
}

class HomeSc extends StatefulWidget {
  HomeSc({Key key, this.title}) : super(key: key);
  final String title;
  final FlutterBlue flutterBlue = FlutterBlue.instance;
  final List<BluetoothDevice> devicesList = <BluetoothDevice>[];
  @override
  State<HomeSc> createState() => _HomeScState();
}

class _HomeScState extends State<HomeSc> {
  BluetoothDevice _connectedDevice;
  List<BluetoothService> _services;

  _addDeviceTolist(final BluetoothDevice device) {
    if (!widget.devicesList.contains(device)) {
      setState(() {
        widget.devicesList.add(device);
      });
    }
  }

  @override
  void initState() {
    super.initState();
    widget.flutterBlue.connectedDevices
        .asStream()
        .listen((List<BluetoothDevice> devices) {
      for (BluetoothDevice device in devices) {
        _addDeviceTolist(device);
      }
    });
    widget.flutterBlue.scanResults.listen((List<ScanResult> results) {
      for (ScanResult result in results) {
        _addDeviceTolist(result.device);
      }
    });
    widget.flutterBlue.startScan();
  }

  ListView _buildListViewOfDevices() {
    List<Container> containers = <Container>[];
    for (BluetoothDevice device in widget.devicesList) {
      containers.add(
        Container(
          height: 50,
          child: Row(
            children: <Widget>[
              Expanded(
                child: Column(
                  children: <Widget>[
                    Text(device.name == '' ? '(unknown device)' : device.name),
                    Text(device.id.toString()),
                  ],
                ),
              ),
              FlatButton(
                color: Colors.blue,
                child: Text(
                  'Connect',
                  style: TextStyle(color: Colors.white),
                ),
                onPressed: () async {
                  widget.flutterBlue.stopScan();
                  try {
                    await device.connect();
                  } catch (e) {
                    if (e != 'already_connected') {
                      throw e;
                    }
                  } finally {
                    _services = await device.discoverServices();
                    for (BluetoothService service in _services) {
                      for (BluetoothCharacteristic characteristic
                      in service.characteristics) {
                        if (equalsIc(service.uuid.toString(), SERVICE_UUID) &&
                            equalsIc(characteristic.uuid.toString(),
                                CHARACTERISTIC_UUID)) {
                          print("CHARACTERISTIC_UUID FOUND !");
                          hm10NotifyCharacteristic = characteristic;
                        }
                      }
                    }
                  }
                  setState(() {
                    _connectedDevice = device;
                  });
                  Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) =>
                              Bowl(_services, _connectedDevice)));
                },
              ),
            ],
          ),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(8),
      children: <Widget>[
        ...containers,
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[800],
      appBar: AppBar(
        title: Text(widget.title),
        centerTitle: true,
        backgroundColor: Colors.lightBlue[800],
        elevation: 1.0,
      ),
      body: _buildListViewOfDevices(),
    );
  }
}

class Bowl extends StatefulWidget {
  List<BluetoothService> serviceObject;
  BluetoothDevice deviceObject;
  Bowl(this.serviceObject, this.deviceObject);

  @override
  State<Bowl> createState() => _BowlState(serviceObject, deviceObject);
}

class _BowlState extends State<Bowl> {
  List<BluetoothService> serviceObject;
  BluetoothDevice deviceObject;
  _BowlState(this.serviceObject, this.deviceObject);

  Map<Guid, List<int>> readValues = Map<Guid, List<int>>();

  String waterLevel = " ";
  String foodLevel = " ";
  String waterAsset = " ";
  String foodAsset = " ";

  TextStyle foodLevelStyle, waterLevelStyle;

  @override
  void initState() {
    super.initState();
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      RemoteNotification notification = message.notification;
      AndroidNotification android = message.notification?.android;
      if (notification != null && android != null) {
        flutterLocalNotificationsPlugin.show(
            notification.hashCode,
            notification.title,
            notification.body,
            NotificationDetails(
              android: AndroidNotificationDetails(
                channel.id,
                channel.name,
                channel.description,
                color: Colors.blue,
                playSound: true,
                icon: '@mipmap/ic_launcher',
              ),
            ));
      }
    });
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      print('A new onMessageOpenedApp event was published!');
      RemoteNotification notification = message.notification;
      AndroidNotification android = message.notification?.android;
      if (notification != null && android != null) {
        showDialog(
            context: context,
            builder: (_) {
              return AlertDialog(
                title: Text(notification.title),
                content: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [Text(notification.body)],
                  ),
                ),
              );
            });
      }
    });
    setNotification(hm10NotifyCharacteristic);
  }
  void showNotificationWater() {

    flutterLocalNotificationsPlugin.show(
        0,
        "Pet-Era",
        "The water bowl is running low on water",
        NotificationDetails(
            android: AndroidNotificationDetails(channel.id, channel.name, channel.description,
                importance: Importance.high,
                color: Colors.blue,
                playSound: true,
                icon: '@mipmap/ic_launcher')));
  }

  void showNotificationFood() {

    flutterLocalNotificationsPlugin.show(
        0,
        "Pet-Era",
        "The food bowl is running low on food.",
        NotificationDetails(
            android: AndroidNotificationDetails(channel.id, channel.name, channel.description,
                importance: Importance.high,
                color: Colors.blue,
                playSound: true,
                icon: '@mipmap/ic_launcher')));
  }


  setNotification(BluetoothCharacteristic characteristic) async {
    print("SETTING NOTIFICATION FOR :");
    print(characteristic);
    characteristic.value.listen((value) {
      String s = new String.fromCharCodes(value);
      print(s);
      // s.split("");
      int foodLevelValue = int.parse(s[0]);
      setState(() {
        switch (foodLevelValue) {
          case 0:
            foodLevel = "Low";
            foodAsset = "images/food-low.png";
            foodLevelStyle = TextStyle(
              color: Colors.red[300],
              fontSize: 30.0,
              fontWeight: FontWeight.bold,
            );
            showNotificationFood();
            break;
          case 1:
            foodAsset = "images/food-medium.png";
            foodLevel = "Medium";
            foodLevelStyle = TextStyle(
              color: Colors.brown[300],
              fontSize: 30.0,
              fontWeight: FontWeight.bold,
            );
            break;
          case 2:
            foodAsset = "images/food-high.png";
            foodLevel = "High";
            foodLevelStyle = TextStyle(
              color: Colors.lightBlue[800],
              fontSize: 30.0,
              fontWeight: FontWeight.bold,
            );
            break;
          default:
        }
      });
      int waterLevelValue = int.parse(s[1]);
      setState(() {
        switch (waterLevelValue) {
          case 0:
            waterAsset = "images/water-low.png";
            waterLevel = "Low";
            waterLevelStyle = TextStyle(
              color: Colors.red[300],
              fontSize: 30.0,
              fontWeight: FontWeight.bold,
            );
            showNotificationWater();
            break;
          case 1:
            waterAsset = "images/water-medium.png";
            waterLevel = "Medium";
            waterLevelStyle = TextStyle(
              color: Colors.brown[300],
              fontSize: 30.0,
              fontWeight: FontWeight.bold,
            );
            break;
          case 2:
            waterAsset = "images/water-high.png";
            waterLevel = "High";
            waterLevelStyle = TextStyle(
              color: Colors.lightBlue[800],
              fontSize: 30.0,
              fontWeight: FontWeight.bold,
            );
            break;
          default:
        }
      });
    });
    await characteristic.setNotifyValue(true);
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[800],
      appBar: AppBar(
        title: Text('Pet-Era'),
        centerTitle: true,
        backgroundColor: Colors.lightBlue[800],
        elevation: 1.0,
        automaticallyImplyLeading: false,
      ),
      body: Padding(
        padding: EdgeInsets.fromLTRB(30.0, 30.0, 30.0, 0.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Image(
                  image: AssetImage(waterAsset)
                ),
                Image(
                  image: AssetImage(foodAsset)
                )
            ]
            ),

            Divider(
              height: 30.0,
              color: Colors.grey[600],
              thickness: 1.5,
            ),
            Text(
              "Water Level:",
              style: TextStyle(
                color: Colors.white,
                fontSize: 20.0,
              ),
            ),
            Text(waterLevel, style: waterLevelStyle),
            SizedBox(height: 35.0),
            Text(
              "Food Level:",
              style: TextStyle(
                color: Colors.white,
                fontSize: 20.0,
              ),
            ),
            Text(foodLevel, style: foodLevelStyle),
          ],
        ),
      ),
    );
  }
}
