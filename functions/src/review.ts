import { Firestore, FieldValue, getFirestore } from 'firebase-admin/firestore';
import { getStorage } from 'firebase-admin/storage';
import { onCall, HttpsError } from 'firebase-functions/v2/https';
import { Tier, TIERS, Ranking, emptyRanking, insertPlace, scoreChanges, scoresOf, deriveScores, round1, RestaurantSums } from './scoring';
import { OcrReceipt, PlaceInfo, verifyReceipt, kstDate } from './receipt';
import { clovaOcr } from './ocr';
import { REGION, CLOVA_OCR_SECRET, CLOVA_OCR_URL } from './config';

export const DAILY_REVIEW_LIMIT = 5;

export interface SubmitReviewInput {
  placeId: string; receiptPath: string; tier: Tier; rankIndex: number;
  eventJoined: boolean; eventStars: number | null; text: string; photos: string[];
}
export interface SubmitDeps { ocr: (receiptPath: string) => Promise<OcrReceipt> }

const invalid = (field: string): never => { throw new HttpsError('invalid-argument', field); };

/* eslint-disable @typescript-eslint/no-explicit-any */
export function validateSubmitInput(uid: string, raw: unknown): SubmitReviewInput {
  const d = (raw ?? {}) as any;
  if (typeof d.placeId !== 'string' || !d.placeId || d.placeId.includes('/')) invalid('placeId');
  if (typeof d.receiptPath !== 'string' || !d.receiptPath.startsWith(`receipts/${uid}/`)) invalid('receiptPath');
  if (!TIERS.includes(d.tier)) invalid('tier');
  if (!Number.isInteger(d.rankIndex) || d.rankIndex < 0) invalid('rankIndex');
  if (typeof d.eventJoined !== 'boolean') invalid('eventJoined');
  const starsOk = d.eventJoined ? Number.isInteger(d.eventStars) && d.eventStars >= 1 && d.eventStars <= 5 : d.eventStars == null;
  if (!starsOk) invalid('eventStars');
  const text = typeof d.text === 'string' ? d.text.trim() : '';
  if (text.length < 10 || text.length > 300) invalid('text');
  const photos = d.photos ?? [];
  if (!Array.isArray(photos) || photos.length > 5 || photos.some((p: unknown) => typeof p !== 'string' || !p.startsWith(`photos/${uid}/`))) invalid('photos');
  return {
    placeId: d.placeId, receiptPath: d.receiptPath, tier: d.tier, rankIndex: d.rankIndex,
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
    ocr = await deps.ocr(input.receiptPath);
  } catch {
    throw new HttpsError('unavailable', 'ocr_unavailable');
  }
  const receipt = verifyReceipt(ocr, place as PlaceInfo, now);
  if (!receipt.ok) throw new HttpsError('failed-precondition', receipt.reason);

  const reviewId = `${uid}_${input.placeId}`;
  const reviewRef = db.doc(`reviews/${reviewId}`);
  const keyRef = db.doc(`receiptKeys/${receipt.hash}`);

  await db.runTransaction(async (tx) => {
    const [userSnap, keySnap, oldSnap] = await tx.getAll(userRef, keyRef, reviewRef);
    if (keySnap.exists) throw new HttpsError('already-exists', 'duplicate');
    const user = userSnap.data()!;
    const dailyCount = user.dailyReviewDate === today ? user.dailyReviewCount : 0;
    if (dailyCount >= DAILY_REVIEW_LIMIT) throw new HttpsError('resource-exhausted', 'daily_limit');

    const before: Ranking = user.ranking ?? emptyRanking();
    const after = insertPlace(before, input.placeId, input.tier, input.rankIndex);
    const changes = scoreChanges(before, after);
    const ids = [...new Set([input.placeId, ...changes.keys()])];
    const restSnaps = await tx.getAll(...ids.map((id) => db.doc(`restaurants/${id}`)));
    const old = oldSnap.data();
    const isNew = !old;

    // --- 이하 쓰기만 ---
    ids.forEach((id, i) => {
      const s = restSnaps[i].data() ?? {};
      const sums: RestaurantSums = {
        scoreSum: s.scoreSum ?? 0, reviewCount: s.reviewCount ?? 0,
        eventStarSum: s.eventStarSum ?? 0, eventReviewCount: s.eventReviewCount ?? 0,
      };
      const c = changes.get(id);
      if (c) sums.scoreSum = round1(sums.scoreSum - (c.old ?? 0) + c.new);
      if (id === input.placeId) {
        if (isNew) sums.reviewCount += 1;
        if (old?.eventJoined) { sums.eventStarSum -= old.eventStars; sums.eventReviewCount -= 1; }
        if (input.eventJoined) { sums.eventStarSum += input.eventStars!; sums.eventReviewCount += 1; }
      } else if (c) {
        tx.update(db.doc(`reviews/${uid}_${id}`), { personalScore: c.new });
      }
      tx.set(db.doc(`restaurants/${id}`), { ...sums, ...deriveScores(sums) }, { merge: true });
    });

    tx.set(reviewRef, {
      uid, restaurantId: input.placeId, region: place.region, tier: input.tier,
      personalScore: scoresOf(after).get(input.placeId)!,
      eventJoined: input.eventJoined, eventStars: input.eventStars, text: input.text, photos: input.photos,
      visitDate: receipt.visitDate, likeCount: old?.likeCount ?? 0,
      createdAt: old?.createdAt ?? FieldValue.serverTimestamp(), updatedAt: FieldValue.serverTimestamp(),
    });
    tx.set(keyRef, { uid, reviewId, createdAt: FieldValue.serverTimestamp() });
    tx.update(userRef, {
      ranking: after,
      verifiedReviewCount: (user.verifiedReviewCount ?? 0) + (isNew ? 1 : 0),
      dailyReviewDate: today,
      dailyReviewCount: dailyCount + 1,
    });
  });
  return { reviewId };
}

export const submitReview = onCall({ region: REGION, secrets: [CLOVA_OCR_SECRET], timeoutSeconds: 60 }, (req) => {
  if (!req.auth) throw new HttpsError('unauthenticated', 'login_required');
  const ocr = async (path: string) => {
    const [buf] = await getStorage().bucket().file(path).download();
    return clovaOcr(buf, { url: CLOVA_OCR_URL.value(), secret: CLOVA_OCR_SECRET.value() });
  };
  return submitReviewCore(getFirestore(), { ocr }, req.auth.uid, req.data, new Date());
});
