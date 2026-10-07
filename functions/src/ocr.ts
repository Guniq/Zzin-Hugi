import { randomUUID } from 'node:crypto';
import { OcrReceipt } from './receipt';

export interface ClovaConfig { url: string; secret: string }

const EMPTY: OcrReceipt = { storeName: null, address: null, date: null, total: null, approvalNo: null };

/* eslint-disable @typescript-eslint/no-explicit-any */
export function parseClovaReceipt(json: unknown): OcrReceipt {
  const img = (json as any)?.images?.[0];
  if (img?.inferResult !== 'SUCCESS') return { ...EMPTY };
  const r = img.receipt?.result ?? {};
  const name = r.storeInfo?.name?.formatted?.value ?? r.storeInfo?.name?.text ?? null;
  const addr = r.storeInfo?.addresses?.[0];
  const address = addr?.formatted?.value ?? addr?.text ?? null;
  const d = r.paymentInfo?.date?.formatted;
  const year = d?.year?.length === 2 ? `20${d.year}` : d?.year;
  const date = year && d?.month && d?.day ? `${year}-${d.month.padStart(2, '0')}-${d.day.padStart(2, '0')}` : null;
  const totalStr: string | undefined = r.totalPrice?.price?.formatted?.value;
  const total = totalStr && /^\d+$/.test(totalStr) ? Number(totalStr) : null;
  const approvalNo = String(r.paymentInfo?.confirmNum?.text ?? '').replace(/\D/g, '') || null;
  return { storeName: name, address, date, total, approvalNo };
}

export async function clovaOcr(image: Buffer, cfg: ClovaConfig, fetchFn: typeof fetch = fetch): Promise<OcrReceipt> {
  const res = await fetchFn(cfg.url, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json', 'X-OCR-SECRET': cfg.secret },
    body: JSON.stringify({
      version: 'V2',
      requestId: randomUUID(),
      timestamp: Date.now(),
      images: [{ format: 'jpg', name: 'receipt', data: image.toString('base64') }],
    }),
    signal: AbortSignal.timeout(20_000),
  });
  if (!res.ok) throw new Error(`clova ${res.status}`);
  return parseClovaReceipt(await res.json());
}
