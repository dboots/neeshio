import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../models/locations.dart' as Locations;
import '../models/place_list.dart';

class MarkerService {
  // Convert an Office to a Marker
  Marker createMarkerFromOffice({
    required Locations.Office office,
    required Function(Locations.Office) onTap,
  }) {
    return Marker(
      markerId: MarkerId(office.id),
      position: LatLng(office.lat, office.lng),
      // Remove info window to prioritize drawer opening
      infoWindow: const InfoWindow(),
      onTap: () => onTap(office),
    );
  }

  // Convert a Place to a Marker
  Marker createMarkerFromPlace({
    required Place place,
    required Function(Place) onTap,
  }) {
    return Marker(
      markerId: MarkerId(place.id),
      position: LatLng(place.lat, place.lng),
      // Remove info window to prioritize drawer opening
      infoWindow: const InfoWindow(),
      onTap: () => onTap(place),
    );
  }

  // Create markers from a list of offices
  Set<Marker> createMarkersFromOffices({
    required List<Locations.Office> offices,
    required Function(Locations.Office) onTap,
  }) {
    return offices
        .map((office) => createMarkerFromOffice(
              office: office,
              onTap: onTap,
            ))
        .toSet();
  }

  // Create markers from a list of places
  Set<Marker> createMarkersFromPlaces({
    required List<Place> places,
    required Function(Place) onTap,
  }) {
    return places
        .map((place) => createMarkerFromPlace(
              place: place,
              onTap: onTap,
            ))
        .toSet();
  }
}
