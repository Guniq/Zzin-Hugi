import 'package:cloud_firestore/cloud_firestore.dart';

import 'score.dart';

double? _d(dynamic v) => (v as num?)?.toDouble();
int _i(dynamic v) => (v as num?)?.toInt() ?? 0;

enum RestaurantSort { real, bubble }

enum ReviewSort { likes, recent }

class PlaceResult {
  const PlaceResult({required this.placeId, required this.name, required this.address, this.region});
  final String placeId;
  final String name;
  final String address;
  final String? region;

  factory PlaceResult.fromMap(Map<String, dynamic> m) => PlaceResult(
        placeId: m['placeId'] as String,
        name: m['name'] as String,
        address: (m['address'] as String?) ?? '',
        region: m['region'] as String?,
      );
}

class Restaurant {
  const Restaurant({
    required this.id,
    required this.name,
    required this.address,
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
        region: m['region'] as String?,
        realScore: _d(m['realScore']),
        eventScore: _d(m['eventScore']),
        bubble: _d(m['bubble']),
        reviewCount: _i(m['reviewCount']),
        eventReviewCount: _i(m['eventReviewCount']),
      );

  PlaceResult toPlace() => PlaceResult(placeId: id, name: name, address: address, region: region);
}

class Review {
  const Review({
    required this.id,
    required this.uid,
    required this.restaurantId,
    required this.tier,
    required this.personalScore,
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
  final Tier tier;
  final double personalScore;
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
        tier: Tier.values.byName(m['tier'] as String),
        personalScore: _d(m['personalScore']) ?? 0,
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
    required this.ranking,
  });
  final String uid;
  final String nickname;
  final String title;
  final int likesReceived;
  final int verifiedReviewCount;
  final Map<Tier, List<String>> ranking;

  factory AppUser.fromMap(String uid, Map<String, dynamic> m) {
    final r = (m['ranking'] as Map?) ?? const {};
    return AppUser(
      uid: uid,
      nickname: (m['nickname'] as String?) ?? '',
      title: (m['title'] as String?) ?? '찐린이',
      likesReceived: _i(m['likesReceived']),
      verifiedReviewCount: _i(m['verifiedReviewCount']),
      ranking: {for (final t in Tier.values) t: List<String>.from((r[t.name] as List?) ?? const [])},
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
    required this.tier,
    required this.rankIndex,
    required this.eventJoined,
    this.eventStars,
    required this.text,
    required this.photos,
  });
  final String placeId;
  final String receiptPath;
  final Tier tier;
  final int rankIndex;
  final bool eventJoined;
  final int? eventStars;
  final String text;
  final List<String> photos;

  Map<String, dynamic> toMap() => {
        'placeId': placeId,
        'receiptPath': receiptPath,
        'tier': tier.name,
        'rankIndex': rankIndex,
        'eventJoined': eventJoined,
        'eventStars': eventStars,
        'text': text,
        'photos': photos,
      };
}
