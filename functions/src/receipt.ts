import { createHash } from 'node:crypto';
import { addressParts } from './address';

export interface OcrReceipt { storeName: string | null; address: string | null; date: string | null; total: number | null; approvalNo: string | null }
export interface PlaceInfo { name: string; address: string; roadAddress: string }
export type ReceiptFailure = 'unreadable' | 'store_mismatch' | 'date_expired';
export type ReceiptResult = { ok: true; hash: string; visitDate: string } | { ok: false; reason: ReceiptFailure };

export const MAX_RECEIPT_AGE_DAYS = 30;
const DAY_MS = 86_400_000;

export function kstDate(now: Date): string {
  return new Date(now.getTime() + 9 * 3_600_000).toISOString().slice(0, 10);
}

export function normalizeName(s: string): string {
  return s.replace(/\(주\)|㈜|주식회사/g, '').replace(/[^0-9a-zA-Z가-힣]/g, '').toLowerCase();
}

function levenshtein(a: string, b: string): number {
  let prev = Array.from({ length: b.length + 1 }, (_, j) => j);
  for (let i = 1; i <= a.length; i++) {
    const cur = [i];
    for (let j = 1; j <= b.length; j++) {
      cur[j] = Math.min(prev[j] + 1, cur[j - 1] + 1, prev[j - 1] + (a[i - 1] === b[j - 1] ? 0 : 1));
    }
    prev = cur;
  }
  return prev[b.length];
}

export function nameMatches(ocrName: string, placeName: string): boolean {
  const a = normalizeName(ocrName);
  const b = normalizeName(placeName);
  if (!a || !b) return false;
  if (Math.min(a.length, b.length) >= 2 && (a.includes(b) || b.includes(a))) return true;
  return levenshtein(a, b) <= Math.max(1, Math.floor(Math.max(a.length, b.length) * 0.2));
}

export function addressMatches(ocrAddr: string, place: PlaceInfo): boolean {
  const o = addressParts(ocrAddr);
  const jibun = addressParts(place.address);
  const road = addressParts(place.roadAddress);
  if (!o.gu || (o.gu !== jibun.gu && o.gu !== road.gu)) return false;
  return (o.dong !== null && o.dong === jibun.dong) || (o.road !== null && o.road === road.road);
}

export function receiptHash(approvalNo: string, total: number, date: string): string {
  return createHash('sha256').update(`${approvalNo}|${total}|${date}`).digest('hex');
}

export function verifyReceipt(r: OcrReceipt, place: PlaceInfo, now: Date): ReceiptResult {
  if (!r.storeName || !r.address || !r.date || r.total === null || !r.approvalNo) return { ok: false, reason: 'unreadable' };
  if (!nameMatches(r.storeName, place.name) || !addressMatches(r.address, place)) return { ok: false, reason: 'store_mismatch' };
  const age = Math.round((Date.parse(kstDate(now)) - Date.parse(r.date)) / DAY_MS);
  if (Number.isNaN(age) || age < 0 || age > MAX_RECEIPT_AGE_DAYS) return { ok: false, reason: 'date_expired' };
  return { ok: true, hash: receiptHash(r.approvalNo, r.total, r.date), visitDate: r.date };
}
