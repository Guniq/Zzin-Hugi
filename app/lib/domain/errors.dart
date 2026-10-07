import '../core/regions.dart';

final _messages = {
  'place_not_found': '식당 정보를 찾을 수 없어요. 다시 검색해 주세요.',
  'out_of_region': '아직 베타 지역이 아니에요. ${betaRegions.first.name}에서 먼저 만나요!',
  'daily_limit': '하루에 쓸 수 있는 후기는 5개예요. 내일 다시 써 주세요.',
  'ocr_unavailable': '영수증 확인 서버가 바빠요. 잠시 후 다시 시도해 주세요. 작성한 내용은 그대로예요.',
  'unreadable': '영수증을 읽지 못했어요. 글씨가 잘 보이게 다시 찍어 주세요.',
  'store_mismatch': '영수증의 가게가 선택한 식당과 달라요. 해당 식당의 영수증을 올려 주세요.',
  'date_expired': '영수증 날짜가 달라요. 방문 후 30일 이내의 영수증만 쓸 수 있어요.',
  'duplicate': '이미 사용된 영수증이에요.',
  'kakao_unavailable': '식당 검색이 잠시 안 돼요. 잠시 후 다시 시도해 주세요.',
  'login_required': '로그인이 필요해요.',
  'no_user': '프로필을 만드는 중이에요. 잠시 후 다시 시도해 주세요.',
};

const _fields = {'placeId', 'receiptPath', 'tier', 'rankIndex', 'eventJoined', 'eventStars', 'text', 'photos', 'query'};

String reviewErrorText(String? message) {
  if (message != null && _messages.containsKey(message)) return _messages[message]!;
  if (message != null && _fields.contains(message)) return '입력값을 확인해 주세요. ($message)';
  return '알 수 없는 오류가 발생했어요. 잠시 후 다시 시도해 주세요.';
}
