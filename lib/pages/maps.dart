import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:geocoding/geocoding.dart';

class MapsScreen extends StatefulWidget {
  final bool isForDeparture;
  final Function(String) onLocationSelected;

  const MapsScreen({
    super.key,
    required this.isForDeparture,
    required this.onLocationSelected,
  });

  @override
  _MapsScreenState createState() => _MapsScreenState();
}

class _MapsScreenState extends State<MapsScreen> {
  GoogleMapController? _mapController;
  final Set<Marker> _markers = {};
  final Set<Polyline> _polylines = {};
  LatLng? _departureLocation;
  LatLng? _arrivalLocation;

  // Center of Algeria
  static const LatLng _algeriaCenter = LatLng(28.0339, 1.6596);

  // Search controllers
  final TextEditingController _searchController = TextEditingController();

  // For loading state
  bool _isLoading = false;

  // For address display
  String _selectedAddress = '';

  @override
  void initState() {
    super.initState();
    _requestLocationPermission();
  }

  Future<void> _requestLocationPermission() async {
    var status = await Permission.location.request();
    if (status.isGranted) {
      _getCurrentLocation();
    }
  }

  Future<void> _getCurrentLocation() async {
    setState(() {
      _isLoading = true;
    });

    try {
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      LatLng userLocation = LatLng(position.latitude, position.longitude);

      if (_mapController != null) {
        _mapController!.animateCamera(
          CameraUpdate.newCameraPosition(
            CameraPosition(target: userLocation, zoom: 12),
          ),
        );
      }

      // If this is for selecting departure and we don't have a departure marker yet
      if (widget.isForDeparture && _departureLocation == null) {
        _addMarker(
          userLocation,
          'Votre position actuelle',
          BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
        );
        _departureLocation = userLocation;
        _getAddressFromLatLng(userLocation);
      }
    } catch (e) {
      print("Error getting location: $e");
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _getAddressFromLatLng(LatLng position) async {
    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );

      if (placemarks.isNotEmpty) {
        Placemark place = placemarks[0];
        setState(() {
          _selectedAddress =
              '${place.locality}, ${place.administrativeArea}, ${place.country}';
        });
      }
    } catch (e) {
      print("Error getting address: $e");
    }
  }

  void _addMarker(LatLng position, String markerId, BitmapDescriptor icon) {
    _markers.add(
      Marker(
        markerId: MarkerId(markerId),
        position: position,
        icon: icon,
        infoWindow: InfoWindow(
          title: markerId,
          snippet: 'Lat: ${position.latitude}, Lng: ${position.longitude}',
        ),
      ),
    );
  }

