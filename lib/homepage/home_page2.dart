import 'dart:async';
import 'dart:math';
import 'dart:typed_data';
import 'dart:ui';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:ionicons/ionicons.dart';
import 'package:location/location.dart';
import 'package:maps_launcher/maps_launcher.dart';
import 'package:searchfield/searchfield.dart';
import 'package:ngo/apptheme.dart';
import 'package:ngo/authentication/functions/firebase.dart';
import 'package:ngo/homepage/components/ngo_profile.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'components/get_location.dart';
import 'components/ngo_bottomsheet.dart';
import 'components/updatecamera.dart';

class HomePage2 extends StatefulWidget {
  const HomePage2({Key? key}) : super(key: key);

  @override
  State<HomePage2> createState() => _HomePage2State();
}

class _HomePage2State extends State<HomePage2>
    with AutomaticKeepAliveClientMixin<HomePage2> {
  final Set<Circle> _circles = {};
  final Set<Marker> _markers = {};
  GoogleMapController? _googleMapController;
  bool hasValue = false;
  List<LatLng> polyPoints = [];
  Set<Polyline> polyLines = {};
  var data;
  late var place;
  late double startLat;
  late double startLng;
  late double endLat;
  late double endLng;
  late LatLng destination;
  bool selected = false;
  Location currentLocation = Location();
  TextEditingController search = TextEditingController();
  final TextEditingController _id = TextEditingController();
  final TextEditingController _name = TextEditingController();
  final TextEditingController _address = TextEditingController();
  late BitmapDescriptor ngoIcon;
  late BitmapDescriptor myPos;
  late BitmapDescriptor area;
  List<SearchFieldListItem<String>> suggestions = [];
  late StreamSubscription _streamSubscription;
  var _initialCameraPosition = const CameraPosition(
    target: LatLng(20.5937, 78.9629),
    zoom: 0,
  );

  @override
  void initState() {
    super.initState();
    setmarker();
    getNgoDoc();
    getNGO();
    getAreas();
    getrequests();
  }

  Future<void> setmarker() async {
    ngoIcon = await getMapIcon('assets/homepage/marker/NGO2.png');
    area = await getMapIcon('assets/homepage/marker/Areas.png');
    myPos = await getMapIcon('assets/homepage/marker/mypos.png');
  }

  @override
  void dispose() {
    _googleMapController?.dispose();
    _streamSubscription.cancel();
    super.dispose();
  }

  Future<void> createHotAreas(id, name, address, latitude, longitude) async {
    FirebaseFirestore.instance.collection('HotAreas').doc().set({
      'address': address,
      'dislikes': 0,
      'id': id,
      'likes': 0,
      'latitude': latitude,
      'longitude': longitude,
      'name': name,
    });
    _circles.add(
      Circle(
        circleId: CircleId(id),
        center: LatLng(latitude, longitude),
        radius: 100,
        fillColor: Colors.purple.withOpacity(0.6),
        strokeColor: Colors.transparent,
      ),
    );
    var b = addAreasMarker(
      id,
      latitude,
      longitude,
      name,
      address,
      BitmapDescriptor.hueViolet,
      0,
      0,
    );
    _markers.add(b);
  }

  void getJsonData() async {
    NetworkHelper network = NetworkHelper(
      startLat: startLat,
      startLng: startLng,
      endLat: endLat,
      endLng: endLng,
    );

    try {
      data = await network.getData();
      LineString ls =
          LineString(data['features'][0]['geometry']['coordinates']);

      for (int i = 0; i < ls.lineString.length; i++) {
        polyPoints.add(LatLng(ls.lineString[i][1], ls.lineString[i][0]));
      }

      if (polyPoints.length == ls.lineString.length) {
        setPolyLines();
      }
    } catch (e) {
      Fluttertoast.showToast(
          msg: 'Response error please check your connection');
    }
  }

  Future<void> getAreas() async {
    FirebaseFirestore.instance.collection('HotAreas').get().then(
      (area) {
        for (int j = 0; j < area.docs.length; ++j) {
          Map<String, dynamic> data = area.docs[j].data();
          _circles.add(
            Circle(
              circleId: CircleId(data['id']),
              center: LatLng(data['latitude'], data['longitude']),
              radius: 100,
              fillColor: Colors.green.withOpacity(0.6),
              strokeColor: Colors.transparent,
            ),
          );
          var b = addAreasMarker(
              data['id'],
              data['latitude'],
              data['longitude'],
              data['name'],
              data['address'],
              BitmapDescriptor.hueViolet,
              data['likes'],
              data['dislikes']);
          _markers.add(b);
        }
      },
    );
  }

  Future getNgoDoc() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    final String? name = prefs.getString('Ngo');
    var selected = await FirebaseFirestore.instance
        .collection('NGO')
        .where('name', isEqualTo: name)
        .limit(1)
        .get();
    var newLocation = CameraPosition(
      target: LatLng(
        selected.docs.single.data()['latitude'],
        selected.docs.single.data()['longitude'],
      ),
      zoom: 16,
    );
    _googleMapController!.animateCamera(
      CameraUpdate.newCameraPosition(newLocation),
    );
    setState(() {
      _initialCameraPosition = newLocation;
      startLat = newLocation.target.latitude;
      startLng = newLocation.target.longitude;
    });
  }

  addAreasMarker(id, lat, long, name, address, marker, likes, dislikes) {
    return Marker(
        onTap: () {
          showAreaSheet(id, lat, long, name, address, startLat, startLng, likes,
              dislikes);
        },
        markerId: MarkerId('A$id'),
        position: LatLng(
          lat,
          long,
        ),
        icon: area);
  }

  void showAreaSheet(id, lat, long, name, address, double startLat,
      double startLng, likes, dislikes) {
    showModalBottomSheet(
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(30),
          topRight: Radius.circular(30),
        ),
      ),
      isScrollControlled: true,
      context: context,
      builder: (context) {
        return Wrap(
          children: [
            Column(
              mainAxisAlignment: MainAxisAlignment.start,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ListTile(
                  leading: Container(
                    width: 60,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(5),
                      image: const DecorationImage(
                        image: AssetImage('assets/homepage/marker/Areas.png'),
                      ),
                    ),
                  ),
                  title: Padding(
                    padding: const EdgeInsets.only(top: 8.5),
                    child: Text(
                      name,
                      style: AppTheme.title,
                    ),
                  ),
                  subtitle: Text(
                    address,
                    style: AppTheme.caption,
                  ),
                  trailing: Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: GestureDetector(
                      onTap: () async {
                        getDirection(startLat, startLng, lat, long);
                        await updateCameraLocation(
                            _initialCameraPosition.target,
                            destination,
                            _googleMapController!);
                        place = name;
                      },
                      child: Container(
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.black),
                          borderRadius: BorderRadius.circular(50),
                        ),
                        child: const Icon(
                          CupertinoIcons.arrow_turn_right_up,
                          color: Colors.black,
                        ),
                      ),
                    ),
                  ),
                ),
                const Divider(),
                const ListTile(
                  title: Text(
                    'Helping those in need can make you feel more content and fulfilled.',
                    style: AppTheme.subtitle,
                  ),
                ),
                SizedBox(
                  height: 80,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(width: 10),
                      const Text('Users Review', style: AppTheme.title),
                      const Spacer(),
                      Column(
                        children: [
                          IconButton(
                            onPressed: () {},
                            icon: const Icon(CupertinoIcons.hand_thumbsup),
                            splashColor: Colors.green.withOpacity(0.5),
                            splashRadius: 25,
                          ),
                          Text(likes.toString())
                        ],
                      ),
                      const SizedBox(width: 20),
                      Column(
                        children: [
                          IconButton(
                            onPressed: () {},
                            icon: const Icon(CupertinoIcons.hand_thumbsdown),
                            splashColor: Colors.red.withOpacity(0.5),
                            splashRadius: 25,
                          ),
                          Text(dislikes.toString())
                        ],
                      ),
                      const SizedBox(width: 20),
                    ],
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  Future<BitmapDescriptor> getMapIcon(String iconPath) async {
    final Uint8List endMarker = await getBytesFromAsset(iconPath, 120);
    final icon = BitmapDescriptor.fromBytes(endMarker);
    return icon;
  }

  Future<Uint8List> getBytesFromAsset(String path, int width) async {
    ByteData data = await rootBundle.load(path);
    var codec = await instantiateImageCodec(data.buffer.asUint8List(),
        targetWidth: width);
    FrameInfo fi = await codec.getNextFrame();
    return (await fi.image.toByteData(format: ImageByteFormat.png))!
        .buffer
        .asUint8List();
  }

  // getJSON
  Future<String> getJsonFile(String path) async {
    return await rootBundle.loadString(path);
  }

  // Set Style
  void setMapStyle(String mapStyle) {
    _googleMapController!.setMapStyle(mapStyle);
  }

  Future<void> getrequests() async {
    FirebaseFirestore.instance
        .collection('donations')
        .get()
        .then((value) async {
      for (int i = 0; i < value.docs.length; ++i) {
        Map<String, dynamic> data = value.docs[i].data();
        String ngoDocumentId = value.docs[i].id;
        final getcoordinates = data["pickupCoordinates"].split(',');
        var a = Marker(
          markerId: MarkerId(ngoDocumentId),
          position: LatLng(
            double.parse(getcoordinates[0]),
            double.parse(getcoordinates[1]),
          ),
          icon: await _getAssetIcon(
                  context, 'assets/homepage/marker/marker-1.png')
              .then((value) => value),
        );
        _markers.add(a);
      }
    });
  }

  Future<BitmapDescriptor> _getAssetIcon(
      BuildContext context, String icon) async {
    final Completer<BitmapDescriptor> bitmapIcon =
        Completer<BitmapDescriptor>();
    final ImageConfiguration config =
        createLocalImageConfiguration(context, size: const Size(5, 5));

    AssetImage(icon)
        .resolve(config)
        .addListener(ImageStreamListener((ImageInfo image, bool sync) async {
      final ByteData? bytes =
          await image.image.toByteData(format: ImageByteFormat.png);
      final BitmapDescriptor bitmap =
          BitmapDescriptor.fromBytes(bytes!.buffer.asUint8List());
      bitmapIcon.complete(bitmap);
    }));

    return await bitmapIcon.future;
  }

  void getNGO() async {
    FirebaseFirestore.instance.collection('NGO').get().then((value) {
      for (int i = 0; i < value.docs.length; ++i) {
        Map<String, dynamic> data = value.docs[i].data();
        String ngoDocumentId = value.docs[i].id;

        var a = addNgoMarker(
            data['id'],
            data['latitude'],
            data['longitude'],
            data['name'],
            data['address'],
            BitmapDescriptor.hueBlue,
            data['workingIn'],
            data['mobile'].toString(),
            data['email'],
            data['website'],
            ngoDocumentId);
        suggestions.add(SearchFieldListItem(data['name']));
        _markers.add(a);
      }
    });
  }

  showSheet(id, lat, long, name, address, workingIn, double startLat,
      double startLng, mobile, email, website, ngoDocumentId) {
    showModalBottomSheet(
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(30),
          topRight: Radius.circular(30),
        ),
      ),
      context: context,
      builder: (context) {
        return Wrap(
          children: [
            Column(
              mainAxisAlignment: MainAxisAlignment.start,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(
                  height: 10,
                ),
                ListTile(
                  leading: Container(
                    height: 80,
                    width: 60,
                    decoration: BoxDecoration(
                      color: AppTheme.grey,
                      border: Border.all(width: 1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Icon(
                      CupertinoIcons.house_fill,
                      color: Colors.white,
                    ),
                  ),
                  trailing: GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => NgoProfile(
                              permission: mode.read,
                              name: name,
                              email: email,
                              worksIn: workingIn,
                              mobile: mobile,
                              address: address,
                              ngoDocumentId: ngoDocumentId),
                        ),
                      );
                    },
                    child: const Icon(
                      CupertinoIcons.arrowtriangle_right,
                      color: Colors.black,
                    ),
                  ),
                  title: Text(
                    name,
                    style: AppTheme.title,
                  ),
                  subtitle: Text(
                    address,
                    style: AppTheme.subtitle,
                  ),
                ),
                const Divider(
                  color: Colors.grey,
                ),
                NGOdata(
                  heading: "Phone Number: ",
                  title: mobile,
                  icon: Ionicons.call_outline,
                ),
                const Divider(
                  color: Colors.grey,
                ),
                NGOdata(
                    heading: "Email: ",
                    title: email,
                    icon: Ionicons.mail_open_outline),
                const Divider(
                  color: Colors.grey,
                ),
                NGOdata(
                  heading: "Website: ",
                  title: website,
                  icon: Ionicons.planet_outline,
                ),
                const Divider(
                  color: Colors.grey,
                ),
                Padding(
                  padding: const EdgeInsets.only(left: 10, right: 10),
                  child: ListTile(
                    leading: const Icon(Ionicons.help_circle_outline),
                    title: Column(
                      mainAxisAlignment: MainAxisAlignment.start,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text("Works In: ", style: AppTheme.subtitle),
                        Text(
                          workingIn,
                          style: AppTheme.caption,
                          softWrap: true,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        )
                      ],
                    ),
                  ),
                ),
                const Divider(
                  color: Colors.grey,
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 3, bottom: 15),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      GestureDetector(
                        onTap: () async {
                          getDirection(startLat, startLng, lat, long);
                          await updateCameraLocation(
                              _initialCameraPosition.target,
                              destination,
                              _googleMapController!);
                          place = name;
                        },
                        child: Container(
                          width: 150,
                          height: 45,
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.redAccent),
                            borderRadius: BorderRadius.circular(50),
                          ),
                          child: const Center(
                            child: Text(
                              "Navigate",
                              style: TextStyle(
                                fontFamily: 'WorkSans',
                                fontSize: 17,
                                fontWeight: FontWeight.w600,
                                color: Colors.redAccent,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  addNgoMarker(id, lat, long, name, address, marker, workingIn, mobile, email,
      website, ngoDocumentId) {
    return Marker(
      onTap: () {
        showSheet(id, lat, long, name, address, workingIn, startLat, startLng,
            mobile, email, website, ngoDocumentId);
      },
      markerId: MarkerId('N$id'),
      position: LatLng(
        lat,
        long,
      ),
      icon: ngoIcon,
    );
  }

  setPolyLines() {
    Polyline polyline = Polyline(
      polylineId: const PolylineId('route'),
      color: Colors.blue,
      points: polyPoints,
    );
    polyLines.add(polyline);
    setState(() {});
  }

  double calculateDistance(lat1, lon1, lat2, lon2) {
    var p = 0.017453292519943295;
    var a = 0.5 -
        cos((lat2 - lat1) * p) / 2 +
        cos(lat1 * p) * cos(lat2 * p) * (1 - cos((lon2 - lon1) * p)) / 2;
    return 12742 * asin(sqrt(a));
  }

  void getDirection(startlat, startlng, lat, long) {
    setState(() {
      endLat = lat;
      endLng = long;
      destination = LatLng(endLat, endLng);
      selected = true;
      polyPoints = [];
      getJsonData();
    });
    Navigator.pop(context);
  }

  void searchandanimate(name) async {
    var selected = await FirebaseFirestore.instance
        .collection('NGO')
        .where('name', isEqualTo: name)
        .limit(1)
        .get();
    var newLocation = CameraPosition(
      target: LatLng(
        selected.docs.single.data()['latitude'],
        selected.docs.single.data()['longitude'],
      ),
      zoom: 16,
    );
    _googleMapController!.animateCamera(
      CameraUpdate.newCameraPosition(newLocation),
    );
    setState(() {
      endLat = newLocation.target.latitude;
      endLng = newLocation.target.longitude;
    });
  }

  void _addDestination(LatLng pos) {
    setState(
      () {
        _markers.add(
          Marker(
            markerId: const MarkerId("Here"),
            infoWindow: const InfoWindow(title: "Create at this location"),
            icon: BitmapDescriptor.defaultMarkerWithHue(
                BitmapDescriptor.hueViolet),
            position: pos,
          ),
        );
        showModalBottomSheet(
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(30),
              topRight: Radius.circular(30),
            ),
          ),
          context: context,
          builder: (context) {
            return Wrap(
              children: [
                Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      const Text(
                        'Create a Hot Area',
                        style: AppTheme.headline,
                      ),
                      const Divider(),
                      const SizedBox(
                        height: 10,
                      ),
                      TextFormField(
                        controller: _id,
                        decoration: InputDecoration(
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide:
                                  const BorderSide(color: Colors.black)),
                          focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide:
                                  const BorderSide(color: Colors.black)),
                          hintText: "ID",
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 20, vertical: 20),
                        ),
                      ),
                      const SizedBox(
                        height: 10,
                      ),
                      TextFormField(
                        controller: _name,
                        decoration: InputDecoration(
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide:
                                  const BorderSide(color: Colors.black)),
                          focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide:
                                  const BorderSide(color: Colors.black)),
                          hintText: "Name",
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 20, vertical: 20),
                        ),
                      ),
                      const SizedBox(
                        height: 10,
                      ),
                      TextFormField(
                        controller: _address,
                        decoration: InputDecoration(
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide:
                                  const BorderSide(color: Colors.black)),
                          focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide:
                                  const BorderSide(color: Colors.black)),
                          hintText: "Address",
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 20, vertical: 20),
                        ),
                      ),
                      const SizedBox(height: 10),
                      MaterialButton(
                        color: AppTheme.button,
                        onPressed: () {
                          createHotAreas(_id.text, _name.text, _address.text,
                              pos.latitude, pos.longitude);

                          Navigator.pop(context);
                        },
                        child: const Text(
                          "Create",
                          style: TextStyle(color: Colors.white),
                        ),
                      )
                    ],
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void showPinOnMap() {
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final _size = MediaQuery.of(context).size;
    return Scaffold(
      body: Stack(
        alignment: Alignment.topCenter,
        children: [
          const SizedBox(
            width: double.infinity - 20,
            height: 50,
            child: TextField(),
          ),
          GoogleMap(
            zoomControlsEnabled: false,
            rotateGesturesEnabled: false,
            tiltGesturesEnabled: false,
            initialCameraPosition: _initialCameraPosition,
            compassEnabled: false,
            cameraTargetBounds: CameraTargetBounds.unbounded,
            mapToolbarEnabled: false,
            onMapCreated: (controller) {
              _googleMapController = controller;
              showPinOnMap();
            },
            onLongPress: _addDestination,
            markers: _markers,
            circles: _circles,
            polylines: polyLines,
          ),
          selected
              ? Positioned(
                  top: 30,
                  child: Material(
                    borderRadius: BorderRadius.circular(10),
                    elevation: 6,
                    clipBehavior: Clip.antiAlias,
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.blueGrey,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        children: [
                          Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Text(
                              '${double.parse(calculateDistance(startLat, startLng, endLat, endLng).toStringAsFixed(2))} KM',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                          IconButton(
                            onPressed: () {
                              setState(() {
                                selected = false;
                                place = null;
                                polyLines.clear();
                              });
                            },
                            icon: const Icon(
                              Icons.clear_outlined,
                              color: Colors.white,
                            ),
                          )
                        ],
                      ),
                    ),
                  ),
                )
              : Positioned(
                  top: 30,
                  left: 10,
                  right: 10,
                  child: Container(
                    decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(30),
                        boxShadow: const [
                          BoxShadow(
                            offset: Offset(
                              1.0,
                              1.0,
                            ),
                            blurRadius: 2.0,
                          ), //BoxShadow
                          BoxShadow(
                            color: Colors.white,
                            offset: Offset(0.0, 0.0),
                            blurRadius: 0.0,
                            spreadRadius: 0.0,
                          ), //BoxShadow
                        ]),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 21),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          const CircleAvatar(
                            foregroundColor: Colors.black,
                            backgroundColor: Colors.white,
                            child: Icon(
                              CupertinoIcons.search,
                              size: 28,
                            ),
                          ),
                          Expanded(
                            flex: 2,
                            child: SearchField(
                                hasOverlay: false,
                                suggestionItemDecoration: const BoxDecoration(
                                  color: Colors.white,
                                ),
                                hint: 'Search For NGO / Organisation',
                                searchStyle: const TextStyle(
                                  fontSize: 16,
                                  color: Colors.black,
                                ),
                                searchInputDecoration: const InputDecoration(
                                  enabledBorder: OutlineInputBorder(
                                    borderSide: BorderSide(
                                      color: Colors.transparent,
                                    ),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderSide: BorderSide(
                                      color: Colors.transparent,
                                    ),
                                  ),
                                ),
                                maxSuggestionsInViewPort: 4,
                                itemHeight: 50,
                                suggestionsDecoration: const BoxDecoration(
                                  color: Colors.white,
                                ),
                                suggestions: suggestions,
                                onTap: (x) {
                                  FocusManager.instance.primaryFocus?.unfocus();
                                  return searchandanimate(x.searchKey);
                                }),
                          )
                        ],
                      ),
                    ),
                  ),
                )
        ],
      ),
      floatingActionButton: Wrap(
        direction: Axis.vertical,
        children: [
          if (selected)
            Container(
              margin: const EdgeInsets.all(10),
              child: FloatingActionButton(
                heroTag: "btn4",
                onPressed: () {
                  MapsLauncher.launchCoordinates(endLat, endLng, place);
                },
                child: const Icon(
                  (Icons.directions_run_rounded),
                ),
                backgroundColor: Colors.green[600],
              ),
            ),
          if (selected)
            Container(
              margin: const EdgeInsets.all(10),
              child: FloatingActionButton(
                heroTag: "btn3",
                child: const Icon(Icons.location_pin),
                backgroundColor: Colors.amber,
                onPressed: () => updateCameraLocation(
                    _initialCameraPosition.target,
                    destination,
                    _googleMapController!),
              ),
            ),
          Container(
            margin: const EdgeInsets.all(10),
            child: FloatingActionButton(
              heroTag: "btn2",
              child: const Icon(Icons.location_searching),
              onPressed: () => _googleMapController!.animateCamera(
                CameraUpdate.newCameraPosition(_initialCameraPosition),
              ),
            ),
          ),
          Container(
            margin: const EdgeInsets.all(10),
            child: FloatingActionButton(
              heroTag: "btn1",
              backgroundColor: Colors.deepPurple,
              child: const Icon(Icons.add_location_alt_outlined),
              onPressed: () {
                Fluttertoast.showToast(
                    msg: "Long Press on map to create hot area");
              },
            ),
          ),
          Container(
            margin: const EdgeInsets.all(10),
            child: FloatingActionButton(
              heroTag: "btn0",
              backgroundColor: Colors.red,
              child: const Icon(Icons.exit_to_app),
              onPressed: () {
                logout().then((value) async {
                  SharedPreferences prefs =
                      await SharedPreferences.getInstance();
                  prefs.remove('Ngo');
                  prefs.remove('userType');
                  Navigator.pushReplacementNamed(context, '/wrapper');
                });
              },
            ),
          ),
        ],
      ),
    );
  }

  @override
  bool get wantKeepAlive => true;
}

class LineString {
  LineString(this.lineString);
  List<dynamic> lineString;
}
