// 카카오맵 JavaScript SDK 를 Flutter(Dart)에서 쓰기 쉽게 감싼 얇은 레이어.
// Dart 쪽은 window.zzinMap 의 함수만 부른다. 카카오 API 호출은 모두 이 파일 안에 있다.
//
// 흐름: load(appKey) → create(el, opts, onMarkerTap, onUserMoved) → setMarkers / moveTo / locate → destroy
//
// 핀 모양(카카오맵 앱과 비슷하게): 흰 알약 안에 [식당 아이콘 + 찐점수], 알약 아래에 가게 이름.
// 선택된 핀은 빨간 알약 + 꼬리로 크게 보이고, 이름이 겹치는 핀은 이름만 숨긴다(확대하면 나타남).
(function () {
  'use strict';

  var INK = '#121417';
  var ACCENT = '#C93C1C';
  var GREY = '#9AA0A6';
  var LOAD_TIMEOUT_MS = 10000;
  var NAME_MAX_W = 88;
  var NAME_LINE_H = 15;
  var NAME_CHAR_W = 12;
  var PILL_H = 30;

  var sdkPromise = null;
  var maps = {};
  var nextId = 1;

  function load(appKey) {
    if (sdkPromise) return sdkPromise;
    sdkPromise = new Promise(function (resolve, reject) {
      if (window.kakao && window.kakao.maps && window.kakao.maps.LatLng) {
        resolve();
        return;
      }
      var timer = setTimeout(function () { reject(new Error('sdk_timeout')); }, LOAD_TIMEOUT_MS);
      var s = document.createElement('script');
      s.src = 'https://dapi.kakao.com/v2/maps/sdk.js?autoload=false&appkey=' + encodeURIComponent(appKey);
      s.onload = function () {
        try {
          window.kakao.maps.load(function () { clearTimeout(timer); resolve(); });
        } catch (e) { clearTimeout(timer); reject(e); }
      };
      s.onerror = function () { clearTimeout(timer); reject(new Error('sdk_load_failed')); };
      document.head.appendChild(s);
    });
    // 실패하면 다음에 다시 시도할 수 있게 비운다.
    sdkPromise.catch(function () { sdkPromise = null; });
    return sdkPromise;
  }

  var SVG_NS = 'http://www.w3.org/2000/svg';

  function utensilsIcon(color, size) {
    var svg = document.createElementNS(SVG_NS, 'svg');
    svg.setAttribute('width', String(size));
    svg.setAttribute('height', String(size));
    svg.setAttribute('viewBox', '0 0 24 24');
    svg.setAttribute('fill', 'none');
    svg.setAttribute('stroke', color);
    svg.setAttribute('stroke-width', '2.4');
    svg.setAttribute('stroke-linecap', 'round');
    svg.setAttribute('stroke-linejoin', 'round');
    ['M3 2v7c0 1.1.9 2 2 2h4a2 2 0 0 0 2-2V2', 'M7 2v22', 'M21 15V2a5 5 0 0 0-5 5v6c0 1.1.9 2 2 2h3Zm0 0v7'].forEach(function (d) {
      var p = document.createElementNS(SVG_NS, 'path');
      p.setAttribute('d', d);
      svg.appendChild(p);
    });
    return svg;
  }

  // 알약 가로 길이 추정(겹침 계산용): 아이콘 원 + 여백 + 글자
  function pillWidth(m, selected) {
    var base = selected ? 36 : 30;
    return base + (m.badge ? 15 + String(m.badge).length * 9 : 0);
  }

  /**
   * 핀 하나. 오버레이의 기준점은 알약 한가운데(선택된 핀은 꼬리 끝)이고, 이름은 알약 아래에 absolute 로 붙는다.
   * 가게 이름은 외부 데이터이므로 textContent 만 쓴다(innerHTML 금지).
   */
  function pinEl(m, selected, onTap) {
    var wrap = document.createElement('div');
    wrap.style.cssText = 'position:relative;display:flex;flex-direction:column;align-items:center;cursor:pointer;';

    var h = selected ? 36 : PILL_H;
    var circleSize = selected ? 28 : 24;
    var pill = document.createElement('div');
    pill.style.cssText =
      'display:flex;align-items:center;gap:5px;box-sizing:border-box;height:' + h + 'px;border-radius:' + h / 2 + 'px;' +
      'padding:0 ' + (m.badge ? 10 : 3) + 'px 0 3px;box-shadow:0 1px 5px rgba(18,20,23,.35);' +
      'background:' + (selected ? ACCENT : '#fff') + ';border:' + (selected ? '2px solid #fff' : '1px solid #D5D8DC') + ';';

    var circle = document.createElement('div');
    circle.style.cssText =
      'display:flex;align-items:center;justify-content:center;flex:none;border-radius:50%;width:' + circleSize + 'px;height:' + circleSize + 'px;' +
      'background:' + (selected ? '#fff' : (m.blocked ? GREY : INK)) + ';';
    circle.appendChild(utensilsIcon(selected ? ACCENT : '#fff', selected ? 17 : 15));
    pill.appendChild(circle);

    if (m.badge) {
      var badge = document.createElement('span');
      badge.textContent = m.badge;
      badge.style.cssText =
        'font:800 ' + (selected ? 15 : 14) + 'px/1 "Noto Sans KR",sans-serif;white-space:nowrap;color:' + (selected ? '#fff' : (m.blocked ? GREY : INK)) + ';';
      pill.appendChild(badge);
    }
    wrap.appendChild(pill);

    if (selected) {
      var tail = document.createElement('div');
      tail.style.cssText = 'width:0;height:0;margin-top:-1px;border-left:7px solid transparent;border-right:7px solid transparent;border-top:9px solid ' + ACCENT + ';';
      wrap.appendChild(tail);
    }

    var name = document.createElement('div');
    name.textContent = m.name;
    name.style.cssText =
      'position:absolute;top:100%;left:50%;transform:translateX(-50%);margin-top:' + (selected ? 3 : 2) + 'px;width:max-content;max-width:' + NAME_MAX_W + 'px;' +
      'text-align:center;word-break:keep-all;font:700 12px/' + NAME_LINE_H + 'px "Noto Sans KR",sans-serif;color:' + (m.blocked ? GREY : INK) + ';' +
      'text-shadow:-1px -1px 0 #fff,1px -1px 0 #fff,-1px 1px 0 #fff,1px 1px 0 #fff,0 0 3px #fff;pointer-events:none;';
    wrap.appendChild(name);

    wrap.addEventListener('click', function (e) { e.stopPropagation(); onTap(m.id); });
    return { el: wrap, name: name };
  }

  function create(el, optsJson, onMarkerTap, onUserMoved) {
    var k = window.kakao.maps;
    var opts = JSON.parse(optsJson);
    var map = new k.Map(el, { center: new k.LatLng(opts.lat, opts.lng), level: opts.level || 4 });
    var id = nextId++;
    var entry = { map: map, overlays: [], items: [], quietUntil: Date.now() + 1500, onMarkerTap: onMarkerTap };
    maps[id] = entry;

    // 프로그램이 지도를 옮긴 뒤의 idle 은 사용자가 움직인 게 아니므로 무시한다.
    k.event.addListener(map, 'idle', function () {
      layoutLabels(entry); // 확대·이동이 끝나면 이름 라벨의 겹침을 다시 계산
      if (Date.now() < entry.quietUntil) return;
      var c = map.getCenter();
      onUserMoved(c.getLat(), c.getLng());
    });
    // 컨테이너 크기가 늦게 정해지는 경우를 대비해 한 번 다시 계산한다.
    setTimeout(function () { try { map.relayout(); map.setCenter(new k.LatLng(opts.lat, opts.lng)); } catch (e) { /* 무시 */ } }, 200);
    return id;
  }

  function clearOverlays(entry) {
    entry.overlays.forEach(function (o) { o.setMap(null); });
    entry.overlays = [];
    entry.items = [];
  }

  function overlaps(a, b) {
    return a.x1 < b.x2 && a.x2 > b.x1 && a.y1 < b.y2 && a.y2 > b.y1;
  }

  function nameBox(m, p, selected) {
    var textW = String(m.name).length * NAME_CHAR_W;
    var lines = Math.min(3, Math.max(1, Math.ceil(textW / NAME_MAX_W)));
    var w = Math.min(NAME_MAX_W, textW) + 4;
    var top = p.y + (selected ? 12 : PILL_H / 2 + 2);
    return { x1: p.x - w / 2, x2: p.x + w / 2, y1: top, y2: top + lines * NAME_LINE_H };
  }

  // 알약은 항상 보이고, 이름은 이미 놓인 알약·이름과 겹치면 숨긴다.
  // 우선순위: 선택된 핀 → 검색 결과 순서(서버가 거리순으로 준다).
  function layoutLabels(entry) {
    if (!entry.items || entry.items.length === 0) return;
    var proj;
    try {
      proj = entry.map.getProjection();
    } catch (e) { return; }
    var k = window.kakao.maps;
    var points = entry.items.map(function (it) { return proj.containerPointFromCoords(new k.LatLng(it.m.lat, it.m.lng)); });
    var placed = [];

    // 모든 알약(선택된 핀은 꼬리까지)이 차지하는 자리를 장애물로 둔다.
    entry.items.forEach(function (it, i) {
      var p = points[i];
      var w = it.pillW;
      if (it.selected) placed.push({ x1: p.x - w / 2, x2: p.x + w / 2, y1: p.y - 46, y2: p.y });
      else placed.push({ x1: p.x - w / 2, x2: p.x + w / 2, y1: p.y - PILL_H / 2, y2: p.y + PILL_H / 2 });
    });
    // 선택된 핀의 이름이 먼저 자리를 잡는다.
    entry.items.forEach(function (it, i) {
      if (!it.selected) return;
      var box = nameBox(it.m, points[i], true);
      it.name.style.display = '';
      placed.push(box);
    });
    entry.items.forEach(function (it, i) {
      if (it.selected) return;
      var box = nameBox(it.m, points[i], false);
      var hit = placed.some(function (r) { return overlaps(box, r); });
      if (hit) {
        it.name.style.display = 'none';
      } else {
        it.name.style.display = '';
        placed.push(box);
      }
    });
  }

  function setMarkers(id, markersJson, selectedId, fit) {
    var entry = maps[id];
    if (!entry) return;
    var k = window.kakao.maps;
    var list = JSON.parse(markersJson);
    clearOverlays(entry);
    var tap = function (mid) { entry.onMarkerTap(mid); };

    // 선택되지 않은 핀을 먼저 그리고, 선택된 핀을 맨 위에 올린다.
    var ordered = list.slice().sort(function (a, b) {
      return (a.id === selectedId ? 1 : 0) - (b.id === selectedId ? 1 : 0);
    });
    var made = {};
    ordered.forEach(function (m) {
      var selected = m.id === selectedId;
      var pin = pinEl(m, selected, tap);
      var overlay = new k.CustomOverlay({
        position: new k.LatLng(m.lat, m.lng),
        content: pin.el,
        yAnchor: selected ? 1 : 0.5,
        xAnchor: 0.5,
        zIndex: selected ? 10 : 1,
        clickable: true,
      });
      overlay.setMap(entry.map);
      entry.overlays.push(overlay);
      made[m.id] = { m: m, selected: selected, name: pin.name, pillW: pillWidth(m, selected) };
    });
    // 이름 우선순위는 검색 결과 순서(거리순)이므로, 그리는 순서(ordered)와 별개로 원래 순서대로 담는다.
    entry.items = list.map(function (m) { return made[m.id]; });
    // 지도가 새로 그려진 뒤 좌표 변환이 가능하므로 잠깐 뒤에 한 번, 이후에는 idle 때마다 계산한다.
    setTimeout(function () { layoutLabels(entry); }, 60);

    if (fit && list.length > 0) {
      entry.quietUntil = Date.now() + 1500;
      if (list.length === 1) {
        entry.map.setLevel(3);
        entry.map.setCenter(new k.LatLng(list[0].lat, list[0].lng));
      } else {
        var bounds = new k.LatLngBounds();
        list.forEach(function (m) { bounds.extend(new k.LatLng(m.lat, m.lng)); });
        // 위·오른쪽·아래·왼쪽 여백. 아래는 하단 카드에 가려지지 않게 넉넉히.
        entry.map.setBounds(bounds, 120, 40, 340, 40);
      }
    } else if (selectedId) {
      // 선택한 가게가 하단 카드에 가려지지 않게 화면 위쪽 1/3 지점으로 살짝 옮긴다.
      var sel = list.filter(function (m) { return m.id === selectedId; })[0];
      if (sel) panToUpperThird(entry, sel);
    }
  }

  function panToUpperThird(entry, sel) {
    var k = window.kakao.maps;
    try {
      var map = entry.map;
      var proj = map.getProjection();
      var el = map.getNode();
      var w = el.clientWidth;
      var h = el.clientHeight;
      var p = proj.containerPointFromCoords(new k.LatLng(sel.lat, sel.lng));
      var dx = p.x - w / 2;
      var dy = p.y - h * 0.32;
      var target = proj.coordsFromContainerPoint(new k.Point(w / 2 + dx, h / 2 + dy));
      entry.quietUntil = Date.now() + 1500;
      map.panTo(target);
    } catch (e) {
      entry.quietUntil = Date.now() + 1500;
      entry.map.panTo(new k.LatLng(sel.lat, sel.lng));
    }
  }

  function moveTo(id, lat, lng) {
    var entry = maps[id];
    if (!entry) return;
    entry.quietUntil = Date.now() + 1500;
    entry.map.setCenter(new window.kakao.maps.LatLng(lat, lng));
  }

  // 현재 위치를 JSON 문자열({"lat":..,"lng":..})로. 못 가져오면 null. (https 에서만 가능)
  function locate() {
    return new Promise(function (resolve) {
      if (!window.isSecureContext || !navigator.geolocation) { resolve(null); return; }
      navigator.geolocation.getCurrentPosition(
        function (pos) { resolve(JSON.stringify({ lat: pos.coords.latitude, lng: pos.coords.longitude })); },
        function () { resolve(null); },
        { enableHighAccuracy: true, timeout: 8000, maximumAge: 30000 }
      );
    });
  }

  function destroy(id) {
    var entry = maps[id];
    if (!entry) return;
    clearOverlays(entry);
    delete maps[id];
  }

  window.zzinMap = { load: load, create: create, setMarkers: setMarkers, moveTo: moveTo, locate: locate, destroy: destroy };
})();
