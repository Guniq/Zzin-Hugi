// firebase-tools 14+ 에뮬레이터는 JDK 21 이상이 필요하다. 뒤에 오는 명령을 JDK 21이 PATH 맨 앞에 오도록 해서 실행한다.
// JDK 21 위치: 환경변수 JAVA21_HOME, 없으면 Windows 기본 설치 경로. 못 찾으면 현재 PATH의 java를 그대로 쓴다.
const { spawnSync } = require('node:child_process');
const fs = require('node:fs');
const path = require('node:path');

const win = process.platform === 'win32';
const exe = win ? 'java.exe' : 'java';
const home = [process.env.JAVA21_HOME, 'C:/Program Files/Java/jdk-21'].filter(Boolean).find((d) => fs.existsSync(path.join(d, 'bin', exe)));

const cmd = process.argv.slice(2).map((a) => (/\s/.test(a) ? `"${a}"` : a)).join(' ');
let line = cmd;
if (home) {
  const bin = path.join(home, 'bin');
  // 환경변수 객체의 PATH 대소문자 문제를 피하려고, 실행할 셸 안에서 직접 PATH를 바꾼다.
  line = win ? `set "PATH=${bin};%PATH%" && set "JAVA_HOME=${home}" && ${cmd}` : `PATH="${bin}:$PATH" JAVA_HOME="${home}" ${cmd}`;
}
process.exit(spawnSync(line, { stdio: 'inherit', shell: true }).status ?? 1);
