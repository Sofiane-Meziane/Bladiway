import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:geocoding/geocoding.dart';

class MapsScreen extends StatefulWidget {
  final bool isForDeparture;
  final Function(String) onLocationSelected;
  final LatLng? initialDeparture;
  final LatLng? initialArrival;
  final bool showRoute;

  const MapsScreen({
    super.key,
    required this.isForDeparture,
    required this.onLocationSelected,
    this.initialDeparture,
    this.initialArrival,
    this.showRoute = false,
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

    // Initialize with provided locations if available
    if (widget.initialDeparture != null) {
      _departureLocation = widget.initialDeparture;
    }

    if (widget.initialArrival != null) {
      _arrivalLocation = widget.initialArrival;
    }

    // If both locations are provided and we should show the route, prepare to draw it
    if (widget.showRoute &&
        widget.initialDeparture != null &&
        widget.initialArrival != null) {
      Future.delayed(Duration.zero, () {
        _setupInitialMarkersAndRoute();
      });
    } else {
      _requestLocationPermission();
    }
  }

  void _setupInitialMarkersAndRoute() {
    if (_departureLocation != null) {
      _addMarker(
        _departureLocation!,
        'Point de Départ',
        BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
      );
    }

    if (_arrivalLocation != null) {
      _addMarker(
        _arrivalLocation!,
        'Point d\'Arrivée',
        BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
      );
    }

    if (_departureLocation != null && _arrivalLocation != null) {
      _getPolylinePoints();

      // Fit the map to show both markers
      if (_mapController != null) {
        LatLngBounds bounds = LatLngBounds(
          southwest: LatLng(
            _departureLocation!.latitude < _arrivalLocation!.latitude
                ? _departureLocation!.latitude
                : _arrivalLocation!.latitude,
            _departureLocation!.longitude < _arrivalLocation!.longitude
                ? _departureLocation!.longitude
                : _arrivalLocation!.longitude,
          ),
          northeast: LatLng(
            _departureLocation!.latitude > _arrivalLocation!.latitude
                ? _departureLocation!.latitude
                : _arrivalLocation!.latitude,
            _departureLocation!.longitude > _arrivalLocation!.longitude
                ? _departureLocation!.longitude
                : _arrivalLocation!.longitude,
          ),
        );

        _mapController!.animateCamera(
          CameraUpdate.newLatLngBounds(bounds, 100),
        );
      }
    }
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
    setState(() {
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
    });
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
        setState(() {
          _markers.removeWhere(
            (marker) =>
                (widget.isForDeparture &&
                    marker.markerId.value.contains('Départ')) ||
                (!widget.isForDeparture &&
                    marker.markerId.value.contains('Arrivée')),
          );
        });

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
    setState(() {
      _markers.removeWhere(
        (marker) =>
            (widget.isForDeparture &&
                marker.markerId.value.contains('Départ')) ||
            (!widget.isForDeparture &&
                marker.markerId.value.contains('Arrivée')),
      );
    });

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
  }

  Future<void> _getPolylinePoints() async {
    if (_departureLocation == null || _arrivalLocation == null) return;

    try {
      List<LatLng> polylineCoordinates = [];

      // Amélioration: Ajouter des points intermédiaires pour créer un chemin plus réaliste
      // Calculer la distance entre les points
      double latDiff =
          _arrivalLocation!.latitude - _departureLocation!.latitude;
      double lngDiff =
          _arrivalLocation!.longitude - _departureLocation!.longitude;

      // Créer 8 points intermédiaires pour une courbe plus lisse
      for (int i = 0; i <= 8; i++) {
        double fraction = i / 8;
        double lat = _departureLocation!.latitude + (latDiff * fraction);
        double lng = _departureLocation!.longitude + (lngDiff * fraction);

        // Ajouter un léger décalage aléatoire pour les points intermédiaires (pas le premier ni le dernier)
        if (i > 0 && i < 8) {
          // Calculer un décalage proportionnel à la distance totale
          double maxOffset = 0.005; // Ajuster selon vos besoins
          double randomOffset = (maxOffset * (0.5 - (i % 2 == 0 ? 0.3 : -0.3)));

          // Appliquer le décalage perpendiculairement à la direction du trajet
          lat += randomOffset * (lngDiff / (latDiff.abs() + lngDiff.abs()));
          lng += randomOffset * (latDiff / (latDiff.abs() + lngDiff.abs()));
        }

        polylineCoordinates.add(LatLng(lat, lng));
      }

      setState(() {
        _polylines.clear();
        _polylines.add(
          Polyline(
            polylineId: const PolylineId('route'),
            color: Theme.of(context).colorScheme.primary,
            points: polylineCoordinates,
            width: 5,
            patterns: [
              PatternItem.dash(20),
              PatternItem.gap(10),
            ], // Ligne pointillée pour un effet de chemin
          ),
        );
      });

      print(
        "Created a polyline with intermediate points between departure and arrival",
      );
    } catch (e) {
      print("Error creating polyline: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          widget.isForDeparture
              ? 'Sélectionner le départ'
              : 'Sélectionner l\'arrivée',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
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
              if (widget.showRoute &&
                  widget.initialDeparture != null &&
                  widget.initialArrival != null) {
                _setupInitialMarkersAndRoute();
              } else if (!widget.isForDeparture && _arrivalLocation == null) {
                // If selecting arrival and we don't have any markers yet
                _getCurrentLocation();
              }
            },
            markers: _markers,
            polylines: _polylines,
            onTap:
                widget.showRoute
                    ? null
                    : _onMapTap, // Disable tap if just viewing
            mapType: MapType.normal,
            myLocationEnabled: true,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
            compassEnabled: true,
          ),
          // Search bar at the top
          if (!widget.showRoute) // Hide search if just viewing
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
          if (!widget.showRoute) // Hide confirmation if just viewing
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

          SizedBox(
            height: widget.showRoute ? 20 : 100,
          ), // Adjust space for bottom panel
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
