import 'package:cloud_firestore/cloud_firestore.dart';

double? _d(dynamic v) => (v as num?)?.toDouble();
int _i(dynamic v) => (v as num?)?.toInt() ?? 0;

enum RestaurantSort { real, bubble }

enum ReviewSort { likes, recent }

class PlaceResult {
  const PlaceResult({required this.placeId, required this.name, required this.address, this.category = '', this.region, this.lat, this.lng, this.realScore, this.reviewCount = 0});
  final String placeId;
  final String name;
  final String address;
  final String category;
  final String? region;
  final double? lat;
  final double? lng;

  /// 이미 찐후기가 쌓인 식당이면 찐점수(3개 미만이면 null)와 후기 수. 지도 핀에 보여 준다.
  final double? realScore;
  final int reviewCount;

  factory PlaceResult.fromMap(Map<String, dynamic> m) => PlaceResult(
        placeId: m['placeId'] as String,
        name: m['name'] as String,
        address: (m['address'] as String?) ?? '',
        category: (m['category'] as String?) ?? '',
        region: m['region'] as String?,
        lat: _d(m['lat']),
        lng: _d(m['lng']),
        realScore: _d(m['realScore']),
        reviewCount: _i(m['reviewCount']),
      );
}

class Restaurant {
  const Restaurant({
    required this.id,
    required this.name,
    required this.address,
    this.category = '',
    this.region,
    this.realScore,
    this.eventScore,
    this.bubble,
    this.reviewCount = 0,
    this.eventReviewCount = 0,
  });
  final String id;
  final String name;
  final String address;
  final String category;
  final String? region;
  final double? realScore;
  final double? eventScore;
  final double? bubble;
  final int reviewCount;
  final int eventReviewCount;

  factory Restaurant.fromMap(String id, Map<String, dynamic> m) => Restaurant(
        id: id,
        name: m['name'] as String,
        address: (m['address'] as String?) ?? '',
        category: (m['category'] as String?) ?? '',
        region: m['region'] as String?,
        realScore: _d(m['realScore']),
        eventScore: _d(m['eventScore']),
        bubble: _d(m['bubble']),
        reviewCount: _i(m['reviewCount']),
        eventReviewCount: _i(m['eventReviewCount']),
      );

  PlaceResult toPlace() => PlaceResult(placeId: id, name: name, address: address, category: category, region: region);
}

class Review {
  const Review({
    required this.id,
    required this.uid,
    required this.restaurantId,
    required this.stars,
    required this.eventJoined,
    this.eventStars,
    required this.text,
    required this.photos,
    required this.visitDate,
    required this.likeCount,
    this.createdAt,
  });
  final String id;
  final String uid;
  final String restaurantId;
  /// 내 실제 별점 1~5
  final int stars;
  final bool eventJoined;
  final int? eventStars;
  final String text;
  final List<String> photos;
  final String visitDate;
  final int likeCount;
  final DateTime? createdAt;

  factory Review.fromMap(String id, Map<String, dynamic> m) => Review(
        id: id,
        uid: m['uid'] as String,
        restaurantId: m['restaurantId'] as String,
        stars: _i(m['stars']),
        eventJoined: (m['eventJoined'] as bool?) ?? false,
        eventStars: (m['eventStars'] as num?)?.toInt(),
        text: (m['text'] as String?) ?? '',
        photos: List<String>.from((m['photos'] as List?) ?? const []),
        visitDate: (m['visitDate'] as String?) ?? '',
        likeCount: _i(m['likeCount']),
        createdAt: (m['createdAt'] as Timestamp?)?.toDate(),
      );
}

class AppUser {
  const AppUser({
    required this.uid,
    required this.nickname,
    required this.title,
    required this.likesReceived,
    required this.verifiedReviewCount,
  });
  final String uid;
  final String nickname;
  final String title;
  final int likesReceived;
  final int verifiedReviewCount;

  factory AppUser.fromMap(String uid, Map<String, dynamic> m) {
    return AppUser(
      uid: uid,
      nickname: (m['nickname'] as String?) ?? '',
      title: (m['title'] as String?) ?? '찐린이',
      likesReceived: _i(m['likesReceived']),
      verifiedReviewCount: _i(m['verifiedReviewCount']),
    );
  }
}

class Crown {
  const Crown({required this.uid, required this.likes, required this.status});
  final String uid;
  final int likes;
  final String status;
  bool get isConfirmed => status == 'confirmed';

  factory Crown.fromMap(Map<String, dynamic> m) =>
      Crown(uid: m['uid'] as String, likes: _i(m['likes']), status: (m['status'] as String?) ?? 'pending');
}

class SubmitInput {
  const SubmitInput({
    required this.placeId,
    required this.receiptPath,
    required this.stars,
    required this.eventJoined,
    this.eventStars,
    required this.text,
    required this.photos,
  });
  final String placeId;
  final String receiptPath;
  final int stars;
  final bool eventJoined;
  final int? eventStars;
  final String text;
  final List<String> photos;

  Map<String, dynamic> toMap() => {
        'placeId': placeId,
        'receiptPath': receiptPath,
        'stars': stars,
        'eventJoined': eventJoined,
        'eventStars': eventStars,
        'text': text,
        'photos': photos,
      };
}
