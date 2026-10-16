'use strict';
/* 내 루틴: myroutine 앱 기능을 참고해 만든 로컬 우선 루틴 앱. 데이터는 이 브라우저의 localStorage에만 저장된다. */

const KEY = 'myroutine.v1';
const COLORS = ['#FFE8E8', '#FFF1D6', '#FFFDE9', '#E3F7E8', '#DDF1FF', '#EBE4FF', '#FFE4F3', '#EFEFEF'];
const MOODS = ['😭', '😟', '😐', '🙂', '😄'];
const DOW = ['일', '월', '화', '수', '목', '금', '토'];
const LEVELS = { mini: 'Mini', plus: 'Plus', max: 'Max' };
const MAX_MODES = 10;
const GREEN_AT = 0.6;
const YELLOW_AT = 0.2;

/* ---------- 날짜 유틸 ---------- */
const pad = (n) => String(n).padStart(2, '0');
const ymd = (d) => `${d.getFullYear()}-${pad(d.getMonth() + 1)}-${pad(d.getDate())}`;
const parse = (s) => { const [y, m, d] = s.split('-').map(Number); return new Date(y, m - 1, d); };
const addDays = (s, n) => { const d = parse(s); d.setDate(d.getDate() + n); return ymd(d); };
const weekStart = (s) => addDays(s, -((parse(s).getDay() + 6) % 7)); // 월요일 시작
const today = () => ymd(new Date());
const uid = () => Math.random().toString(36).slice(2, 10);
const esc = (s) => String(s ?? '').replace(/[&<>"']/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));
const $ = (s, el = document) => el.querySelector(s);

/* ---------- 상태 ---------- */
function defaultState() {
  const t = today();
  return {
    version: 1,
    modes: [{ id: 'm1', name: '기본' }],
    activeMode: 'm1',
    habits: [
      mkHabit({ emoji: '💧', name: '아침에 물 한 잔', time: '07:00', color: COLORS[4], start: t }),
      mkHabit({ emoji: '🧘', name: '스트레칭 10분', time: '', context: '점심 먹고', color: COLORS[3], start: t }),
      mkHabit({ emoji: '📖', name: '책 10쪽 읽기', time: '22:00', color: COLORS[5], start: t, alarm: '22:00' }),
    ],
    todos: [],
    logs: {},      // { 'YYYY-MM-DD': { habitId: { done, level, alt, value } } }
    rest: {},      // { 'YYYY-MM-DD': true }
    reviews: {},   // { 'YYYY-MM-DD': { mood, best, msg } }
    memos: [],     // { id, date, kind: 'short'|'long', text, hl }
    settings: { theme: 'auto', rolling: true, doneToBottom: true },
  };
}
function mkHabit(o) {
  return {
    id: uid(), emoji: '✅', name: '', time: '', context: '', color: COLORS[3],
    repeat: { type: 'daily', days: [1, 2, 3, 4, 5], times: 3, every: 2, monthDays: [1] },
    levels: { mini: '', plus: '', max: '' }, alts: [], alarm: '', unit: '', timerMin: 0,
    modes: [], archived: false, start: today(), ...o,
  };
}
function load() {
  const raw = localStorage.getItem(KEY);
  if (!raw) return defaultState();
  try {
    return { ...defaultState(), ...JSON.parse(raw) };
  } catch (err) {
    console.error('저장된 데이터를 읽지 못했다. 원본은 별도 키에 보관한다.', err);
    localStorage.setItem(`${KEY}.corrupt.${Date.now()}`, raw);
    return defaultState();
  }
}
let S = load();
const save = () => localStorage.setItem(KEY, JSON.stringify(S));

const ui = { tab: 'home', sub: 'routine', date: today(), view: 'day', edit: false, filter: 'all', range: 'rolling7' };

/* ---------- 도메인 로직 ---------- */
const inMode = (h) => !h.modes.length || h.modes.includes(S.activeMode);
const logOf = (id, date) => S.logs[date]?.[id];
const isDone = (id, date) => !!logOf(id, date)?.done;
function weekDoneCount(h, date) {
  const ws = weekStart(date); let c = 0;
  for (let i = 0; i < 7; i++) if (isDone(h.id, addDays(ws, i))) c++;
  return c;
}
function isDue(h, date) {
  if (h.archived || date < h.start) return false;
  const r = h.repeat;
  if (r.type === 'daily') return true;
  if (r.type === 'weekdays') return r.days.includes(parse(date).getDay());
  if (r.type === 'interval') {                        // N일마다 (시작일 기준)
    const diff = Math.round((parse(date) - parse(h.start)) / 864e5);
    return diff >= 0 && diff % Math.max(1, r.every || 2) === 0;
  }
  if (r.type === 'monthdays') return (r.monthDays || []).includes(parse(date).getDate());
  if (isDone(h.id, date)) return true;               // 주 N회: 이미 체크한 날은 표시
  if (date < today()) return false;                   // 지난 날 미체크는 실패로 세지 않는다
  return weekDoneCount(h, date) < r.times;
}
function dueHabits(date) { return S.habits.filter((h) => inMode(h) && isDue(h, date)); }
function dayStat(date) {
  if (S.rest[date]) return { rest: true, rate: null, due: 0, done: 0 };
  const list = dueHabits(date);
  const done = list.filter((h) => isDone(h.id, date)).length;
  return { rest: false, due: list.length, done, rate: list.length ? done / list.length : null };
}
function light(rate) {
  if (rate == null) return '';
  return rate >= GREEN_AT ? 'g' : rate >= YELLOW_AT ? 'y' : 'r';
}
function streak() {
  let d = today(), n = 0;
  const st0 = dayStat(d);
  if (!st0.rest && st0.rate != null && st0.rate < GREEN_AT) d = addDays(d, -1); // 오늘은 아직 진행 중
  for (let i = 0; i < 3650; i++, d = addDays(d, -1)) {
    const st = dayStat(d);
    if (st.rest || st.rate == null) { if (d < firstDate()) break; continue; }
    if (st.rate >= GREEN_AT) n++; else break;
  }
  return n;
}
function firstDate() {
  const ds = S.habits.map((h) => h.start).sort();
  return ds[0] || today();
}
function habitStreak(h) {
  let d = today(), n = 0;
  if (!isDone(h.id, d)) d = addDays(d, -1);
  for (let i = 0; i < 3650 && d >= h.start; i++, d = addDays(d, -1)) {
    if (S.rest[d]) continue;
    if (!isDue(h, d) && !isDone(h.id, d)) continue;
    if (isDone(h.id, d)) n++; else break;
  }
  return n;
}
function setLog(id, date, patch) {
  const day = (S.logs[date] ??= {});
  day[id] = { ...(day[id] || {}), ...patch };
  save();
}

/* ---------- 렌더링 ---------- */
function toast(msg) {
  const t = $('#toast'); t.textContent = msg; t.classList.remove('hidden');
  clearTimeout(toast.t); toast.t = setTimeout(() => t.classList.add('hidden'), 2200);
}
function applyTheme() {
  const t = S.settings.theme;
  if (t === 'auto') document.documentElement.removeAttribute('data-theme');
  else document.documentElement.setAttribute('data-theme', t);
}
const WIDGET = new URLSearchParams(location.search).has('widget');

// 위젯용 화면: 오늘의 루틴만 크게 보여 준다. 홈 화면에 바로가기로 두고 쓴다.
function renderWidget() {
  const d = today(), st = dayStat(d), pct = st.rate == null ? 0 : Math.round(st.rate * 100);
  const hs = dueHabits(d);
  const rows = hs.map((h) => `<div class="row w-row ${isDone(h.id, d) ? 'done' : ''}" style="background:${h.color}">
      <div class="num"></div><div class="meta"><span class="t">${esc(h.time || h.context || '언제든')}</span><b>${esc(h.emoji)} ${esc(h.name)}</b></div>
      <button class="check ${isDone(h.id, d) ? 'on' : ''}" data-act="toggle" data-id="${h.id}">${isDone(h.id, d) ? esc(h.emoji) : ''}</button></div>`).join('');
  return `<div class="widget"><div class="topbar"><div class="month">오늘의 루틴</div><a class="chip" href="index.html">앱 열기</a></div>
    <div class="summary"><b>${pct}%</b><div class="bar"><i style="width:${pct}%"></i></div><span>${st.done}/${st.due}</span></div>
    <div class="list">${rows || '<div class="empty">오늘 할 습관이 없어요.</div>'}</div></div>`;
}

function render() {
  applyTheme();
  if (WIDGET) { ui.date = today(); $('#app').innerHTML = renderWidget(); return; }
  const body = ui.tab === 'home' ? renderHome() : ui.tab === 'stats' ? renderStats() : renderSettings();
  const nav = [['home', '🏠', '홈'], ['stats', '📊', '통계'], ['settings', '⚙️', '설정']]
    .map(([k, i, l]) => `<button data-act="nav" data-v="${k}" class="${ui.tab === k ? 'on' : ''}"><span>${i}</span>${l}</button>`).join('');
  $('#app').innerHTML = `${body}<nav class="nav"><div class="nav-in">${nav}</div></nav>`;
}

function weekStrip() {
  const ws = weekStart(ui.date);
  let h = '';
  for (let i = 0; i < 7; i++) {
    const d = addDays(ws, i), st = dayStat(d);
    const future = d > today();
    const inProgress = d === today() && st.rate === 0; // 오늘은 아직 진행 중이므로 0%여도 빨강으로 두지 않는다
    const cls = st.rest ? 'rest' : future || inProgress ? '' : light(st.rate);
    h += `<button class="wd ${d === ui.date ? 'sel' : ''} ${d === today() ? 'today' : ''}" data-act="pick" data-v="${d}">
      <span>${DOW[parse(d).getDay()]}</span><i class="dot ${cls}">${parse(d).getDate()}</i></button>`;
  }
  return `<div class="week">${h}</div>`;
}

function renderHome() {
  const d = parse(ui.date);
  const mode = S.modes.find((m) => m.id === S.activeMode);
  const st = dayStat(ui.date);
  const top = `<div class="topbar">
    <button class="month" data-act="datepick">${d.getFullYear()}년 ${d.getMonth() + 1}월 <span>📅</span></button>
    <div style="display:flex;gap:6px;align-items:center">
      <button class="chip" data-act="modes">🗂 ${esc(mode?.name || '모드')}</button>
      <button class="chip ${S.rest[ui.date] ? 'on' : ''}" data-act="rest">🌴 쉼</button>
    </div></div>`;
  const tabs = `<div class="tabs">
    <button class="tab ${ui.sub === 'routine' ? 'on' : ''}" data-act="sub" data-v="routine">루틴</button>
    <button class="tab ${ui.sub === 'review' ? 'on' : ''}" data-act="sub" data-v="review">회고</button></div>`;
  const pct = st.rate == null ? 0 : Math.round(st.rate * 100);
  const sum = ui.sub === 'routine' ? `<div class="summary">
      <span>${S.rest[ui.date] ? '🌴 쉬는 날' : `<b>${pct}%</b>`}</span>
      <div class="bar"><i style="width:${pct}%;background:var(--${{ g: 'green', y: 'yellow', r: 'red', '': 'gray' }[light(st.rate)]})"></i></div>
      <span>🔥 ${streak()}일</span></div>` : '';
  const main = ui.sub === 'routine' ? renderRoutine() : renderReview();
  return `${top}${weekStrip()}${tabs}${sum}${main}`;
}

function habitRow(h, n, list) {
  const done = isDone(h.id, ui.date);
  const lg = logOf(h.id, ui.date);
  const label = lg?.alt || h.name;
  const sub = [lg?.level ? LEVELS[lg.level] : '', lg?.value ? `${lg.value}${h.unit}` : '', habitStreak(h) >= 2 ? `🔥${habitStreak(h)}` : '', h.alarm ? `🔔${h.alarm}` : '']
    .filter(Boolean).join('  ');
  const idx = list.indexOf(h);
  const right = ui.edit
    ? `<div class="edit-actions"><button data-act="up" data-id="${h.id}" ${idx === 0 ? 'disabled' : ''}>▲</button><button data-act="down" data-id="${h.id}" ${idx === list.length - 1 ? 'disabled' : ''}>▼</button><button data-act="editHabit" data-id="${h.id}">✏️</button></div>`
    : `<button class="check ${done ? 'on' : ''}" data-act="toggle" data-id="${h.id}" aria-label="체크">${done ? esc(h.emoji) : ''}</button>`;
  return `<div class="row ${done ? 'done' : ''}" style="background:${h.color}">
    <div class="num">${n}</div>
    <button class="meta" data-act="detail" data-id="${h.id}"><span class="t">${esc(h.time || h.context || '언제든')}</span>
      <b>${esc(h.emoji)} ${esc(label)}</b>${sub ? `<small>${esc(sub)}</small>` : ''}</button>${right}</div>`;
}
function todoRow(t) {
  const late = t.date < ui.date;
  return `<div class="row todo ${t.done ? 'done' : ''}">
    <div class="num">TODO</div>
    <button class="meta" data-act="editTodo" data-id="${t.id}"><span class="t">${late ? `${t.date.slice(5)} 에서 이월` : '투두'}</span><b>${esc(t.text)}</b></button>
    <button class="check ${t.done ? 'on' : ''}" data-act="todoToggle" data-id="${t.id}">${t.done ? '✓' : ''}</button></div>`;
}
function visibleTodos() {
  const isToday = ui.date === today();
  return S.todos.filter((t) => t.date === ui.date || (isToday && t.date < ui.date && !t.done));
}

function renderRoutine() {
  const bar = `<div class="toolbar">
    <div class="seg"><button class="${ui.view === 'day' ? 'on' : ''}" data-act="view" data-v="day">일간</button><button class="${ui.view === 'week' ? 'on' : ''}" data-act="view" data-v="week">주간</button></div>
    <span class="grow"></span>
    <button class="chip ${ui.edit ? 'on' : ''}" data-act="edit">${ui.edit ? '완료' : '편집'}</button>
    <button class="chip" data-act="filter">필터: ${{ all: '전체', undone: '미완료', done: '완료' }[ui.filter]}</button></div>`;
  if (ui.view === 'week') return bar + renderWeekGrid() + fab();
  let habits = dueHabits(ui.date);
  const all = habits.slice();
  if (ui.filter === 'undone') habits = habits.filter((h) => !isDone(h.id, ui.date));
  if (ui.filter === 'done') habits = habits.filter((h) => isDone(h.id, ui.date));
  if (S.settings.doneToBottom && !ui.edit) habits = [...habits.filter((h) => !isDone(h.id, ui.date)), ...habits.filter((h) => isDone(h.id, ui.date))];
  let todos = visibleTodos();
  if (ui.filter === 'undone') todos = todos.filter((t) => !t.done);
  if (ui.filter === 'done') todos = todos.filter((t) => t.done);
  if (S.settings.doneToBottom) todos = [...todos.filter((t) => !t.done), ...todos.filter((t) => t.done)];
  const rows = habits.map((h, i) => habitRow(h, i + 1, ui.edit ? all : habits)).join('') + todos.map(todoRow).join('');
  const empty = `<div class="empty">${S.rest[ui.date] ? '🌴 쉬는 날이에요. 스트릭은 끊기지 않아요.' : '이 날의 루틴이 없어요.<br>아래 + 버튼으로 습관이나 투두를 추가해 보세요.'}</div>`;
  return bar + `<div class="list">${rows || empty}</div>` + fab();
}
const fab = () => `<button class="fab" data-act="add" aria-label="추가">+</button>`;

function renderWeekGrid() {
  const ws = weekStart(ui.date);
  const days = Array.from({ length: 7 }, (_, i) => addDays(ws, i));
  const hs = S.habits.filter((h) => inMode(h) && !h.archived);
  if (!hs.length) return '<div class="empty">습관이 없어요.</div>' + '';
  const head = `<tr><th></th>${days.map((d) => `<th>${DOW[parse(d).getDay()]}<br>${parse(d).getDate()}</th>`).join('')}</tr>`;
  const rows = hs.map((h) => {
    const cells = days.map((d, i) => {
      const due = isDue(h, d), done = isDone(h.id, d);
      const last = i === 6 ? ' last' : '';
      return `<td class="${last}" style="background:${h.color}"><button class="gcell ${done ? 'on' : ''} ${!due && !done ? 'na' : ''}" data-act="gtoggle" data-id="${h.id}" data-v="${d}">${done ? esc(h.emoji) : ''}</button></td>`;
    }).join('');
    return `<tr><td class="name" style="background:${h.color}">${esc(h.emoji)} ${esc(h.name)}</td>${cells}</tr>`;
  }).join('');
  return `<table class="grid-week">${head}${rows}</table>`;
}

function renderReview() {
  const r = S.reviews[ui.date] || {};
  const memos = S.memos.filter((m) => m.date === ui.date);
  const st = dayStat(ui.date);
  return `<div class="card"><h4>오늘의 기분</h4>
      <div class="moods">${MOODS.map((m, i) => `<button class="${r.mood === i + 1 ? 'on' : ''}" data-act="mood" data-v="${i + 1}">${m}</button>`).join('')}</div></div>
    <div class="card"><h4>데일리 회고</h4>
      <div class="field"><label>오늘 가장 좋았던 일</label><textarea data-bind="best">${esc(r.best || '')}</textarea></div>
      <div class="field"><label>나에게 한마디</label><textarea data-bind="msg">${esc(r.msg || '')}</textarea></div>
      <div class="lab">오늘 루틴 달성: ${st.rest ? '쉼' : `${st.done}/${st.due}`}</div></div>
    <div class="card"><h4>메모</h4>
      ${memos.map((m) => `<div class="memo ${m.hl ? 'hl' : ''}" data-act="memo" data-id="${m.id}">${m.kind === 'long' ? '📝 ' : '💬 '}${esc(m.text)}</div>`).join('') || '<div class="lab">아직 메모가 없어요.</div>'}
      <div class="btns"><button class="btn" data-act="newMemo" data-v="short">짧은 메모</button><button class="btn" data-act="newMemo" data-v="long">긴 메모</button></div></div>`;
}

/* ---------- 통계 ---------- */
function rangeDates() {
  const t = today();
  if (ui.range === 'rolling7') return Array.from({ length: 7 }, (_, i) => addDays(t, i - 6));
  if (ui.range === 'rolling30') return Array.from({ length: 30 }, (_, i) => addDays(t, i - 29));
  if (ui.range === 'week') { const ws = weekStart(t); return Array.from({ length: 7 }, (_, i) => addDays(ws, i)).filter((d) => d <= t); }
  const d = parse(t); const first = ymd(new Date(d.getFullYear(), d.getMonth(), 1));
  const out = []; for (let x = first; x <= t; x = addDays(x, 1)) out.push(x); return out;
}
function renderStats() {
  const dates = rangeDates();
  const sts = dates.map(dayStat);
  const rated = sts.filter((s) => s.rate != null);
  const avg = rated.length ? rated.reduce((a, s) => a + s.rate, 0) / rated.length : 0;
  const greens = rated.filter((s) => s.rate >= GREEN_AT).length;
  const seg = [['rolling7', '최근 7일'], ['rolling30', '최근 30일'], ['week', '이번 주'], ['month', '이번 달']]
    .map(([k, l]) => `<button class="${ui.range === k ? 'on' : ''}" data-act="range" data-v="${k}">${l}</button>`).join('');
  const per = S.habits.filter((h) => !h.archived && inMode(h)).map((h) => {
    let due = 0, done = 0;
    dates.forEach((d) => { if (S.rest[d]) return; if (isDone(h.id, d)) { due++; done++; } else if (isDue(h, d)) due++; });
    const p = due ? Math.round((done / due) * 100) : 0;
    return `<div class="stat-row"><span>${esc(h.emoji)} ${esc(h.name)}</span><b>${p}%</b><div class="bar"><i style="width:${p}%"></i></div></div>`;
  }).join('') || '<div class="lab">습관이 없어요.</div>';
  const days = dates.map((d, i) => `<i class="dot ${S.rest[d] ? 'rest' : light(sts[i].rate)}" style="display:inline-grid;width:22px;height:22px;margin:2px;font-size:10px">${parse(d).getDate()}</i>`).join('');
  return `<div class="topbar"><div class="month">통계</div></div>
    <div class="toolbar"><div class="seg">${seg}</div></div>
    <div class="card"><h4>달성률</h4><div style="font-size:30px;font-weight:900">${Math.round(avg * 100)}%</div>
      <div class="lab">초록불 ${greens}일 / 기록된 ${rated.length}일 (초록 ${Math.round(GREEN_AT * 100)}% 이상, 노랑 ${Math.round(YELLOW_AT * 100)}% 이상)</div>
      <div style="margin-top:8px">${days}</div></div>
    <div class="stats-grid"><div class="card"><h4>습관별 달성률</h4>${per}</div>
    ${renderMoodCal()}${renderBadges()}</div>`;
}
function renderMoodCal() {
  const base = parse(ui.date);
  const y = base.getFullYear(), m = base.getMonth();
  const first = new Date(y, m, 1), len = new Date(y, m + 1, 0).getDate();
  let cells = DOW.map((d) => `<div class="h">${d}</div>`).join('') + '<div></div>'.repeat(first.getDay());
  for (let i = 1; i <= len; i++) {
    const d = ymd(new Date(y, m, i)); const mood = S.reviews[d]?.mood;
    cells += `<div class="c"><small>${i}</small>${mood ? MOODS[mood - 1] : ''}</div>`;
  }
  return `<div class="card"><h4>${y}년 ${m + 1}월 무드 캘린더</h4><div class="cal">${cells}</div></div>`;
}
function renderBadges() {
  const total = Object.values(S.logs).reduce((a, day) => a + Object.values(day).filter((l) => l.done).length, 0);
  const s = streak();
  const reviews = Object.values(S.reviews).filter((r) => r.best || r.msg || r.mood).length;
  const list = [
    ['🌱 첫 체크', total >= 1], ['🔥 3일 연속', s >= 3], ['🔥 7일 연속', s >= 7], ['🏅 30일 연속', s >= 30], ['👑 100일 연속', s >= 100],
    ['✅ 100회 체크', total >= 100], ['✅ 500회 체크', total >= 500], ['✏️ 회고 7일', reviews >= 7],
  ];
  return `<div class="card"><h4>배지 (누적 체크 ${total}회)</h4><div class="badges">${list.map(([l, on]) => `<span class="badge ${on ? 'on' : ''}">${l}</span>`).join('')}</div></div>`;
}

/* ---------- 설정 ---------- */
function renderSettings() {
  const notif = 'Notification' in window ? Notification.permission : 'unsupported';
  const sel = (v, l) => `<option value="${v}" ${S.settings.theme === v ? 'selected' : ''}>${l}</option>`;
  return `<div class="topbar"><div class="month">설정</div></div>
    <div class="setrow"><div>화면 테마</div><select data-set="theme" style="width:130px">${sel('auto', '시스템')}${sel('light', '라이트')}${sel('dark', '다크')}</select></div>
    <div class="setrow"><div>완료 항목을 아래로<small>체크하면 목록 맨 아래로 내려가요</small></div><input type="checkbox" data-set="doneToBottom" ${S.settings.doneToBottom ? 'checked' : ''} style="width:auto"></div>
    <div class="setrow"><div>루틴 모드<small>${S.modes.length}/${MAX_MODES}개. 홈 상단에서 바로 바꿀 수 있어요</small></div><button class="chip" data-act="modes">관리</button></div>
    <div class="setrow"><div>알림<small>앱이 열려 있을 때 습관의 알람 시각에 알려요 (${notif})</small></div><button class="chip" data-act="notif">허용하기</button></div>
    <div class="sec-title">데이터</div>
    <div class="setrow"><div>백업 내보내기<small>JSON 파일로 저장</small></div><button class="chip" data-act="export">내보내기</button></div>
    <div class="setrow"><div>백업 불러오기<small>현재 데이터를 덮어써요</small></div><button class="chip" data-act="import">불러오기</button></div>
    <div class="setrow"><div>보관된 습관<small>삭제 대신 보관한 습관 ${S.habits.filter((h) => h.archived).length}개</small></div><button class="chip" data-act="archived">보기</button></div>
    <div class="setrow"><div style="color:var(--red)">모든 데이터 지우기</div><button class="chip" data-act="wipe">지우기</button></div>
    <p class="lab" style="margin-top:20px">데이터는 이 기기의 브라우저에만 저장돼요. 서버로 전송되지 않아요.</p>`;
}

/* ---------- 시트(모달) ---------- */
function openSheet(html) { $('#sheetBody').innerHTML = html; $('#sheet').classList.remove('hidden'); }
function closeSheet() { $('#sheet').classList.add('hidden'); $('#sheetBody').innerHTML = ''; stopTimer(); }

function addMenu() {
  openSheet(`<h3>추가하기</h3><div class="btns" style="margin-top:0">
    <button class="btn" data-act="newHabit">🌿 습관</button><button class="btn" data-act="newTodo">☑️ 투두</button></div>`);
}

function habitForm(id) {
  const h = id ? S.habits.find((x) => x.id === id) : mkHabit({});
  const r = h.repeat;
  openSheet(`<h3>${id ? '습관 편집' : '새 습관'}</h3>
  <form id="hf" data-id="${id || ''}">
    <div class="field row3"><div><label>이모지</label><input name="emoji" value="${esc(h.emoji)}" maxlength="4" style="text-align:center;font-size:22px"></div>
      <div><label>이름</label><input name="name" value="${esc(h.name)}" placeholder="예: 아침에 물 한 잔" required></div></div>
    <div class="field row2"><div><label>시각</label><input type="time" name="time" value="${esc(h.time)}"></div>
      <div><label>또는 상황</label><input name="context" value="${esc(h.context)}" placeholder="출근길에, 점심 먹고"></div></div>
    <div class="field"><label>반복</label>
      <select name="rtype"><option value="daily" ${r.type === 'daily' ? 'selected' : ''}>매일</option><option value="weekdays" ${r.type === 'weekdays' ? 'selected' : ''}>요일 지정</option><option value="weekly" ${r.type === 'weekly' ? 'selected' : ''}>주 N회</option><option value="interval" ${r.type === 'interval' ? 'selected' : ''}>N일마다</option><option value="monthdays" ${r.type === 'monthdays' ? 'selected' : ''}>매월 특정 날짜</option></select></div>
    <div class="field row2"><div><label>N일마다 (간격)</label><input type="number" name="every" min="2" max="365" value="${r.every || 2}"></div>
      <div><label>매월 날짜 (쉼표로 구분)</label><input name="monthDays" value="${esc((r.monthDays || [1]).join(', '))}" placeholder="1, 15"></div></div>
    <div class="field"><label>요일 (요일 지정일 때)</label><div class="days">${[1, 2, 3, 4, 5, 6, 0].map((d) => `<label><input type="checkbox" name="days" value="${d}" ${r.days.includes(d) ? 'checked' : ''}><span>${DOW[d]}</span></label>`).join('')}</div></div>
    <div class="field"><label>주 몇 회 (주 N회일 때)</label><input type="number" name="times" min="1" max="7" value="${r.times}"></div>
    <div class="field"><label>난이도별 내용 (선택)</label>
      <div class="levels">${Object.keys(LEVELS).map((k) => `<input name="lv_${k}" value="${esc(h.levels[k])}" placeholder="${LEVELS[k]}: 예) ${{ mini: '1분만', plus: '10분', max: '30분' }[k]}">`).join('')}</div></div>
    <div class="field"><label>대체 이름 (쉼표로 구분)</label><input name="alts" value="${esc(h.alts.join(', '))}" placeholder="예: 요가, 산책"></div>
    <div class="field row2"><div><label>알람</label><input type="time" name="alarm" value="${esc(h.alarm)}"></div>
      <div><label>타이머(분)</label><input type="number" name="timerMin" min="0" max="240" value="${h.timerMin || 0}"></div></div>
    <div class="field"><label>수치 기록 단위 (선택)</label><input name="unit" value="${esc(h.unit)}" placeholder="예: 보, kg, 쪽"></div>
    <div class="field"><label>색상</label><div class="swatches">${COLORS.map((c) => `<label><input type="radio" name="color" value="${c}" ${h.color === c ? 'checked' : ''}><span style="background:${c}"></span></label>`).join('')}</div></div>
    <div class="field"><label>적용할 루틴 모드 (선택 안 하면 모두)</label>
      ${S.modes.map((m) => `<label style="display:inline-flex;gap:4px;margin-right:12px;font-size:14px;color:var(--text)"><input type="checkbox" name="modes" value="${m.id}" ${h.modes.includes(m.id) ? 'checked' : ''} style="width:auto">${esc(m.name)}</label>`).join('')}</div>
    <div class="btns">${id ? '<button type="button" class="btn danger" data-act="archiveHabit" data-id="' + id + '">보관</button>' : ''}<button type="button" class="btn" data-act="close">취소</button><button class="btn primary">저장</button></div>
  </form>`);
}
function saveHabitForm(form) {
  const f = new FormData(form); const id = form.dataset.id;
  const name = String(f.get('name')).trim();
  if (!name) { toast('이름을 입력해 주세요'); return; }
  const old = id ? S.habits.find((x) => x.id === id) : null;
  const next = mkHabit({
    ...(old || {}),
    emoji: String(f.get('emoji')).trim() || '✅', name,
    time: f.get('time') || '', context: String(f.get('context')).trim(),
    repeat: { type: f.get('rtype'), days: f.getAll('days').map(Number), times: Math.max(1, Math.min(7, Number(f.get('times')) || 3)),
      every: Math.max(2, Number(f.get('every')) || 2),
      monthDays: String(f.get('monthDays')).split(',').map((s) => Number(s.trim())).filter((n) => n >= 1 && n <= 31) },
    levels: { mini: String(f.get('lv_mini')).trim(), plus: String(f.get('lv_plus')).trim(), max: String(f.get('lv_max')).trim() },
    alts: String(f.get('alts')).split(',').map((s) => s.trim()).filter(Boolean),
    alarm: f.get('alarm') || '', timerMin: Number(f.get('timerMin')) || 0,
    unit: String(f.get('unit')).trim(), color: f.get('color') || COLORS[3], modes: f.getAll('modes'),
  });
  if (old) S.habits[S.habits.indexOf(old)] = { ...next, id: old.id, start: old.start };
  else S.habits.push(next);
  save(); closeSheet(); render(); toast('저장했어요');
}

function todoForm(id) {
  const t = id ? S.todos.find((x) => x.id === id) : { text: '', date: ui.date };
  openSheet(`<h3>${id ? '투두 편집' : '새 투두'}</h3><form id="tf" data-id="${id || ''}">
    <div class="field"><label>할 일</label><input name="text" value="${esc(t.text)}" required></div>
    <div class="field"><label>날짜</label><input type="date" name="date" value="${t.date}"></div>
    <div class="btns">${id ? `<button type="button" class="btn danger" data-act="delTodo" data-id="${id}">삭제</button>` : ''}<button type="button" class="btn" data-act="close">취소</button><button class="btn primary">저장</button></div></form>`);
}

function detailSheet(id) {
  const h = S.habits.find((x) => x.id === id); if (!h) return;
  const lg = logOf(id, ui.date) || {};
  const lv = Object.keys(LEVELS).map((k) => `<button class="lv ${lg.level === k ? 'on' : ''}" data-act="level" data-id="${id}" data-v="${k}"><b>${LEVELS[k]}</b><span>${esc(h.levels[k] || '-')}</span></button>`).join('');
  const alts = h.alts.length ? `<div class="field"><label>오늘은 이 이름으로</label><div class="alts">
      <button class="chip ${!lg.alt ? 'on' : ''}" data-act="alt" data-id="${id}" data-v="">${esc(h.name)}</button>
      ${h.alts.map((a) => `<button class="chip ${lg.alt === a ? 'on' : ''}" data-act="alt" data-id="${id}" data-v="${esc(a)}">${esc(a)}</button>`).join('')}</div></div>` : '';
  openSheet(`<h3>${esc(h.emoji)} ${esc(h.name)}</h3>
    <div class="lab">${esc(ui.date)}  ${h.time || h.context || ''}  / 연속 ${habitStreak(h)}일</div>
    <div class="field"><label>난이도</label><div class="levels">${lv}</div></div>${alts}
    ${h.unit ? `<div class="field"><label>오늘 기록 (${esc(h.unit)})</label><input type="number" step="any" data-act-change="value" data-id="${id}" value="${lg.value ?? ''}"></div>` : ''}
    ${h.timerMin ? `<div class="field"><label>타이머</label><div class="timer" id="timerView">${pad(h.timerMin)}:00</div>
       <div class="btns" style="margin-top:0"><button class="btn" data-act="timerStart" data-id="${id}">시작</button><button class="btn" data-act="timerStop">정지</button></div></div>` : ''}
    <div class="btns"><button class="btn" data-act="editHabit" data-id="${id}">편집</button><button class="btn primary" data-act="close">닫기</button></div>`);
}

let timerId = null;
function stopTimer() { if (timerId) { clearInterval(timerId); timerId = null; } }
function startTimer(id) {
  const h = S.habits.find((x) => x.id === id); stopTimer();
  let left = h.timerMin * 60;
  const view = () => { const el = $('#timerView'); if (el) el.textContent = `${pad(Math.floor(left / 60))}:${pad(left % 60)}`; };
  view();
  timerId = setInterval(() => {
    left--; view();
    if (left <= 0) {
      stopTimer(); setLog(id, ui.date, { done: true }); navigator.vibrate?.([200, 100, 200]);
      toast(`${h.name} 완료!`); render();
    }
  }, 1000);
}

function modesSheet() {
  openSheet(`<h3>루틴 모드</h3><div class="lab">모드를 누르면 바로 적용돼요. 습관마다 적용할 모드를 고를 수 있어요.</div>
    <div class="list" style="margin-top:8px">${S.modes.map((m) => `<div class="row" style="background:var(--card);grid-template-columns:1fr auto auto;border:1px solid ${m.id === S.activeMode ? 'var(--green)' : 'var(--line)'}">
      <button class="meta" data-act="applyMode" data-id="${m.id}"><b>${m.id === S.activeMode ? '✅ ' : ''}${esc(m.name)}</b></button>
      <button class="chip" data-act="renameMode" data-id="${m.id}">이름</button>
      <button class="chip" data-act="delMode" data-id="${m.id}" ${S.modes.length === 1 ? 'disabled' : ''}>삭제</button></div>`).join('')}</div>
    <div class="btns"><button class="btn" data-act="addMode" ${S.modes.length >= MAX_MODES ? 'disabled' : ''}>+ 모드 추가 (${S.modes.length}/${MAX_MODES})</button><button class="btn primary" data-act="close">닫기</button></div>`);
}

function memoSheet(id, kind) {
  const m = id ? S.memos.find((x) => x.id === id) : { text: '', kind, hl: false };
  openSheet(`<h3>${m.kind === 'long' ? '긴 메모' : '짧은 메모'}</h3><form id="mf" data-id="${id || ''}" data-kind="${m.kind}">
    <div class="field"><textarea name="text" required style="min-height:${m.kind === 'long' ? 200 : 84}px">${esc(m.text)}</textarea></div>
    <label style="display:flex;gap:8px;align-items:center;font-size:14px;color:var(--text)"><input type="checkbox" name="hl" ${m.hl ? 'checked' : ''} style="width:auto"> 형광펜 표시</label>
    <div class="btns">${id ? `<button type="button" class="btn danger" data-act="delMemo" data-id="${id}">삭제</button>` : ''}<button type="button" class="btn" data-act="close">취소</button><button class="btn primary">저장</button></div></form>`);
}

function archivedSheet() {
  const list = S.habits.filter((h) => h.archived);
  openSheet(`<h3>보관된 습관</h3>${list.map((h) => `<div class="setrow"><div>${esc(h.emoji)} ${esc(h.name)}</div>
    <div><button class="chip" data-act="restore" data-id="${h.id}">복원</button> <button class="chip" data-act="purge" data-id="${h.id}">영구 삭제</button></div></div>`).join('') || '<div class="empty">보관된 습관이 없어요.</div>'}
    <div class="btns"><button class="btn primary" data-act="close">닫기</button></div>`);
}

/* ---------- 이벤트 ---------- */
function swap(id, dir) {
  const vis = dueHabits(ui.date); const i = vis.findIndex((h) => h.id === id); const j = i + dir;
  if (j < 0 || j >= vis.length) return;
  const a = S.habits.indexOf(vis[i]), b = S.habits.indexOf(vis[j]);
  [S.habits[a], S.habits[b]] = [S.habits[b], S.habits[a]];
  save(); render();
}

document.addEventListener('click', (e) => {
  if (e.target.id === 'sheet') { closeSheet(); return; }
  const el = e.target.closest('[data-act]'); if (!el) return;
  const { act, id, v } = el.dataset;
  switch (act) {
    case 'nav': ui.tab = v; render(); break;
    case 'pick': ui.date = v; render(); break;
    case 'sub': ui.sub = v; render(); break;
    case 'view': ui.view = v; render(); break;
    case 'edit': ui.edit = !ui.edit; render(); break;
    case 'filter': ui.filter = { all: 'undone', undone: 'done', done: 'all' }[ui.filter]; render(); break;
    case 'range': ui.range = v; render(); break;
    case 'datepick': { const p = $('#datePicker'); p.value = ui.date; p.showPicker ? p.showPicker() : p.click(); break; }
    case 'rest':
      if (S.rest[ui.date]) delete S.rest[ui.date]; else S.rest[ui.date] = true;
      save(); render(); toast(S.rest[ui.date] ? '쉬는 날로 표시했어요. 실패로 세지 않아요' : '쉼을 해제했어요'); break;
    case 'toggle': setLog(id, ui.date, { done: !isDone(id, ui.date) }); render(); break;
    case 'gtoggle': setLog(id, v, { done: !isDone(id, v) }); render(); break;
    case 'todoToggle': { const t = S.todos.find((x) => x.id === id); t.done = !t.done; save(); render(); break; }
    case 'add': addMenu(); break;
    case 'newHabit': habitForm(); break;
    case 'newTodo': todoForm(); break;
    case 'editHabit': habitForm(id); break;
    case 'editTodo': todoForm(id); break;
    case 'delTodo': S.todos = S.todos.filter((t) => t.id !== id); save(); closeSheet(); render(); break;
    case 'detail': detailSheet(id); break;
    case 'level': { const cur = logOf(id, ui.date)?.level; setLog(id, ui.date, { level: cur === v ? '' : v, done: true }); detailSheet(id); render(); break; }
    case 'alt': setLog(id, ui.date, { alt: v }); detailSheet(id); render(); break;
    case 'timerStart': startTimer(id); break;
    case 'timerStop': stopTimer(); break;
    case 'up': swap(id, -1); break;
    case 'down': swap(id, 1); break;
    case 'archiveHabit': S.habits.find((h) => h.id === id).archived = true; save(); closeSheet(); render(); toast('보관했어요. 설정에서 복원할 수 있어요'); break;
    case 'archived': archivedSheet(); break;
    case 'restore': S.habits.find((h) => h.id === id).archived = false; save(); archivedSheet(); render(); break;
    case 'purge': S.habits = S.habits.filter((h) => h.id !== id); save(); archivedSheet(); render(); break;
    case 'modes': modesSheet(); break;
    case 'applyMode': S.activeMode = id; save(); closeSheet(); render(); toast('오늘부터 이 모드로 보여요'); break;
    case 'addMode': { const name = prompt('모드 이름', `모드 ${S.modes.length + 1}`); if (name?.trim()) { S.modes.push({ id: uid(), name: name.trim() }); save(); modesSheet(); render(); } break; }
    case 'renameMode': { const m = S.modes.find((x) => x.id === id); const name = prompt('모드 이름', m.name); if (name?.trim()) { m.name = name.trim(); save(); modesSheet(); render(); } break; }
    case 'delMode':
      if (S.modes.length > 1 && confirm('이 모드를 삭제할까요? 습관은 지워지지 않아요.')) {
        S.modes = S.modes.filter((m) => m.id !== id);
        S.habits.forEach((h) => { h.modes = h.modes.filter((x) => x !== id); });
        if (S.activeMode === id) S.activeMode = S.modes[0].id;
        save(); modesSheet(); render();
      } break;
    case 'mood': { const r = (S.reviews[ui.date] ??= {}); r.mood = r.mood === Number(v) ? 0 : Number(v); save(); render(); break; }
    case 'newMemo': memoSheet(null, v); break;
    case 'memo': memoSheet(id); break;
    case 'delMemo': S.memos = S.memos.filter((m) => m.id !== id); save(); closeSheet(); render(); break;
    case 'notif':
      if (!('Notification' in window)) toast('이 브라우저는 알림을 지원하지 않아요');
      else Notification.requestPermission().then((p) => { toast(p === 'granted' ? '알림을 허용했어요' : '알림이 허용되지 않았어요'); render(); });
      break;
    case 'export': exportData(); break;
    case 'import': $('#importFile').click(); break;
    case 'wipe':
      if (confirm('모든 습관, 기록, 회고가 삭제돼요. 계속할까요?') && confirm('정말 지울까요? 되돌릴 수 없어요.')) { localStorage.removeItem(KEY); S = defaultState(); save(); render(); toast('초기화했어요'); }
      break;
    case 'close': closeSheet(); break;
    default: console.warn('알 수 없는 동작', act);
  }
});

document.addEventListener('submit', (e) => {
  e.preventDefault();
  const f = e.target;
  if (f.id === 'hf') saveHabitForm(f);
  if (f.id === 'tf') {
    const d = new FormData(f); const text = String(d.get('text')).trim(); if (!text) return;
    if (f.dataset.id) Object.assign(S.todos.find((t) => t.id === f.dataset.id), { text, date: d.get('date') });
    else S.todos.push({ id: uid(), text, date: d.get('date') || ui.date, done: false });
    save(); closeSheet(); render();
  }
  if (f.id === 'mf') {
    const d = new FormData(f); const text = String(d.get('text')).trim(); if (!text) return;
    if (f.dataset.id) Object.assign(S.memos.find((m) => m.id === f.dataset.id), { text, hl: d.get('hl') === 'on' });
    else S.memos.push({ id: uid(), date: ui.date, kind: f.dataset.kind, text, hl: d.get('hl') === 'on' });
    save(); closeSheet(); render();
  }
});

document.addEventListener('change', (e) => {
  const t = e.target;
  if (t.id === 'datePicker') { if (t.value) { ui.date = t.value; render(); } return; }
  if (t.dataset.set) { S.settings[t.dataset.set] = t.type === 'checkbox' ? t.checked : t.value; save(); render(); return; }
  if (t.dataset.actChange === 'value') { setLog(t.dataset.id, ui.date, { value: t.value === '' ? '' : Number(t.value), done: t.value !== '' ? true : isDone(t.dataset.id, ui.date) }); render(); return; }
  if (t.id === 'importFile') { importData(t.files[0]); t.value = ''; }
});
document.addEventListener('input', (e) => {
  const k = e.target.dataset.bind; if (!k) return;
  const r = (S.reviews[ui.date] ??= {}); r[k] = e.target.value; save();
});

/* ---------- 백업 ---------- */
function exportData() {
  const blob = new Blob([JSON.stringify(S, null, 2)], { type: 'application/json' });
  const a = document.createElement('a'); a.href = URL.createObjectURL(blob);
  a.download = `myroutine-backup-${today()}.json`; a.click(); URL.revokeObjectURL(a.href);
}
async function importData(file) {
  if (!file) return;
  let data;
  try { data = JSON.parse(await file.text()); } catch (err) { console.error(err); toast('JSON 파일을 읽지 못했어요'); return; }
  if (!Array.isArray(data.habits) || !data.logs) { toast('내 루틴 백업 파일이 아니에요'); return; }
  if (!confirm('현재 데이터를 이 백업으로 덮어쓸까요?')) return;
  S = { ...defaultState(), ...data }; save(); render(); toast('불러왔어요');
}

/* ---------- 알람 ---------- */
const fired = new Set();
function checkAlarms() {
  const now = new Date(); const hm = `${pad(now.getHours())}:${pad(now.getMinutes())}`; const d = today();
  S.habits.forEach((h) => {
    if (!h.alarm || h.alarm !== hm || !inMode(h) || !isDue(h, d) || isDone(h.id, d) || S.rest[d]) return;
    const k = `${d}|${h.id}|${hm}`; if (fired.has(k)) return; fired.add(k);
    toast(`🔔 ${h.emoji} ${h.name}`);
    if ('Notification' in window && Notification.permission === 'granted') new Notification(`${h.emoji} ${h.name}`, { body: '지금 할 시간이에요', icon: 'assets/icon.svg' });
  });
}
setInterval(checkAlarms, 20000);

/* ---------- 시작 ---------- */
// 다른 탭/위젯 화면에서 바꾼 내용을 바로 반영
window.addEventListener('storage', (e) => { if (e.key === KEY) { S = load(); render(); } });
document.addEventListener('visibilitychange', () => { if (!document.hidden) { S = load(); render(); } });
if (new URLSearchParams(location.search).has('add')) setTimeout(addMenu, 0);
render();
if ('serviceWorker' in navigator && location.protocol.startsWith('http')) {
  navigator.serviceWorker.register('sw.js').catch((err) => console.error('서비스 워커 등록 실패', err));
}
