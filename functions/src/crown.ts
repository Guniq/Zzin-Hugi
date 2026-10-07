import { Firestore, getFirestore } from 'firebase-admin/firestore';
import { onSchedule } from 'firebase-functions/v2/scheduler';
import { Region } from './address';
import { kstDate } from './receipt';
import { REGION } from './config';

export function crownMonths(now: Date): { scoreMonth: string; displayMonth: string } {
  const displayMonth = kstDate(now).slice(0, 7);
  const [y, m] = displayMonth.split('-').map(Number);
  const scoreMonth = m === 1 ? `${y - 1}-12` : `${y}-${String(m - 1).padStart(2, '0')}`;
  return { scoreMonth, displayMonth };
}

export async function pickCrowns(db: Firestore, now: Date): Promise<void> {
  const { scoreMonth, displayMonth } = crownMonths(now);
  const regions: Region[] = (await db.doc('config/regions').get()).data()?.list ?? [];
  for (const r of regions) {
    const top = await db.collection('likeMonths')
      .where('month', '==', scoreMonth).where('region', '==', r.id)
      .orderBy('likes', 'desc').limit(1).get();
    const best = top.docs[0]?.data();
    if (!best || best.likes <= 0) continue;
    await db.doc(`crowns/${displayMonth}_${r.id}`).set({
      uid: best.uid, likes: best.likes, region: r.id, scoreMonth, displayMonth, status: 'pending',
    });
  }
}

export const monthlyCrown = onSchedule({ schedule: '0 0 1 * *', timeZone: 'Asia/Seoul', region: REGION }, async () => {
  await pickCrowns(getFirestore(), new Date());
});
