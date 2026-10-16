/* VERSION = "v1.1": 스킬별 개인 메모와 일관된 설치 도구 순서를 추가한다. */
const NOTE_KEY = 'skill-atlas-notes-v1';
const NOTE_LIMIT = 4000;
let notes = new Map();
let activeNoteName = null;
let noteStorageAvailable = true;

function parseNotes(value) {
  if (!value || typeof value !== 'object' || Array.isArray(value)) {
    throw new Error('메모 목록이 올바른 객체가 아닙니다.');
  }
  const entries = Object.entries(value);
  if (entries.length > 5000) throw new Error('메모 개수가 허용 범위를 넘었습니다.');
  for (const [name, text] of entries) {
    if (!name || name.length > 250 || typeof text !== 'string' || text.length > NOTE_LIMIT) {
      throw new Error('메모 이름 또는 내용의 형식이 올바르지 않습니다.');
    }
  }
  return new Map(entries.filter(([, text]) => text.trim()));
}

try {
  notes = parseNotes(JSON.parse(localStorage.getItem(NOTE_KEY) || '{}'));
} catch (error) {
  noteStorageAvailable = false;
  console.error('개인 메모 읽기 실패', error);
  toast('기존 메모를 읽지 못했습니다. 기존 저장값은 덮어쓰지 않습니다.');
}

function persistNotes() {
  if (!noteStorageAvailable) {
    toast('메모는 현재 창에서만 보관됩니다. 메모 백업으로 파일에 저장해주세요.');
    return false;
  }
  try {
    localStorage.setItem(NOTE_KEY, JSON.stringify(Object.fromEntries(notes)));
    return true;
  } catch (error) {
    console.error('개인 메모 저장 실패', error);
    toast('브라우저 저장에 실패했습니다. 현재 메모는 메모 백업으로 저장할 수 있습니다.');
    return false;
  }
}

const baseMatchingLocations = matchingLocations;
matchingLocations = skill => baseMatchingLocations(skill).sort((a, b) =>
  a.agent.localeCompare(b.agent, 'en') || a.path.localeCompare(b.path, 'en'));

matches = skill => {
  const locations = matchingLocations(skill);
  if (!locations.length) return false;
  if (state.agent === 'both' && !['Claude Code', 'Codex'].every(agent => locations.some(l => l.agent === agent))) return false;
  if (state.category !== 'all' && skill.category !== state.category) return false;
  if (state.fav && !favorites.has(skill.name)) return false;
  if (state.recent && !featuredNames.has(skill.name)) return false;
  if (state.notesOnly && !notes.has(skill.name)) return false;
  const haystack = [skill.name, skill.description, skill.category, skill.source,
    notes.get(skill.name) || '', featured.find(f => f[0] === skill.name)?.slice(1, 3).join(' ') || ''].join(' ').toLowerCase();
  return state.q.trim().toLowerCase().split(/\s+/).every(word => haystack.includes(word));
};

const noteFilter = document.createElement('button');
noteFilter.id = 'notes-only';
noteFilter.className = 'nav-item';
noteFilter.innerHTML = '메모 있는 스킬 <span id="notes-count">0</span>';
$('saved').after(noteFilter);
state.notesOnly = new URLSearchParams(location.hash.slice(1)).get('notesOnly') === '1';
noteFilter.onclick = () => {
  update({ notesOnly: !state.notesOnly, fav: false, recent: false, category: 'all', q: '' });
  closeMenu();
};
const baseRestore = restore;
restore = () => {
  baseRestore();
  state.notesOnly = new URLSearchParams(location.hash.slice(1)).get('notesOnly') === '1';
};
const baseUpdate = update;
update = next => {
  const changesView = ['category', 'fav', 'recent'].some(key => Object.hasOwn(next, key));
  baseUpdate({ ...(changesView ? { notesOnly: false } : {}), ...next });
};

function showNotePreview(skillName, element) {
  const existing = element.querySelector('.personal-note');
  if (existing) existing.remove();
  const note = notes.get(skillName);
  const section = document.createElement('div');
  section.className = 'personal-note';
  const button = document.createElement('button');
  button.className = 'note-link';
  button.dataset.detail = skillName;
  button.textContent = note ? '내 메모 수정' : '메모 남기기';
  button.setAttribute('aria-label', `${skillName} ${note ? '메모 수정' : '메모 작성'}`);
  if (note) {
    const text = document.createElement('p');
    text.className = 'note-preview';
    text.textContent = note;
    section.append(text);
  }
  section.append(button);
  element.querySelector('.skill-desc').after(section);
}

const baseRender = render;
render = () => {
  baseRender();
  for (const row of document.querySelectorAll('#list .skill')) {
    showNotePreview(row.querySelector('[data-detail]').dataset.detail, row.querySelector('.skill-main'));
  }
  noteFilter.setAttribute('aria-pressed', String(!!state.notesOnly));
  $('notes-count').textContent = SKILLS.filter(skill => notes.has(skill.name)).length;
  if (state.notesOnly) {
    $('collection-title').textContent = '메모 있는 스킬';
    $('all').setAttribute('aria-pressed', 'false');
  }
};

