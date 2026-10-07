export interface AddressParts { gu: string | null; dong: string | null; road: string | null }
export interface Region { id: string; name: string; gu: string; dongs: string[] }

// ponytail: "구"가 있는 주소만 지원 (베타는 서울 한정). 구 없는 시(경기 광주시 등) 확장 시 시/군 토큰 추가.
export function addressParts(addr: string): AddressParts {
  const tokens = addr.trim().split(/\s+/);
  const gu = tokens.find((t) => /^[가-힣]+구$/.test(t)) ?? null;
  const road = tokens.find((t) => /^[가-힣][가-힣\d]*(로|길)$/.test(t)) ?? null;
  const dongTok = tokens.find((t) => /^[가-힣][가-힣\d]*(동|가)$/.test(t)) ?? null;
  const dong = dongTok ? dongTok.replace(/\d.*$/, '').replace(/동$/, '') : null;
  return { gu, dong, road };
}

export function regionFor(address: string, regions: Region[]): string | null {
  const p = addressParts(address);
  return regions.find((r) => r.gu === p.gu && p.dong !== null && r.dongs.includes(p.dong))?.id ?? null;
}
