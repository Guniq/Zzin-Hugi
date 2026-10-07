// 웹 빌드 도우미. 루트의 kakao-js-key.txt 를 읽어 지도 키를 넣고 flutter build web 을 실행한다.
//
//   npm --prefix functions run build:web -- --host=192.168.0.179
//
// --host: 앱이 에뮬레이터를 찾아갈 PC 주소 (기본 localhost). 폰에서 접속하려면 PC 의 LAN IP 를 쓴다.
// kakao-js-key.txt 가 없으면 지도 없이 목록 검색만 되는 빌드가 만들어진다.
const fs = require('node:fs');
const path = require('node:path');
const { spawnSync } = require('node:child_process');

const SAFE = /^[A-Za-z0-9._-]+$/;

function parseHost(argv) {
  const arg = argv.find((a) => a.startsWith('--host='));
  const host = arg ? arg.slice('--host='.length).trim() : 'localhost';
  if (!SAFE.test(host)) throw new Error('--host 형식이 올바르지 않아요 (IP 또는 호스트 이름만)');
  return host;
}

function buildArgs(host, kakaoJsKey) {
  if (kakaoJsKey !== undefined && !SAFE.test(kakaoJsKey)) throw new Error('카카오 JavaScript 키 형식이 올바르지 않아요');
  return [
    'build',
    'web',
    '--dart-define=USE_EMULATOR=true',
    `--dart-define=EMULATOR_HOST=${host}`,
    ...(kakaoJsKey ? [`--dart-define=KAKAO_JS_KEY=${kakaoJsKey}`] : []),
  ];
}

function readKey(root) {
  const file = path.join(root, 'kakao-js-key.txt');
  if (!fs.existsSync(file)) return undefined;
  return fs.readFileSync(file, 'utf8').replace(/\s+/g, '') || undefined;
}

if (require.main === module) {
  const root = path.resolve(__dirname, '..');
  const key = readKey(root);
  const host = parseHost(process.argv.slice(2));
  console.log(`웹 빌드: 에뮬레이터 주소 ${host} / 카카오 지도 ${key ? '켜짐' : '꺼짐(kakao-js-key.txt 없음 → 목록 검색만)'}`);
  const r = spawnSync('flutter', buildArgs(host, key), { cwd: path.join(root, 'app'), stdio: 'inherit', shell: true });
  process.exit(r.status ?? 1);
}

module.exports = { buildArgs, parseHost, readKey };
