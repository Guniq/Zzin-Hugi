// 카카오맵 JavaScript SDK 를 Flutter(Dart)에서 쓰기 쉽게 감싼 얇은 레이어.
// Dart 쪽은 window.zzinMap 의 함수만 부른다. 카카오 API 호출은 모두 이 파일 안에 둔다.
//
// 흐름: load(appKey) → create(el, opts, onMarkerTap, onUserMoved) → setMarkers / moveTo / locate → destroy
(function () {
  'use strict';

  var INK = '#121417';
  var ACCENT = '#C93C1C';
  var GREY = '#9AA0A6';
  var LOAD_TIMEOUT_MS = 10000;

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

  function dotEl(m, onTap) {
    var wrap = document.createElement('div');
    wrap.style.cssText = 'padding:10px;cursor:pointer;';
    var dot = document.createElement('div');
    dot.style.cssText =
      'width:18px;height:18px;border-radius:50%;box-sizing:border-box;border:3px solid #fff;' +
      'box-shadow:0 1px 4px rgba(18,20,23,.4);background:' + (m.blocked ? GREY : INK) + ';';
    wrap.appendChild(dot);
    wrap.addEventListener('click', function (e) { e.stopPropagation(); onTap(m.id); });
    return wrap;
  }

  function pinEl(m, onTap) {
    var wrap = document.createElement('div');
    wrap.style.cssText = 'display:flex;flex-direction:column;align-items:center;cursor:pointer;';
    var label = document.createElement('div');
    label.textContent = m.name; // innerHTML 을 쓰지 않는다 (가게 이름은 외부 데이터)
    label.style.cssText =
      'padding:5px 10px;border-radius:12px;background:' + INK + ';color:#fff;font:700 13px/1.2 "Noto Sans KR",sans-serif;' +
      'white-space:nowrap;max-width:200px;overflow:hidden;text-overflow:ellipsis;box-shadow:0 2px 8px rgba(18,20,23,.3);';
    var svgNs = 'http://www.w3.org/2000/svg';
    var svg = document.createElementNS(svgNs, 'svg');
    svg.setAttribute('width', '34');
    svg.setAttribute('height', '44');
    svg.setAttribute('viewBox', '0 0 34 44');
    svg.style.cssText = 'margin-top:2px;filter:drop-shadow(0 2px 3px rgba(18,20,23,.35));';
    var path = document.createElementNS(svgNs, 'path');
    path.setAttribute('d', 'M17 43C17 43 3 28 3 17A14 14 0 0131 17C31 28 17 43 17 43Z');
    path.setAttribute('fill', m.blocked ? GREY : ACCENT);
    path.setAttribute('stroke', '#fff');
    path.setAttribute('stroke-width', '2.5');
    var circle = document.createElementNS(svgNs, 'circle');
    circle.setAttribute('cx', '17');
    circle.setAttribute('cy', '17');
    circle.setAttribute('r', '6');
    circle.setAttribute('fill', '#fff');
    svg.appendChild(path);
    svg.appendChild(circle);
    wrap.appendChild(label);
    wrap.appendChild(svg);
    wrap.addEventListener('click', function (e) { e.stopPropagation(); onTap(m.id); });
    return wrap;
  }

  function create(el, optsJson, onMarkerTap, onUserMoved) {
    var k = window.kakao.maps;
    var opts = JSON.parse(optsJson);
    var map = new k.Map(el, { center: new k.LatLng(opts.lat, opts.lng), level: opts.level || 4 });
    var id = nextId++;
    var entry = { map: map, overlays: [], quietUntil: Date.now() + 1500, onMarkerTap: onMarkerTap };
    maps[id] = entry;

    // 프로그램이 지도를 옮긴 뒤의 idle 은 사용자가 움직인 게 아니므로 무시한다.
    k.event.addListener(map, 'idle', function () {
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
    ordered.forEach(function (m) {
      var selected = m.id === selectedId;
      var overlay = new k.CustomOverlay({
        position: new k.LatLng(m.lat, m.lng),
        content: selected ? pinEl(m, tap) : dotEl(m, tap),
        yAnchor: selected ? 1 : 0.5,
        xAnchor: 0.5,
        zIndex: selected ? 10 : 1,
        clickable: true,
      });
      overlay.setMap(entry.map);
      entry.overlays.push(overlay);
    });

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
