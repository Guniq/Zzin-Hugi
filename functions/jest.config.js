module.exports = {
  preset: 'ts-jest',
  testEnvironment: 'node',
  testMatch: ['**/test/**/*.test.ts'],
  // firebase-functions → jose는 ESM 전용이라 Jest(CJS)가 못 읽음. 테스트는 jose를 쓰지 않으므로 스텁.
  moduleNameMapper: { '^jose$': '<rootDir>/test/stubs/jose.js' },
};
