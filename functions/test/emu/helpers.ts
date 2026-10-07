import { initializeApp, getApps } from 'firebase-admin/app';
import { getFirestore, Firestore } from 'firebase-admin/firestore';

export const PROJECT = 'demo-zzinhugi';

export function testDb(): Firestore {
  if (!getApps().length) initializeApp({ projectId: PROJECT });
  return getFirestore();
}

export async function clearFirestore(): Promise<void> {
  await fetch(`http://${process.env.FIRESTORE_EMULATOR_HOST}/emulator/v1/projects/${PROJECT}/databases/(default)/documents`, { method: 'DELETE' });
}
