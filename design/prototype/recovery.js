/* The review, remedy and collection screens share the same seeded math lesson. */
(() => {
  'use strict';

  const lesson = '同样多、多、少的含义';
  const original = {
    stem: '桌上有3个杯子和3个盖子，杯子和盖子的数量关系是？',
    options: ['同样多', '杯子多', '盖子多', '无法确定'],
    correct: 0,
    why: '数量都是3，所以同样多。'
  };
  const variants = [
    {stem: '第一排摆了4个圆，第二排也摆了4个圆，两排圆的关系是？', options: ['第一排多', '第二排多', '同样多', '不能比较'], correct: 2, why: '4 = 4，两排圆的数量相等。'},
    {stem: '盘子里有8个红苹果，6个青苹果，哪种苹果少？', options: ['红苹果少', '青苹果少', '一样多', '无法比较'], correct: 1, why: '6 小于 8，所以青苹果少。'},
    {stem: '两个篮子里各装了5个苹果，说明这两个篮子里的苹果同样多。', options: ['对', '错'], correct: 0, why: '每个篮子都有5个，数量相等。'},
    {stem: '小明有3块糖，小红有5块糖，小明比小红多。', options: ['对', '错'], correct: 1, why: '3 小于 5，小明的糖比小红少。'}
  ];
  const knowledge = [
    {title: '1~10各数的数数与认读', concept: '点数时要用手指指着物体，数一个记一个，这就是“一一对应”。最后一个数出的数，就是这堆物体的总数。', method: '从小到大数：1，2，3，4，5，6，7，8，9，10。', tip: '数数时可以做个小记号，数过一个划掉一个，这样就不会漏数或重复了。'},
    {title: lesson, concept: '将两组物体一个对一个地连线或摆放。如果都没有剩余，就是“同样多”。', method: '有剩余的那一组就“多”，对应的另一组就是“少”。', tip: '伸出左右手的手指，一个对一个地比。'}
  ];
  const units = [
    ['准备课', 3], ['位置', 3], ['1~5的认识和加减法', 6], ['认识图形（一）', 3],
    ['6~10的认识和加减法', 5], ['11~20各数的认识', 3], ['认识钟表', 3],
    ['20以内的进位加法', 3], ['总复习', 3]
  ];
  const totalCards = units.reduce((total, unit) => total + unit[1], 0);

  const icon = (name, size = 20) => window.ui.icon(name, size);
  const art = (name, width, height) => window.ui.art(name, width, height);
  const sealedGems = () => window.ui.sample?.().sealedGems ?? 28;

  function backButton(to, close = '') {
    return `<button type="button" class="r-back" ${typeof window.ui[close] === 'function' ? `data-rback="${close}"` : `data-to="${to}"`} aria-label="返回">${icon('back', 20)}</button>`;
  }

  function review(sealed = true, due = sealed, hasMistake = sealed || due) {
    const chest = sealed
      ? `<div class="r-section-head"><h3>心魔录</h3><span>宝箱保留 3 天</span></div><article class="r-chest-banner">
          <div class="r-banner-ink"><span class="r-tag r-tag-ink">${icon('lock', 12)}封存宝箱</span>
            <h3>1 只心魔待收服</h3><p>${lesson}</p></div>
          <div class="r-review-art">${art('chest', 103, 93)}</div>
          <div class="r-banner-foot"><span>${icon('diamond', 17)}${sealedGems()} 宝石<i></i> 1 张银卡</span>
            <button type="button" class="r-chip-button" data-to="remedy">去收服 ${icon('arrow', 15)}</button></div>
        </article>` : '';
    const entry = (due || hasMistake)
      ? `<div class="r-section-head"><h3>${due ? '今天到期' : '稍后复习'}</h3><span>1 题</span></div>
        <div class="r-question-item"><span class="r-item-kicker">${icon('book', 16)} 准备课 · 第 2 课</span>
          <b>${original.stem}</b><span class="r-item-foot"><span>${lesson}</span><span class="r-small-chip">第 ${due ? 1 : 2} 层</span></span></div>`
      : `<div class="r-empty"><div class="r-empty-art">${art('hero', 180, 147)}</div><h3>今天没有到期错题</h3><p>做错的题会自动收集到这里复习。</p></div>`;
    return `<main class="r-page r-review" data-sealed="${sealed}" data-has-mistake="${hasMistake}"><header class="r-page-head"><h1>错题本</h1>${due ? '<span class="r-headmark">待复习 1</span>' : ''}</header>
      ${chest}${entry}${due ? '<div class="r-action-foot"><button type="button" class="r-primary" data-review-action="start">开始复习（1 题）</button></div>' : ''}</main>`;
  }

  const sessions = new WeakMap();
  function practice(root, btn) {
    const action = btn.dataset.reviewAction;
    if (action === 'start') sessions.set(root, {picked: -1, checked: false, due: true});
    const s = sessions.get(root);
    if (!s) return;
    const sealed = root.dataset.sealed === 'true';
    if (action === 'close' || action === 'finish') {
      root.outerHTML = review(sealed, s.due, root.dataset.hasMistake === 'true');
      return;
    }
    if (action === 'select' && !s.checked) s.picked = Number(btn.dataset.index);
    if (action === 'check' && s.picked >= 0 && !s.checked) {
      s.checked = true;
      s.due = s.picked !== original.correct;
      window.ui.reviewOriginal?.(!s.due);
    }
    root.classList.add('r-review-run');
    const header = `<header class="r-page-head"><button type="button" class="r-back" aria-label="返回错题本" data-review-action="close">${icon('close', 18)}</button><h1>错题复习</h1></header>`;
    if (action === 'result') {
      if (s.checked && !s.settled) {
        s.settled = true;
        window.ui.recordReview?.(!s.due);
      }
      root.innerHTML = header + `<div class="r-empty"><div class="r-empty-art">${art('hero',174,138)}</div><h3>复习完成！</h3><p>答对 ${s.due ? 0 : 1}/1 题 · +${s.due ? 0 : 10} XP</p></div><div class="r-action-foot"><button class="r-primary" data-review-action="finish">完成</button></div>`;
      return;
    }
    root.innerHTML = header + `<div class="r-quiz-progress"><span>复习进度</span><strong>1 / 1</strong></div><div class="r-progress"><i style="width:${s.checked ? 100 : 0}%"></i></div>
      <div class="r-quiz-heading"><span class="r-tag">选择正确答案</span><h2>${original.stem}</h2></div><div class="r-options">
      ${original.options.map((label,i) => `<button class="r-option ${s.checked && i === original.correct ? 'r-correct' : (s.picked === i ? (s.checked ? 'r-wrong' : 'r-selected') : '')}" data-review-action="select" data-index="${i}" ${s.checked ? 'disabled' : ''}>${label}</button>`).join('')}</div>
      ${s.checked ? `<div class="r-feedback ${s.due ? '' : 'r-positive'}"><b>${s.due ? '正确答案 · 同样多' : '答对了！'}</b><p>${original.why}</p></div>` : ''}
      <div class="r-action-foot"><button class="r-primary" data-review-action="${s.checked ? 'result' : 'check'}" ${s.picked < 0 ? 'disabled' : ''}>${s.checked ? '继续' : '检查'}</button></div>`;
  }

  function remedyHero() {
    return `<div class="r-relic"><span class="r-relic-id">${icon('shield', 14)}准备课 · 第 2 课</span>
      <div class="r-relic-art">${art('chest', 145, 119)}</div><h2>1 只心魔待收服</h2><p>${lesson}</p></div>`;
  }

  function intro() {
    return `${remedyHero()}<div class="r-section-head"><h3>收服方法</h3></div><ol class="r-rules">
      <li><span class="r-rule-ico">${icon('pencil', 20)}</span><div><b>订正原题</b><p>再做一次答错的杯子与盖子题。</p></div></li>
      <li><span class="r-rule-ico">${icon('repeat', 20)}</span><div><b>答对 2 道同类题</b><p>每错一次多练 1 道，最多 5 道。</p></div></li>
      <li><span class="r-rule-ico r-honey">${icon('key', 20)}</span><div><b>解封宝箱</b><p>取回 ${sealedGems()} 宝石和银卡，再奖 2 宝石。</p></div></li></ol>
      <p class="r-expiry">${icon('clock',14)} 宝箱保留 3 天</p>
      <div class="r-action-foot"><button type="button" class="r-primary" data-ra="start">开始收服 ${icon('arrow', 18)}</button></div>`;
  }

  function remedy() {
    return `<main class="r-page r-remedy"><header class="r-page-head">${backButton('review', 'closeRemedy')}<h1>心魔试炼</h1></header>
      <div class="r-remedy-body">${intro()}</div></main>`;
  }

  const trials = new WeakMap();
  function newTrial() {
    return {corrected: false, done: 0, need: 2, misses: 0, turn: 0, picked: -1, checked: false, question: original};
  }
  function lessonQuiz(state) {
    const q = state.question;
    const right = state.picked === q.correct;
    const done = Number(state.corrected) + state.done;
    const count = state.need + 1;
    const title = q === original ? '订正原题' : `同类题 ${state.done + (right && state.checked ? 0 : 1)} / ${state.need}`;
    const choices = q.options.map((choice, i) => {
      let color = state.picked === i ? ' r-selected' : '';
      if (state.checked && i === q.correct) color = ' r-correct';
      if (state.checked && i === state.picked && !right) color = ' r-wrong';
      return `<button type="button" class="r-option${color}" data-ra="select" data-index="${i}" aria-pressed="${state.picked === i}" ${state.checked ? 'disabled' : ''}>${choice}</button>`;
    }).join('');
    const feedback = state.checked
      ? `<div class="r-feedback ${right ? 'r-positive' : ''}" role="status"><b>${right ? '答对了！' : '正确答案 · ' + q.options[q.correct]}</b><p>${q.why}</p></div>` : '';
    return `<div class="r-quiz-progress"><span>收服进度</span><strong>${done} / ${count}</strong></div>
      <div class="r-progress"><i style="width:${done / count * 100}%"></i></div>
      <div class="r-quiz-heading"><span class="r-tag">${icon('pencil', 14)}${title}</span><h2>${q.stem}</h2></div>
      <div class="r-options">${choices}</div>${feedback}
      <div class="r-action-foot"><button type="button" class="r-primary" data-ra="${state.checked ? 'next' : 'check'}"
        ${state.picked < 0 ? 'disabled' : ''}>${state.checked ? (right ? '继续' : '再试一次') : '检查'}</button></div>`;
  }
  function subdued() {
    return `<div class="r-prize"><div class="r-empty-art">${art('hero', 184, 143)}</div>
      <span class="r-tag">${icon('checkCircle', 14)}已收服</span><h2>收服 1 / 1 只</h2><p>全部收服！去打开宝箱吧</p></div>
      <div class="r-action-foot"><button type="button" class="r-primary" data-ra="open">打开宝箱</button></div>`;
  }
  function finishTrial() {
    return `<div class="r-prize"><div class="r-relic-art">${art('chest', 178, 147)}</div><span class="r-tag">${icon('checkCircle', 14)}心魔已收服</span>
      <h2>宝箱解封！</h2><p>${lesson}</p><div class="r-prize-pay"><div>${icon('diamond', 24)}<b>+${sealedGems() + 2} 宝石</b></div>
      <div>${icon('card', 24)}<b>1 张银卡</b></div></div><p>含收服奖励 2 宝石</p></div>
      <div class="r-action-foot"><button type="button" class="r-primary" data-ra="claim">收下</button></div>`;
  }
  function help() {
    return `<div class="r-help">${art('hero', 150, 120)}<h2>请教时刻</h2><p>把杯子和盖子一一对应。如果两边都没有剩余，它们就同样多。</p><p>也可以请爸爸妈妈和你一起摆一摆。</p></div>
      <div class="r-action-foot"><button type="button" class="r-primary" data-ra="retry">我再试试</button></div>`;
  }
  function paint(root, html) {
    root.querySelector('.r-remedy-body').innerHTML = html;
    root.scrollTop = 0;
  }
  function handleTrial(root, btn) {
    if (btn.disabled) return;
    const action = btn.dataset.ra;
    if (action === 'claim') { window.ui.unseal(); return; }
    if (action === 'open') { paint(root, finishTrial()); return; }
    if (action === 'start') trials.set(root, newTrial());
    const s = trials.get(root);
    if (!s) return;
    if (action === 'select') {
      if (s.checked) return;
      s.picked = Number(btn.dataset.index);
    } else if (action === 'check') {
      if (s.picked < 0 || s.checked) return;
      s.checked = true;
      if (s.question === original) window.ui.reviewOriginal?.(s.question.correct === s.picked);
      if (s.question.correct === s.picked) {
        s.misses = 0;
        if (s.corrected) s.done++;
        else s.corrected = true;
      } else {
        s.misses++;
        s.need = Math.min(5, s.need + 1);
      }
    } else if (action === 'next' || action === 'retry') {
      if (s.done >= s.need) { paint(root, subdued()); return; }
      if (s.misses >= 3 && action !== 'retry') { paint(root, help()); return; }
      if (action === 'retry') s.misses = 0;
      s.question = s.corrected ? variants[s.turn++ % variants.length] : original;
      s.picked = -1;
      s.checked = false;
    }
    paint(root, lessonQuiz(s));
  }

  function motif(index) {
    if (index === 0) return '<span class="r-numbers" aria-hidden="true"><i>1</i><i>2</i><i>3</i></span>';
    if (index === 1) return '<span class="r-counters" aria-hidden="true"><i></i><i></i><i></i><i></i><i></i><i></i></span>';
    return icon('lock', 23);
  }
  function tile(index, tier) {
    const owned = tier > 0;
    const name = owned ? knowledge[index].title : '???';
    const rank = tier === 3 ? '金卡' : (tier === 2 ? '银卡' : '未收集');
    return `<button type="button" class="r-card-tile r-tier-${tier}" data-card-index="${index}" data-card-tier="${tier}" ${owned ? '' : 'disabled'}>
      <span class="r-tile-inner"><span class="r-rank">${owned ? icon('star', 10) : icon('lock', 10)} ${rank}</span>
        <span class="r-tile-motif">${owned ? motif(index) : motif(-1)}</span>
        <b>${name}</b></span></button>`;
  }
  function cards(owned = 2, tier = 2) {
    const ownedCount = Math.min(2, Math.max(0, Number(owned)));
    const guardian = (count, max) => `<div class="r-guardian"><span class="r-guardian-mark">${icon('shield', 26)}</span><div><b>守护兽 · ???</b><p>集齐本单元 ${max} 张卡召唤</p></div>
        <div class="r-gem-progress" aria-label="守护兽收集进度">${Array.from({length:max}, (_,i) => `<i class="${i < count ? 'r-filled' : ''}"></i>`).join('')}</div></div>`;
    return `<main class="r-page r-cards"><header class="r-page-head">${backButton('home', 'closeCards')}<h1>知识卡册</h1></header>
      <div class="r-collection-banner"><div><span class="r-collection-label">人教版小学数学一年级上册（旧版）</span>
        <div class="r-big-count"><b>${ownedCount}</b><span>/ ${totalCards} 张知识卡</span></div><div class="r-album-track"><i style="width:${ownedCount / totalCards * 100}%"></i></div>
        <div class="r-counter-row"><span>${icon('star',12)} 金卡 ${ownedCount > 0 ? (ownedCount > 1 && tier === 3 ? 2 : 1) : 0}</span><span>${icon('shield',12)} 守护兽 0/9</span></div></div>
        <div class="r-collection-art">${art('cards', 102, 90)}</div></div>
      <p class="r-album-rules">每课一张知识卡。1 星铜卡、2 星银卡、3 星金卡。</p>
      ${units.map(([name, size], unitIndex) => {
        const count = unitIndex === 0 ? ownedCount : 0;
        return `<div class="r-unit-title"><div><span>第 ${unitIndex + 1} 单元</span><h2>${name}</h2></div><b>${count} / ${size}</b></div>
          ${guardian(count, size)}<div class="r-deck">${Array.from({length:size}, (_,i) => tile(i, i < count ? (i === 0 ? 3 : Number(tier)) : 0)).join('')}</div>`;
      }).join('')}</main>`;
  }

  function showCard(root, index, tier, flipped) {
    const info = knowledge[index];
    let dialog = root.querySelector('.r-card-dialog');
    if (!dialog) {
      dialog = document.createElement('dialog');
      dialog.className = 'r-card-dialog';
      dialog.setAttribute('aria-label', info.title);
      root.append(dialog);
    }
    const rank = tier === 3 ? '金卡' : '银卡';
    const content = flipped
      ? `<div class="r-card-back"><h3>知识小结</h3><b>核心概念</b><p>${info.concept}</p><b>关键方法</b><p>${info.method}</p><b>小提示</b><p>${info.tip}</p></div>`
      : `<div class="r-detail-face r-tier-${tier}"><span class="r-rank">${icon('star', 13)}${rank}</span><span class="r-tile-motif">${motif(index)}</span><b>${info.title}</b></div>`;
    dialog.innerHTML = `<div class="r-dialog-head"><span>第 1 单元 · 准备课</span><button type="button" aria-label="收起" data-card-close>${icon('close', 18)}</button></div>
      ${content}${tier < 3 ? '<p class="r-upgrade-note">三星通关这一课，就能升级成金卡</p>' : ''}
      <button type="button" class="r-secondary" data-card-flip="${flipped ? 'front' : 'back'}" data-index="${index}" data-tier="${tier}">${icon('repeat', 17)}${flipped ? '看正面' : '翻到背面 · 知识小结'}</button>`;
    if (!dialog.open) {
      dialog.show();
      root.classList.add('r-has-dialog');
      dialog.style.top = `${(root.closest('.app-body')?.scrollTop ?? 0) + 34}px`;
    }
    dialog.querySelector(flipped ? '[data-card-flip]' : '[data-card-close]').focus({preventScroll: true});
  }
  function closeCard(root) {
    const dialog = root.querySelector('.r-card-dialog');
    if (!dialog) return;
    const index = dialog.querySelector('[data-card-flip]').dataset.index;
    dialog.close();
    dialog.remove();
    root.classList.remove('r-has-dialog');
    root.querySelector(`[data-card-index="${index}"]`)?.focus({preventScroll: true});
  }
  document.addEventListener('click', (event) => {
    const btn = event.target.closest('button');
    if (btn?.dataset.rback) { window.ui[btn.dataset.rback](); return; }
    if (btn?.hasAttribute('data-review-action')) { practice(btn.closest('.r-review'), btn); return; }
    const trial = btn?.closest('.r-remedy');
    if (trial && btn.hasAttribute('data-ra')) { handleTrial(trial, btn); return; }
    const root = event.target.closest('.r-cards');
    if (!root) return;
    if (btn?.hasAttribute('data-card-index') && !btn.disabled && !root.classList.contains('r-has-dialog')) {
      showCard(root, Number(btn.dataset.cardIndex), Number(btn.dataset.cardTier), false);
    } else if (btn?.hasAttribute('data-card-flip')) {
      showCard(root, Number(btn.dataset.index), Number(btn.dataset.tier), btn.dataset.cardFlip === 'back');
    } else if (btn?.hasAttribute('data-card-close') || (root.classList.contains('r-has-dialog') && !event.target.closest('dialog'))) {
      closeCard(root);
    }
  });
  document.addEventListener('keydown', (event) => {
    const root = event.target.closest('.r-has-dialog');
    if (!root) return;
    if (event.key === 'Escape') {
      event.preventDefault();
      closeCard(root);
    } else if (event.key === 'Tab') {
      const controls = root.querySelectorAll('dialog button');
      const first = controls[0], last = controls[controls.length - 1];
      if (event.shiftKey && document.activeElement === first) { event.preventDefault(); last.focus(); }
      if (!event.shiftKey && document.activeElement === last) { event.preventDefault(); first.focus(); }
    }
  });
  window.recoveryScreens = {review, remedy, cards};
})();
