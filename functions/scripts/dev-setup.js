// 에뮬레이터용 설정 파일(.env.local, .secret.local)을 만든다. 둘 다 git 에서 무시된다.
//
//   node scripts/dev-setup.js                      → 식당 검색·영수증 인식·카카오 로그인 모두 가짜 (키 불필요)
//   node scripts/dev-setup.js --kakao-key=<REST키>  → 식당 검색·카카오 로그인은 진짜 카카오, 영수증 인식은 가짜
//   (또는 환경변수 KAKAO_REST_KEY)
//   --kakao-secret=<값>  카카오 앱에서 Client Secret 을 켰을 때만 (또는 환경변수 KAKAO_CLIENT_SECRET)
const fs = require('node:fs');
const path = require('node:path');

function parseArg(argv, name, envValue) {
  const arg = argv.find((a) => a.startsWith(`${name}=`));
  const fromArg = arg ? arg.slice(name.length + 1).trim() : '';
  return fromArg || envValue || undefined;
}

function parseKeyArg(argv, env) {
  return parseArg(argv, '--kakao-key', env.KAKAO_REST_KEY);
}

function parseSecretArg(argv, env) {
  return parseArg(argv, '--kakao-secret', env.KAKAO_CLIENT_SECRET);
}

function buildDevFiles(kakaoKey, kakaoSecret) {
  if (kakaoKey !== undefined && !/^[A-Za-z0-9_-]+$/.test(kakaoKey)) {
    throw new Error('카카오 REST 키 형식이 올바르지 않아요 (영문·숫자·-·_ 만 가능)');
  }
  if (kakaoSecret !== undefined && !/^[A-Za-z0-9_-]+$/.test(kakaoSecret)) {
    throw new Error('카카오 Client Secret 형식이 올바르지 않아요 (영문·숫자·-·_ 만 가능)');
  }
  const real = kakaoKey !== undefined;
  return {
    env: 'FAKE_EXTERNALS=true\n' + (real ? 'FAKE_KAKAO=false\n' : '') + 'CLOVA_OCR_URL=http://fake.local\n',
    // KAKAO_CLIENT_SECRET: 카카오 앱에서 Client Secret 을 켰을 때만 실제 값, 아니면 none
    secret: `KAKAO_REST_KEY=${real ? kakaoKey : 'fake'}\nKAKAO_CLIENT_SECRET=${kakaoSecret || 'none'}\nCLOVA_OCR_SECRET=fake\n`,
    realSearch: real,
  };
}

if (require.main === module) {
  const root = path.resolve(__dirname, '..');
  const argv = process.argv.slice(2);
  const files = buildDevFiles(parseKeyArg(argv, process.env), parseSecretArg(argv, process.env));
  fs.writeFileSync(path.join(root, '.env.local'), files.env);
  fs.writeFileSync(path.join(root, '.secret.local'), files.secret);
  console.log(
    files.realSearch
      ? '식당 검색·카카오 로그인: 진짜 카카오 / 영수증 인식: 가짜 (functions/.env.local, .secret.local 작성)'
      : '식당 검색·카카오 로그인·영수증 인식 모두 가짜 (functions/.env.local, .secret.local 작성)',
  );
}

module.exports = { buildDevFiles, parseKeyArg, parseSecretArg };
