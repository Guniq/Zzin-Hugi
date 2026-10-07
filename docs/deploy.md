# 배포 절차

## 1회 준비 (사람)
1. Firebase 콘솔에서 프로젝트 생성 (Blaze 요금제 — Functions·Secret 필수), 위치 `asia-northeast3`
2. Authentication → Apple 공급자 활성화
3. 카카오 디벨로퍼스 앱 생성 → REST API 키, 네이티브 앱 키 확보, 카카오 로그인 활성화
4. NAVER Cloud CLOVA OCR → Receipt 도메인 생성 → Invoke URL, Secret Key 확보
5. `.firebaserc`에 실 프로젝트 별칭 추가: `npx --prefix functions firebase use --add` → 별칭 `prod`

## 시크릿·파라미터
```bash
npx --prefix functions firebase use prod
npx --prefix functions firebase functions:secrets:set KAKAO_REST_KEY
npx --prefix functions firebase functions:secrets:set CLOVA_OCR_SECRET
echo "CLOVA_OCR_URL=<Invoke URL>" > functions/.env.prod
```

## 배포
```bash
npm --prefix functions run test:unit && npm --prefix functions run test:emu
npx --prefix functions firebase deploy --only firestore,storage,functions
gcloud storage buckets update gs://<프로젝트ID>.firebasestorage.app --lifecycle-file=storage-lifecycle.json
```

> 로컬 Emulator는 Java 11+ 와 firebase-tools 13 기준. 최신 firebase-tools(14+)는 JDK 21이 필요하다.

## 베타 지역 등록 (콘솔 → Firestore)
`config/regions` 문서: `{ list: [{ id: "seongsu", name: "성수", gu: "성동구", dongs: ["성수"] }] }`

## 매월 1일
콘솔 → `crowns` 컬렉션 → 이번 달 `pending` 문서 확인 → 담합 의심 없으면 `status`를 `confirmed`로 변경
