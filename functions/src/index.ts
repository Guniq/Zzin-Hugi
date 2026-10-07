import { initializeApp } from 'firebase-admin/app';

initializeApp();

export { searchPlaces } from './search';

export { submitReview } from './review';
export { kakaoLogin, ensureUser } from './auth';
