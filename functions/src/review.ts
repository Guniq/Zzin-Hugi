import { Firestore, FieldValue, getFirestore } from 'firebase-admin/firestore';
import { getStorage } from 'firebase-admin/storage';
import { onCall, HttpsError } from 'firebase-functions/v2/https';
import { deriveScores, RestaurantSums } from './scoring';
import { OcrReceipt, PlaceInfo, verifyReceipt, kstDate } from './receipt';
import { clovaOcr } from './ocr';
import { REGION, CLOVA_OCR_SECRET, CLOVA_OCR_URL } from './config';
import { isFakeOcr, fakeOcr } from './dev/fake';

export const DAILY_REVIEW_LIMIT = 5;

export interface SubmitReviewInput {
  placeId: string;
  receiptPath: string;
  /** 내 실제 별점 1~5 */
  stars: number;
  eventJoined: boolean;
  /** 이벤트 때 준 별점 1~5 (eventJoined 일 때만) */
  eventStars: number | null;
  text: string;
  photos: string[];
}
export interface SubmitDeps { ocr: (receiptPath: string, place: PlaceInfo) => Promise<OcrReceipt> }

const invalid = (field: string): never => { throw new HttpsError('invalid-argument', field); };
const isStar = (v: unknown): v is number => Number.isInteger(v) && (v as number) >= 1 && (v as number) <= 5;

/* eslint-disable @typescript-eslint/no-explicit-any */
export function validateSubmitInput(uid: string, raw: unknown): SubmitReviewInput {
  const d = (raw ?? {}) as any;
  if (typeof d.placeId !== 'string' || !d.placeId || d.placeId.includes('/')) invalid('placeId');
  if (typeof d.receiptPath !== 'string' || !d.receiptPath.startsWith(`receipts/${uid}/`)) invalid('receiptPath');
  if (!isStar(d.stars)) invalid('stars');
  if (typeof d.eventJoined !== 'boolean') invalid('eventJoined');
  const starsOk = d.eventJoined ? isStar(d.eventStars) : d.eventStars == null;
  if (!starsOk) invalid('eventStars');
  const text = typeof d.text === 'string' ? d.text.trim() : '';
  if (text.length < 10 || text.length > 300) invalid('text');
  const photos = d.photos ?? [];
  if (!Array.isArray(photos) || photos.length > 5 || photos.some((p: unknown) => typeof p !== 'string' || !p.startsWith(`photos/${uid}/`))) invalid('photos');
  return {
    placeId: d.placeId, receiptPath: d.receiptPath, stars: d.stars,
    eventJoined: d.eventJoined, eventStars: d.eventJoined ? d.eventStars : null, text, photos,
  };
}

export async function submitReviewCore(db: Firestore, deps: SubmitDeps, uid: string, raw: unknown, now: Date): Promise<{ reviewId: string }> {
  const input = validateSubmitInput(uid, raw);
  const today = kstDate(now);

  const place = (await db.doc(`restaurants/${input.placeId}`).get()).data();
  if (!place) throw new HttpsError('not-found', 'place_not_found');
  if (!place.region) throw new HttpsError('failed-precondition', 'out_of_region');

  const userRef = db.doc(`users/${uid}`);
  const user0 = (await userRef.get()).data();
  if (!user0) throw new HttpsError('failed-precondition', 'no_user');
  // OCR 비용 아끼려고 트랜잭션 전에 한 번 더 확인
  if (user0.dailyReviewDate === today && user0.dailyReviewCount >= DAILY_REVIEW_LIMIT) throw new HttpsError('resource-exhausted', 'daily_limit');

  let ocr: OcrReceipt;
  try {
    ocr = await deps.ocr(input.receiptPath, place as PlaceInfo);
  } catch {
    throw new HttpsError('unavailable', 'ocr_unavailable');
  }
  const receipt = verifyReceipt(ocr, place as PlaceInfo, now);
  if (!receipt.ok) throw new HttpsError('failed-precondition', receipt.reason);

  const reviewId = `${uid}_${input.placeId}`;
  const reviewRef = db.doc(`reviews/${reviewId}`);
  const keyRef = db.doc(`receiptKeys/${receipt.hash}`);
  const restRef = db.doc(`restaurants/${input.placeId}`);

  await db.runTransaction(async (tx) => {
    const [userSnap, keySnap, oldSnap, restSnap] = await tx.getAll(userRef, keyRef, reviewRef, restRef);
    if (keySnap.exists) throw new HttpsError('already-exists', 'duplicate');
    const user = userSnap.data()!;
    const dailyCount = user.dailyReviewDate === today ? user.dailyReviewCount : 0;
    if (dailyCount >= DAILY_REVIEW_LIMIT) throw new HttpsError('resource-exhausted', 'daily_limit');

    const s = restSnap.data() ?? {};
    const sums: RestaurantSums = {
      scoreSum: s.scoreSum ?? 0, reviewCount: s.reviewCount ?? 0,
      eventStarSum: s.eventStarSum ?? 0, eventActualSum: s.eventActualSum ?? 0, eventReviewCount: s.eventReviewCount ?? 0,
    };
    const old = oldSnap.data();
    const isNew = !old;
    // 재방문(같은 식당 후기 갱신)이면 이전 값을 빼고 새 값을 더한다.
    if (old) {
      sums.scoreSum -= old.stars;
      if (old.eventJoined) {
        sums.eventStarSum -= old.eventStars;
        sums.eventActualSum -= old.stars;
        sums.eventReviewCount -= 1;
      }
    } else {
      sums.reviewCount += 1;
    }
    sums.scoreSum += input.stars;
    if (input.eventJoined) {
      sums.eventStarSum += input.eventStars!;
      sums.eventActualSum += input.stars;
      sums.eventReviewCount += 1;
    }

    // --- 이하 쓰기만 ---
    tx.set(restRef, { ...sums, ...deriveScores(sums) }, { merge: true });
    tx.set(reviewRef, {
      uid, restaurantId: input.placeId, region: place.region, stars: input.stars,
      eventJoined: input.eventJoined, eventStars: input.eventStars, text: input.text, photos: input.photos,
      visitDate: receipt.visitDate, likeCount: old?.likeCount ?? 0,
      createdAt: old?.createdAt ?? FieldValue.serverTimestamp(), updatedAt: FieldValue.serverTimestamp(),
    });
    tx.set(keyRef, { uid, reviewId, createdAt: FieldValue.serverTimestamp() });
    tx.update(userRef, {
      verifiedReviewCount: (user.verifiedReviewCount ?? 0) + (isNew ? 1 : 0),
      dailyReviewDate: today,
      dailyReviewCount: dailyCount + 1,
    });
  });
  return { reviewId };
}

export const submitReview = onCall({ region: REGION, secrets: [CLOVA_OCR_SECRET], timeoutSeconds: 60 }, (req) => {
  if (!req.auth) throw new HttpsError('unauthenticated', 'login_required');
  const ocr = isFakeOcr()
    ? async (path: string, place: PlaceInfo) => fakeOcr(path, place)
    : async (path: string) => {
        const [buf] = await getStorage().bucket().file(path).download();
        return clovaOcr(buf, { url: CLOVA_OCR_URL.value(), secret: CLOVA_OCR_SECRET.value() });
      };
  return submitReviewCore(getFirestore(), { ocr }, req.auth.uid, req.data, new Date());
});
