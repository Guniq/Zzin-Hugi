const fs = require('node:fs');
const path = require('node:path');

const root = path.resolve(__dirname, '..');
fs.writeFileSync(path.join(root, '.env.local'), 'FAKE_EXTERNALS=true\nCLOVA_OCR_URL=http://fake.local\n');
fs.writeFileSync(path.join(root, '.secret.local'), 'KAKAO_REST_KEY=fake\nCLOVA_OCR_SECRET=fake\n');
console.log('wrote functions/.env.local and functions/.secret.local (에뮬레이터 전용, 가짜 값)');
