import { personalScore, insertPlace, emptyRanking, scoreChanges, deriveScores, scoresOf } from '../../src/scoring';

describe('personalScore', () => {
  test('등급에 혼자면 구간 중앙', () => {
    expect(personalScore('best', 0, 1)).toBe(8.5);
    expect(personalScore('ok', 0, 1)).toBe(5.5);
    expect(personalScore('bad', 0, 1)).toBe(2);
  });
  test('두 개면 위아래로 나뉨 (소수 1자리 반올림)', () => {
    expect(personalScore('best', 0, 2)).toBe(9.3);
    expect(personalScore('best', 1, 2)).toBe(7.8);
  });
});

describe('insertPlace', () => {
  test('지정 위치에 삽입, 원본 불변', () => {
    const r = { best: ['a', 'b'], ok: [], bad: [] };
    const next = insertPlace(r, 'x', 'best', 1);
    expect(next.best).toEqual(['a', 'x', 'b']);
    expect(r.best).toEqual(['a', 'b']);
  });
  test('다른 등급에 있으면 옮김', () => {
    const r = { best: ['a', 'x'], ok: ['c'], bad: [] };
    expect(insertPlace(r, 'x', 'bad', 0)).toEqual({ best: ['a'], ok: ['c'], bad: ['x'] });
  });
  test('index 범위 밖은 clamp', () => {
    expect(insertPlace(emptyRanking(), 'x', 'ok', 99).ok).toEqual(['x']);
    expect(insertPlace({ best: [], ok: ['a'], bad: [] }, 'x', 'ok', -3).ok).toEqual(['x', 'a']);
  });
});

describe('scoreChanges', () => {
  test('새 식당을 최고 1위로 넣으면 기존 식당 점수 하락', () => {
    const before = { best: ['a'], ok: [], bad: [] };
    const after = insertPlace(before, 'x', 'best', 0);
    const c = scoreChanges(before, after);
    expect(c.get('x')).toEqual({ old: null, new: 9.3 });
    expect(c.get('a')).toEqual({ old: 8.5, new: 7.8 });
  });
  test('점수 안 바뀐 항목은 제외', () => {
    const before = { best: ['a'], ok: ['b'], bad: [] };
    const after = insertPlace(before, 'x', 'bad', 0);
    expect([...scoreChanges(before, after).keys()]).toEqual(['x']);
  });
  test('scoresOf는 전 등급 포함', () => {
    expect(scoresOf({ best: ['a'], ok: ['b'], bad: ['c'] })).toEqual(new Map([['a', 8.5], ['b', 5.5], ['c', 2]]));
  });
});

describe('deriveScores', () => {
  test('후기 3개 미만이면 null', () => {
    expect(deriveScores({ scoreSum: 17, reviewCount: 2, eventStarSum: 10, eventReviewCount: 2 }))
      .toEqual({ realScore: null, eventScore: null, bubble: null });
  });
  test('찐점수·이벤트점수·거품지수', () => {
    expect(deriveScores({ scoreSum: 18, reviewCount: 3, eventStarSum: 15, eventReviewCount: 3 }))
      .toEqual({ realScore: 6, eventScore: 10, bubble: 4 });
  });
  test('이벤트 후기만 부족하면 거품지수 null', () => {
    expect(deriveScores({ scoreSum: 18, reviewCount: 3, eventStarSum: 10, eventReviewCount: 2 }))
      .toEqual({ realScore: 6, eventScore: null, bubble: null });
  });
});
