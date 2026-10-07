// eslint-disable-next-line @typescript-eslint/no-require-imports
const { buildArgs, parseHost } = require('../../../scripts/build-web.js');

describe('parseHost', () => {
  test('--host=값, 없으면 localhost', () => {
    expect(parseHost(['--host=192.168.0.179'])).toBe('192.168.0.179');
    expect(parseHost([])).toBe('localhost');
  });
  test('호스트에 이상한 문자가 있으면 거절', () => {
    expect(() => parseHost(['--host=a b'])).toThrow();
    expect(() => parseHost(['--host=a;rm'])).toThrow();
    expect(() => parseHost(['--host=http://x'])).toThrow();
  });
});

describe('buildArgs', () => {
  test('에뮬레이터 호스트와 카카오 JS 키를 dart-define 으로 넘김', () => {
    const a = buildArgs('192.168.0.179', 'abcDEF123');
    expect(a).toEqual([
      'build',
      'web',
      '--dart-define=USE_EMULATOR=true',
      '--dart-define=EMULATOR_HOST=192.168.0.179',
      '--dart-define=KAKAO_JS_KEY=abcDEF123',
    ]);
  });
  test('키가 없으면 KAKAO_JS_KEY 를 넘기지 않음 (지도 없이 목록 검색만)', () => {
    const a = buildArgs('localhost', undefined);
    expect(a.some((x: string) => x.includes('KAKAO_JS_KEY'))).toBe(false);
  });
  test('키 형식이 이상하면 거절', () => {
    expect(() => buildArgs('localhost', 'a b')).toThrow();
    expect(() => buildArgs('localhost', 'a"b')).toThrow();
  });
});
