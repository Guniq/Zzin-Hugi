// 에뮬레이터용 설정 파일(.env.local, .secret.local)을 만든다. 둘 다 git 에서 무시된다.
//
//   node scripts/dev-setup.js                      → 식당 검색·영수증 인식 모두 가짜 (키 불필요)
//   node scripts/dev-setup.js --kakao-key=<REST키>  → 식당 검색은 진짜 카카오, 영수증 인식은 가짜
//   (또는 환경변수 KAKAO_REST_KEY)
const fs = require('node:fs');
const path = require('node:path');

function parseKeyArg(argv, env) {
  const arg = argv.find((a) => a.startsWith('--kakao-key='));
  const fromArg = arg ? arg.slice('--kakao-key='.length).trim() : '';
  return fromArg || env.KAKAO_REST_KEY || undefined;
}

function buildDevFiles(kakaoKey) {
  if (kakaoKey !== undefined && !/^[A-Za-z0-9_-]+$/.test(kakaoKey)) {
    throw new Error('카카오 REST 키 형식이 올바르지 않아요 (영문·숫자·-·_ 만 가능)');
  }
  const real = kakaoKey !== undefined;
  return {
    env: 'FAKE_EXTERNALS=true\n' + (real ? 'FAKE_KAKAO=false\n' : '') + 'CLOVA_OCR_URL=http://fake.local\n',
    secret: `KAKAO_REST_KEY=${real ? kakaoKey : 'fake'}\nCLOVA_OCR_SECRET=fake\n`,
    realSearch: real,
  };
}

if (require.main === module) {
  const root = path.resolve(__dirname, '..');
  const files = buildDevFiles(parseKeyArg(process.argv.slice(2), process.env));
  fs.writeFileSync(path.join(root, '.env.local'), files.env);
  fs.writeFileSync(path.join(root, '.secret.local'), files.secret);
  console.log(
    files.realSearch
      ? '식당 검색: 진짜 카카오 / 영수증 인식: 가짜 (functions/.env.local, .secret.local 작성)'
      : '식당 검색·영수증 인식 모두 가짜 (functions/.env.local, .secret.local 작성)',
  );
}

module.exports = { buildDevFiles, parseKeyArg };