const baseOpenDetail = openDetail;
openDetail = (name, trigger) => {
  baseOpenDetail(name, trigger);
  activeNoteName = name;
  const section = document.createElement('section');
  section.className = 'note-editor';
  section.setAttribute('aria-labelledby', 'note-heading');
  section.innerHTML = '<h3 id="note-heading"><label for="note-text">내 메모</label></h3>' +
    '<p class="note-help">언제 쓸지, 사용해본 느낌을 적어두세요. 입력하면 자동 저장됩니다.</p>' +
    '<textarea id="note-text" rows="4" maxlength="4000" placeholder="예: 코드 수정 전에 적용하면 불필요한 변경을 줄이기 좋음"></textarea>' +
    '<div class="note-toolbar"><button id="save-note" class="text-button">메모 저장</button>' +
    '<button id="delete-note" class="note-link">메모 지우기</button>' +
    '<span id="note-status" role="status" aria-live="polite"></span></div>' +
    '<p class="note-help">메모는 이 브라우저에 보관됩니다. 메모 백업으로 파일에 따로 저장할 수 있습니다.</p>';
  const description = $('detail-body').querySelector('h3 + p');
  description.after(section);
  const textarea = $('note-text');
  textarea.value = notes.get(name) || '';
  function save(explicit = false) {
    const text = textarea.value;
    if (text.trim()) notes.set(name, text); else notes.delete(name);
    const saved = persistNotes();
    $('note-status').textContent = (saved ? (text.trim() ? '저장됨' : '빈 메모') : '현재 창에만 보관') + ` / ${text.length.toLocaleString()}자`;
    if (explicit && saved) toast('메모를 저장했습니다.');
  }
  $('note-status').textContent = `${textarea.value.length.toLocaleString()} / 4,000자`;
  textarea.addEventListener('input', () => save());
  $('save-note').onclick = () => save(true);
  $('delete-note').onclick = () => {
    textarea.value = '';
    save();
    textarea.focus();
  };
};

function finishNoteEditing() {
  if (!activeNoteName || $('detail').open) return;
  const name = activeNoteName;
  activeNoteName = null;
  render();
  [...document.querySelectorAll('.skill-title')].find(button => button.dataset.detail === name)?.focus({ preventScroll: true });
}
const baseCloseDialog = closeDialog;
closeDialog = () => {
  baseCloseDialog();
  finishNoteEditing();
};
$('close-detail').onclick = closeDialog;
$('detail').addEventListener('close', finishNoteEditing);

const noteTools = document.createElement('div');
noteTools.className = 'note-backup-tools';
noteTools.innerHTML = '<button id="export-notes" class="text-button">메모 백업</button>' +
  '<button id="import-notes" class="text-button">메모 불러오기</button>' +
  '<input id="notes-file" class="visually-hidden" type="file" accept="application/json,.json" aria-label="메모 백업 파일 선택">';
$('collection').after(noteTools);

$('export-notes').onclick = () => {
  const backup = { format: 'skill-atlas-notes', version: 1, exportedAt: new Date().toISOString(), notes: Object.fromEntries(notes) };
  const url = URL.createObjectURL(new Blob([JSON.stringify(backup, null, 2)], { type: 'application/json;charset=utf-8' }));
  const link = document.createElement('a');
  link.href = url;
  link.download = 'skill-atlas-notes.json';
  link.click();
  setTimeout(() => URL.revokeObjectURL(url), 1000);
  toast(`${notes.size}개 메모를 백업했습니다.`);
};
$('import-notes').onclick = () => $('notes-file').click();
$('notes-file').addEventListener('change', async event => {
  const file = event.target.files[0];
  if (!file) return;
  try {
    if (file.size > 2 * 1024 * 1024) throw new Error('2MB 이하의 메모 파일을 선택해주세요.');
    const data = JSON.parse(await file.text());
    if (data.format !== 'skill-atlas-notes' || data.version !== 1) throw new Error('스킬 서재 메모 백업 파일이 아닙니다.');
    const incoming = parseNotes(data.notes);
    let added = 0, conflicts = 0;
    for (const [name, text] of incoming) {
      if (!notes.has(name)) { notes.set(name, text); added++; }
      else if (notes.get(name) !== text) conflicts++;
    }
    const saved = persistNotes();
    render();
    toast(`메모 ${added}개 추가${conflicts ? `, 충돌 ${conflicts}개는 기존 메모 유지` : ''}${saved ? '' : ' / 현재 창에만 보관'}`);
  } catch (error) {
    console.error('메모 불러오기 실패', error);
    toast(`불러오지 못했습니다: ${error.message}`);
  } finally {
    event.target.value = '';
  }
});

render();
