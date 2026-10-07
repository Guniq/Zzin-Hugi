import { Firestore, FieldValue, getFirestore } from 'firebase-admin/firestore';
import { onDocumentWritten } from 'firebase-functions/v2/firestore';
import { titleFor } from './title';
import { kstDate } from './receipt';
import { REGION } from './config';

export async function applyLike(db: Firestore, reviewId: string, delta: 1 | -1, now: Date): Promise<void> {
  const reviewRef = db.doc(`reviews/${reviewId}`);
  const review = (await reviewRef.get()).data();
  if (!review) return;
  const month = kstDate(now).slice(0, 7);
  const userRef = db.doc(`users/${review.uid}`);
  await db.runTransaction(async (tx) => {
    const user = (await tx.get(userRef)).data();
    const likes = Math.max(0, (user?.likesReceived ?? 0) + delta);
    tx.update(reviewRef, { likeCount: FieldValue.increment(delta) });
    tx.set(userRef, { likesReceived: likes, title: titleFor(likes) }, { merge: true });
    // ponytail: 이전 달 따봉을 이번 달에 취소하면 이번 달 집계가 -1. 대마왕은 운영자 확인 단계에서 걸러짐.
    tx.set(
      db.doc(`likeMonths/${month}_${review.region}_${review.uid}`),
      { uid: review.uid, region: review.region, month, likes: FieldValue.increment(delta) },
      { merge: true },
    );
  });
}

// ponytail: 트리거는 at-least-once라 드물게 중복 집계 가능. 베타 규모에선 허용, 문제 되면 event.id로 멱등 처리.
export const onLikeWrite = onDocumentWritten({ document: 'reviews/{reviewId}/likes/{likerUid}', region: REGION }, async (event) => {
  const before = event.data?.before.exists ?? false;
  const after = event.data?.after.exists ?? false;
  if (before === after) return;
  await applyLike(getFirestore(), event.params.reviewId, after ? 1 : -1, new Date());
});
