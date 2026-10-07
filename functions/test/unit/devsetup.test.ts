// eslint-disable-next-line @typescript-eslint/no-require-imports
const { buildDevFiles, parseKeyArg } = require('../../scripts/dev-setup.js');

describe('buildDevFiles', () => {
  test('키가 없으면 검색·영수증 모두 가짜', () => {
    const f = buildDevFiles(undefined);
    expect(f.env).toContain('FAKE_EXTERNALS=true');
    expect(f.env).not.toContain('FAKE_KAKAO=false');
    expect(f.secret).toContain('KAKAO_REST_KEY=fake');
    expect(f.realSearch).toBe(false);
  });

  test('키가 있으면 검색만 진짜, 영수증은 가짜', () => {
    const f = buildDevFiles('abc123def456');
    expect(f.env).toContain('FAKE_EXTERNALS=true');
    expect(f.env).toContain('FAKE_KAKAO=false');
    expect(f.secret).toContain('KAKAO_REST_KEY=abc123def456');
    expect(f.secret).toContain('CLOVA_OCR_SECRET=fake');
    expect(f.realSearch).toBe(true);
  });

  test('공백·따옴표가 섞인 키는 거절', () => {
    expect(() => buildDevFiles('abc def')).toThrow();
    expect(() => buildDevFiles('abc"def')).toThrow();
    expect(() => buildDevFiles('a\nb')).toThrow();
  });
});

describe('parseKeyArg', () => {
  test('--kakao-key=값 또는 환경변수', () => {
    expect(parseKeyArg(['--kakao-key=K1'], {})).toBe('K1');
    expect(parseKeyArg([], { KAKAO_REST_KEY: 'K2' })).toBe('K2');
    expect(parseKeyArg(['--kakao-key=K1'], { KAKAO_REST_KEY: 'K2' })).toBe('K1');
    expect(parseKeyArg([], {})).toBeUndefined();
    expect(parseKeyArg(['--kakao-key='], {})).toBeUndefined();
  });
});