  Future<void> _searchLocation() async {
    if (_searchController.text.isEmpty) return;

    setState(() {
      _isLoading = true;
    });

    try {
      // Add "Algeria" to the search query to focus results on Algeria
      String searchQuery = "${_searchController.text}, Algeria";
      List<Location> locations = await locationFromAddress(searchQuery);

      if (locations.isNotEmpty) {
        LatLng searchedLocation = LatLng(
          locations.first.latitude,
          locations.first.longitude,
        );

        if (_mapController != null) {
          _mapController!.animateCamera(
            CameraUpdate.newCameraPosition(
              CameraPosition(target: searchedLocation, zoom: 12),
            ),
          );
        }

        // Clear markers based on which location we're selecting
        _markers.removeWhere(
          (marker) =>
              (widget.isForDeparture &&
                  marker.markerId.value.contains('Départ')) ||
              (!widget.isForDeparture &&
                  marker.markerId.value.contains('Arrivée')),
        );

        // Add new marker
        if (widget.isForDeparture) {
          _departureLocation = searchedLocation;
          _addMarker(
            searchedLocation,
            'Point de Départ',
            BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
          );
        } else {
          _arrivalLocation = searchedLocation;
          _addMarker(
            searchedLocation,
            'Point d\'Arrivée',
            BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
          );
        }

        await _getAddressFromLatLng(searchedLocation);

        // Draw route if both markers are set
        if (_departureLocation != null && _arrivalLocation != null) {
          _getPolylinePoints();
        }
      }
    } catch (e) {
      print("Error searching location: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Emplacement non trouvé. Veuillez réessayer.')),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _onMapTap(LatLng position) async {
    // Clear markers based on which location we're selecting
    _markers.removeWhere(
      (marker) =>
          (widget.isForDeparture && marker.markerId.value.contains('Départ')) ||
          (!widget.isForDeparture && marker.markerId.value.contains('Arrivée')),
    );

    // Add new marker
    if (widget.isForDeparture) {
      _departureLocation = position;
      _addMarker(
        position,
        'Point de Départ',
        BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
      );
    } else {
      _arrivalLocation = position;
      _addMarker(
        position,
        'Point d\'Arrivée',
        BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
      );
    }

    await _getAddressFromLatLng(position);

    // Draw route if both markers are set
    if (_departureLocation != null && _arrivalLocation != null) {
      _getPolylinePoints();
    }

    setState(() {});
  }

  Future<void> _getPolylinePoints() async {
    if (_departureLocation == null || _arrivalLocation == null) return;

    try {
      List<LatLng> polylineCoordinates = [];

      // Draw a direct line instead of using the API
      polylineCoordinates.add(_departureLocation!);
      polylineCoordinates.add(_arrivalLocation!);

      setState(() {
        _polylines.clear();
        _polylines.add(
          Polyline(
            polylineId: const PolylineId('route'),
            color: Theme.of(context).colorScheme.primary,
            points: polylineCoordinates,
            width: 5,
          ),
        );
      });

      print("Created a direct polyline between points");
    } catch (e) {
      print("Error creating polyline: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.isForDeparture
              ? 'Sélectionner le départ'
              : 'Sélectionner l\'arrivée',
          style: TextStyle(color: Theme.of(context).colorScheme.onPrimary),
        ),
        centerTitle: true,
        backgroundColor: Theme.of(context).colorScheme.primary,
      ),
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: const CameraPosition(
              target: _algeriaCenter,
              zoom: 5.5,
            ),
            onMapCreated: (controller) {
              _mapController = controller;
              if (!widget.isForDeparture && _arrivalLocation == null) {
                // If selecting arrival and we don't have any markers yet
                _getCurrentLocation();
              }
            },
            markers: _markers,
            polylines: _polylines,
            onTap: _onMapTap,
            mapType: MapType.normal,
            myLocationEnabled: true,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
            compassEnabled: true,
          ),
          // Search bar at the top
          Positioned(
            top: 10,
            left: 10,
            right: 10,
            child: Container(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(5),
                boxShadow: [
                  BoxShadow(
                    color: Theme.of(context).shadowColor.withOpacity(0.5),
                    spreadRadius: 2,
                    blurRadius: 5,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Rechercher un lieu en Algérie',
                  prefixIcon: Icon(
                    Icons.search,
                    color: Theme.of(context).iconTheme.color,
                  ),
                  suffixIcon: IconButton(
                    icon: Icon(
                      Icons.clear,
                      color: Theme.of(context).iconTheme.color,
                    ),
                    onPressed: () => _searchController.clear(),
                  ),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 15,
                    vertical: 12,
                  ),
                ),
                onSubmitted: (_) => _searchLocation(),
              ),
            ),
          ),
          // Address display and confirm button at the bottom
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.all(15),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(20),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Theme.of(context).shadowColor.withOpacity(0.5),
                    spreadRadius: 5,
                    blurRadius: 7,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Adresse sélectionnée:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _selectedAddress.isNotEmpty
                        ? _selectedAddress
                        : 'Aucune adresse sélectionnée',
                    style: TextStyle(fontSize: 16),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 15),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      ElevatedButton.icon(
                        onPressed: _getCurrentLocation,
                        icon: Icon(
                          Icons.my_location,
                          color: Theme.of(context).colorScheme.onSecondary,
                        ),
                        label: Text(
                          'Ma position',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onSecondary,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor:
                              Theme.of(context).colorScheme.secondary,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                        ),
                      ),
                      ElevatedButton(
                        onPressed:
                            _selectedAddress.isNotEmpty
                                ? () {
                                  widget.onLocationSelected(_selectedAddress);
                                  Navigator.pop(context);
                                }
                                : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor:
                              Theme.of(context).colorScheme.primary,
                          foregroundColor:
                              Theme.of(context).colorScheme.onPrimary,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 30,
                            vertical: 12,
                          ),
                        ),
                        child: const Text(
                          'Confirmer',
                          style: TextStyle(fontSize: 16),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          // Loading indicator
          if (_isLoading)
            Container(
              color: Colors.black.withOpacity(0.3),
              child: Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(
                    Theme.of(context).colorScheme.primary,
                  ),
                ),
              ),
            ),
        ],
      ),
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          FloatingActionButton(
            heroTag: "zoomIn",
            mini: true,
            backgroundColor: Theme.of(context).colorScheme.surface,
            foregroundColor: Theme.of(context).colorScheme.onSurface,
            child: const Icon(Icons.add),
            onPressed: () {
              _mapController?.animateCamera(CameraUpdate.zoomIn());
            },
          ),
          const SizedBox(height: 8),
          FloatingActionButton(
            heroTag: "zoomOut",
            mini: true,
            backgroundColor: Theme.of(context).colorScheme.surface,
            foregroundColor: Theme.of(context).colorScheme.onSurface,
            child: const Icon(Icons.remove),
            onPressed: () {
              _mapController?.animateCamera(CameraUpdate.zoomOut());
            },
          ),
          const SizedBox(height: 8),
          FloatingActionButton(
            heroTag: "myLocation",
            backgroundColor: Theme.of(context).colorScheme.surface,
            foregroundColor: Theme.of(context).colorScheme.primary,
            onPressed: _getCurrentLocation,
            child: const Icon(Icons.my_location),
          ),
          const SizedBox(height: 100), // Space for the bottom panel
        ],
      ),
    );
  }

  @override
  void dispose() {
    _mapController?.dispose();
    _searchController.dispose();
    super.dispose();
  }
}
