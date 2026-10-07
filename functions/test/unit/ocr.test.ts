import { readFileSync } from 'node:fs';
import { resolve } from 'node:path';
import { parseClovaReceipt, clovaOcr } from '../../src/ocr';

const dir = resolve(__dirname, '../fixtures/clova');
const cases: { file: string; expected: unknown }[] = JSON.parse(readFileSync(resolve(dir, 'cases.json'), 'utf8'));

test.each(cases)('fixture $file 파싱', ({ file, expected }) => {
  expect(parseClovaReceipt(JSON.parse(readFileSync(resolve(dir, file), 'utf8')))).toEqual(expected);
});

test('인식 실패 응답은 전부 null', () => {
  expect(parseClovaReceipt({ images: [{ inferResult: 'FAILURE' }] }))
    .toEqual({ storeName: null, address: null, date: null, total: null, approvalNo: null });
});

test('clovaOcr는 시크릿 헤더와 base64 이미지를 보냄', async () => {
  const body = JSON.parse(readFileSync(resolve(dir, 'sample-ok.json'), 'utf8'));
  const fetchFn = jest.fn().mockResolvedValue({ ok: true, json: async () => body });
  const r = await clovaOcr(Buffer.from('img'), { url: 'https://ocr.example', secret: 's3' }, fetchFn as unknown as typeof fetch);
  expect(r.storeName).toBe('성수찐국밥');
  const [url, init] = fetchFn.mock.calls[0];
  expect(url).toBe('https://ocr.example');
  expect(init.headers['X-OCR-SECRET']).toBe('s3');
  expect(JSON.parse(init.body).images[0].data).toBe(Buffer.from('img').toString('base64'));
});

test('clovaOcr HTTP 실패는 throw', async () => {
  const fetchFn = jest.fn().mockResolvedValue({ ok: false, status: 500 });
  await expect(clovaOcr(Buffer.from('x'), { url: 'u', secret: 's' }, fetchFn as unknown as typeof fetch)).rejects.toThrow('clova 500');
});
