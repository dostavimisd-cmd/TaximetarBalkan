abstract class RideRepository {
  /// Započinje novu vožnju i vraća njen ID.
  Future<int> startRide(Map<String, dynamic> rideData);
  
  /// Ažurira trenutno stanje vožnje (snapshot) za oporavak.
  Future<void> updateSnapshot(Map<String, dynamic> snapshotData);
  
  /// Vraća poslednji snapshot nezavršene vožnje (ako postoji).
  Future<Map<String, dynamic>?> getUnfinishedRideSnapshot();
  
  /// Završava vožnju, upisuje konačne iznose i briše snapshot.
  Future<void> finishRide(int rideId, Map<String, dynamic> finalData);
}