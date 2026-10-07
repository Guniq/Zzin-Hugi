import { validateSubmitInput } from '../../src/review';

const base = {
  placeId: 'p1', receiptPath: 'receipts/u1/r.jpg', tier: 'best', rankIndex: 0,
  eventJoined: false, eventStars: null, text: '국물이 진하고 고기가 많아요', photos: [],
};
const bad = (patch: object, field: string) => {
  let err: unknown;
  try {
    validateSubmitInput('u1', { ...base, ...patch });
  } catch (e) {
    err = e;
  }
  expect(err).toMatchObject({ code: 'invalid-argument', message: field });
};

test('정상 입력은 trim된 값 반환', () => {
  expect(validateSubmitInput('u1', { ...base, text: '  국물이 진하고 고기가 많아요  ' }).text).toBe('국물이 진하고 고기가 많아요');
});
test('남의 영수증 경로', () => bad({ receiptPath: 'receipts/u2/r.jpg' }, 'receiptPath'));
test('잘못된 등급', () => bad({ tier: 'great' }, 'tier'));
test('음수 순위', () => bad({ rankIndex: -1 }, 'rankIndex'));
test('이벤트 참여인데 별점 없음', () => bad({ eventJoined: true, eventStars: null }, 'eventStars'));
test('이벤트 별점 범위 밖', () => bad({ eventJoined: true, eventStars: 6 }, 'eventStars'));
test('이벤트 미참여인데 별점 있음', () => bad({ eventStars: 5 }, 'eventStars'));
test('한줄평 10자 미만', () => bad({ text: '맛있어요' }, 'text'));
test('한줄평 300자 초과', () => bad({ text: '가'.repeat(301) }, 'text'));
test('사진 6장', () => bad({ photos: Array(6).fill('photos/u1/a.jpg') }, 'photos'));
test('남의 사진 경로', () => bad({ photos: ['photos/u2/a.jpg'] }, 'photos'));
