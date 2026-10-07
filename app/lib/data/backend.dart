import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:uuid/uuid.dart';

import '../core/env.dart';
import '../domain/models.dart';

abstract class Backend {
  Stream<List<Restaurant>> watchRestaurants(String region, RestaurantSort sort);
  Stream<Restaurant?> watchRestaurant(String id);
  Stream<List<Review>> watchReviews(String restaurantId, ReviewSort sort);
  Stream<AppUser?> watchUser(String uid);
  Stream<List<Review>> watchUserReviews(String uid);
  Future<Map<String, Restaurant>> getRestaurants(List<String> ids);
  Future<Crown?> getCrown(String region, String month);
  Future<List<PlaceResult>> searchPlaces(String query, {double? lat, double? lng});
  Future<String> uploadImage(String folder, Uint8List bytes, String contentType);
  Future<String> submitReview(SubmitInput input);
  Stream<bool> watchLiked(String reviewId);
  Future<void> setLike(String reviewId, bool on);
  Future<void> report(String reviewId, String reason);
  Future<String> downloadUrl(String path);
}

class FirebaseBackend implements Backend {
  FirebaseFirestore get _db => FirebaseFirestore.instance;
  FirebaseFunctions get _fn => FirebaseFunctions.instanceFor(region: functionsRegion);
  String get _uid => FirebaseAuth.instance.currentUser!.uid;

  @override
  Stream<List<Restaurant>> watchRestaurants(String region, RestaurantSort sort) => _db
      .collection('restaurants')
      .where('region', isEqualTo: region)
      .orderBy(sort == RestaurantSort.real ? 'realScore' : 'bubble', descending: true)
      .snapshots()
      .map((s) => [for (final d in s.docs) Restaurant.fromMap(d.id, d.data())]);

  @override
  Stream<Restaurant?> watchRestaurant(String id) =>
      _db.doc('restaurants/$id').snapshots().map((s) => s.exists ? Restaurant.fromMap(s.id, s.data()!) : null);

  @override
  Stream<List<Review>> watchReviews(String restaurantId, ReviewSort sort) => _db
      .collection('reviews')
      .where('restaurantId', isEqualTo: restaurantId)
      .orderBy(sort == ReviewSort.likes ? 'likeCount' : 'createdAt', descending: true)
      .snapshots()
      .map((s) => [for (final d in s.docs) Review.fromMap(d.id, d.data())]);

  @override
  Stream<List<Review>> watchUserReviews(String uid) => _db
      .collection('reviews')
      .where('uid', isEqualTo: uid)
      .orderBy('createdAt', descending: true)
      .snapshots()
      .map((s) => [for (final d in s.docs) Review.fromMap(d.id, d.data())]);

  @override
  Stream<AppUser?> watchUser(String uid) =>
      _db.doc('users/$uid').snapshots().map((s) => s.exists ? AppUser.fromMap(s.id, s.data()!) : null);

  @override
  Future<Map<String, Restaurant>> getRestaurants(List<String> ids) async {
    final snaps = await Future.wait(ids.map((id) => _db.doc('restaurants/$id').get()));
    return {
      for (final s in snaps)
        if (s.exists) s.id: Restaurant.fromMap(s.id, s.data()!)
    };
  }

  @override
  Future<Crown?> getCrown(String region, String month) async {
    final s = await _db.doc('crowns/${month}_$region').get();
    if (!s.exists) return null;
    final c = Crown.fromMap(s.data()!);
    return c.isConfirmed ? c : null;
  }

  @override
  Future<List<PlaceResult>> searchPlaces(String query, {double? lat, double? lng}) async {
    final res = await _fn.httpsCallable('searchPlaces').call({
      'query': query,
      if (lat != null && lng != null) ...{'lat': lat, 'lng': lng},
    });
    return [for (final e in res.data as List) PlaceResult.fromMap(Map<String, dynamic>.from(e as Map))];
  }

  @override
  Future<String> uploadImage(String folder, Uint8List bytes, String contentType) async {
    final path = '$folder/$_uid/${const Uuid().v4()}.jpg';
    await FirebaseStorage.instance.ref(path).putData(bytes, SettableMetadata(contentType: contentType));
    return path;
  }

  @override
  Future<String> submitReview(SubmitInput input) async {
    final res = await _fn.httpsCallable('submitReview').call(input.toMap());
    return (res.data as Map)['reviewId'] as String;
  }

  @override
  Stream<bool> watchLiked(String reviewId) => _db.doc('reviews/$reviewId/likes/$_uid').snapshots().map((s) => s.exists);

  @override
  Future<void> setLike(String reviewId, bool on) {
    final ref = _db.doc('reviews/$reviewId/likes/$_uid');
    return on ? ref.set({'createdAt': FieldValue.serverTimestamp()}) : ref.delete();
  }

  @override
  Future<void> report(String reviewId, String reason) => _db.collection('reports').add({
        'reviewId': reviewId,
        'reporterUid': _uid,
        'reason': reason,
        'createdAt': FieldValue.serverTimestamp(),
      });

  @override
  Future<String> downloadUrl(String path) => FirebaseStorage.instance.ref(path).getDownloadURL();
}
