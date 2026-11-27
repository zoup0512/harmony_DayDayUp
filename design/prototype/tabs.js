(() => {
  const icon = (name, size = 20) => ui.icon(name, size);
  const art = (name, w, h) => ui.art(name, w, h);
  // Cosmetic rows follow Cosmetics.all() in the Harmony catalog.
  const goods = [
    ["skin_default", "mascot_skin", "原版聪聪", 0, "common"],
    ["skin_graduate", "mascot_skin", "学士帽", 80, "common"],
    ["skin_glasses", "mascot_skin", "圆框眼镜", 100, "common"],
    ["skin_party", "mascot_skin", "派对锥帽", 150, "rare"],
    ["skin_crown", "mascot_skin", "金色皇冠", 250, "rare"],
    ["skin_wizard", "mascot_skin", "法师尖帽", 300, "epic"],
    ["skin_astronaut", "mascot_skin", "宇航员头盔", 500, "legendary"],
    ["skin_sunglasses", "mascot_skin", "酷炫墨镜", 120, "common"],
    ["skin_pirate", "mascot_skin", "海盗船长", 220, "rare"],
    ["skin_headphones", "mascot_skin", "DJ 耳机", 180, "rare"],
    ["skin_laurel", "mascot_skin", "桂冠加身", 280, "epic"],
    ["skin_bowtie", "mascot_skin", "绅士领结", 60, "common"],
    ["theme_default", "ui_theme", "Duolingo 绿", 0, "common"],
    ["theme_ocean", "ui_theme", "海洋蓝", 200, "common"],
    ["theme_sakura", "ui_theme", "樱花粉", 200, "common"],
    ["theme_sunshine", "ui_theme", "阳光黄", 250, "rare"],
    ["theme_galaxy", "ui_theme", "星空紫", 400, "epic"],
    ["theme_mint", "ui_theme", "薄荷青", 220, "common"],
    ["theme_coral", "ui_theme", "珊瑚红", 300, "rare"],
    ["theme_aurora", "ui_theme", "极光", 500, "legendary"],
    ["theme_midnight", "ui_theme", "暗夜模式", 350, "epic"],
    ["theme_obsidian", "ui_theme", "曜石黑", 480, "legendary"],
    ["backdrop_default", "lesson_backdrop", "干净简洁", 0, "common"],
    ["backdrop_clouds", "lesson_backdrop", "蓝天白云", 120, "common"],
    ["backdrop_forest", "lesson_backdrop", "森林晨光", 150, "common"],
    ["backdrop_sunset", "lesson_backdrop", "黄昏彩霞", 200, "rare"],
    ["backdrop_starfield", "lesson_backdrop", "星空夜", 350, "epic"],
    ["backdrop_sakura", "lesson_backdrop", "樱花飘落", 220, "rare"],
    ["backdrop_ocean", "lesson_backdrop", "深海漫游", 280, "rare"],
    ["backdrop_aurora", "lesson_backdrop", "极光夜", 480, "legendary"]
  ];
  function reset() {
    window.studyTabState = {
      name: '小学员', spent: 0, purchased: new Set(),
      equipped: {mascot_skin: 'skin_default', ui_theme: 'theme_default', lesson_backdrop: 'backdrop_default'}
    };
  }
  reset();
  window.resetStudyTabs = reset;
  const state = () => window.studyTabState;
  const esc = value => String(value).replace(/[&<>"']/g, char => ({'&':'&amp;', '<':'&lt;', '>':'&gt;', '"':'&quot;', "'":'&#39;'})[char]);
  const safeName = () => esc(state().name);
  const totalXP = () => ui.sample().todayXP + 60;

  function badge(name, tone) {
    return `<span class="x-icon x-${tone}">${icon(name, 22)}</span>`;
  }
  function league() {
    const s = ui.sample();
    return `<div class="x-screen x-league">
      <header class="x-league-head"><span class="x-trophy">${icon('trophy',31)}</span>
        <div><h1>青铜联赛</h1><p>每周一结算 · 前 5 名晋级</p></div>
        <div class="x-week"><b>${totalXP()}</b><small>本周 XP</small></div></header>
      <div class="x-locked">
        <div class="x-locked-art">${art('hero',162,158)}<span>${icon('lock',18)}</span></div>
        <h2>完成 10 节课后解锁排行榜</h2>
        <div class="x-rail" role="progressbar" aria-label="排行榜解锁进度" aria-valuenow="${s.done}" aria-valuemax="10" aria-valuemin="0"><i style="width:${s.done*10}%"></i></div>
        <p>${s.done} / 10</p>
      </div></div>`;
  }

  const supplyRows = [
    ['heart','rose','补满红心','立刻回满 5 颗红心',350],
    ['shield','mint','连胜护盾','缺勤时自动保住连胜 · 最多 2 个',200],
    ['fire','corn','连胜补卡','断掉的连胜用宝石救回来',50]
  ];
  const category = {mascot_skin:'聪聪装扮',ui_theme:'界面主题',lesson_backdrop:'课程背景'};
  const rarity = {common:'普通',rare:'稀有',epic:'史诗',legendary:'传说'};
  function price(n) { return icon('diamond',15)+' '+n; }
  function shop() {
    const {gems} = ui.sample();
    const supplies = supplyRows.map(([glyph,tone,title,copy,cost]) => `
      <div class="x-surface x-product">${badge(glyph,tone)}
      <div class="x-product-text"><b>${title}</b><small>${copy}</small></div>
      <button class="x-control" disabled aria-label="${title}，${cost} 宝石，暂不可购买">${price(cost)}</button></div>`).join('');
    const costumes = goods.map(([id,type,title,cost,rank]) => {
      const equipped = state().equipped[type] === id;
      const owned = id.endsWith('_default') || state().purchased.has(id);
      const leftIcon = ['skin_default','skin_graduate','skin_glasses'].includes(id) ? `<span class="x-product-art x-${id}">${id==='skin_default'?art('hero',38,38):'<i></i><b></b><em></em>'}</span>` :
        badge(type==='ui_theme'?'leaf':type==='lesson_backdrop'?'book':'sparkles',type==='ui_theme'?'mint':'corn');
      return `<div class="x-surface x-product ${equipped?'x-equipped':''}">${leftIcon}
      <div class="x-product-text"><b>${title} <i class="x-rarity">${rarity[rank]}</i></b><small>${category[type]}</small></div>
      ${equipped?'<span class="x-using">使用中</span>':`<button class="x-control" data-x-buy="${id}" ${owned||gems>=cost?'':'disabled'}>${owned?'使用':price(cost)}</button>`}</div>`;
    }).join('');
    return `<div class="x-screen x-shop"><header class="x-shop-head"><h1>商店</h1><span class="x-balance">${icon('diamond',20)} ${gems}</span></header>
      <h2>补给</h2><div class="x-goods-list">${supplies}</div><h2>装扮</h2><div class="x-goods-list">${costumes}</div></div>`;
  }

  function week(streak) {
    return `<div class="x-days">${['一','二','三','四','五','六','日'].map((day,i) => `<span class="${i>4-streak&&i<=4?'x-done':''} ${i===4?'x-today':''}"><small>${day}</small><b>${i>4-streak&&i<=4?icon('check',17):'·'}</b></span>`).join('')}</div>`;
  }
  function profileRow(glyph,tone,title,copy,action) {
    return `<button class="x-surface x-profile-row" ${action}>${badge(glyph,tone)}<span><b>${title}</b><small>${copy}</small></span>${icon('chevron',16)}</button>`;
  }
  function stats(s) {
    const perfect = s.perfect ?? 1;
    return `<div class="x-stats">${[['bolt','总经验',totalXP(),'mint'],['diamond','宝石',s.gems,'gem'],['checkCircle','完成课',s.done,'green'],['star','满星课',perfect,'corn']].map(([glyph,label,n,tone])=>`<span class="x-${tone}">${icon(glyph,19)}<b>${n}</b><small>${label}</small></span>`).join('')}</div>`;
  }
  function dailyQuests(quests) {
    const rows = quests.map(q => {
      const complete = q.progress >= q.target;
      const reward = `${icon('diamond', 13)} ${q.reward}`;
      const claim = complete && !q.claimed
        ? `<button class="x-quest-claim" data-action="quest" data-quest="${q.id}" aria-label="${q.title}，领取 ${q.reward} 宝石">领取 ${reward}</button>`
        : `<span class="x-quest-reward">${q.claimed ? '已领取' : reward}</span>`;
      return `<li class="x-quest ${complete ? 'x-complete' : ''}">
        <span class="x-quest-icon">${icon(q.claimed ? 'check' : q.icon, 17)}</span>
        <div><strong>${q.title}</strong><div class="x-quest-progress">
          <progress aria-label="${q.title}" max="${q.target}" value="${q.progress}"></progress><small>${q.progress}/${q.target}</small>
        </div></div>${claim}</li>`;
    }).join('');
    return `<section class="x-surface x-quests"><header><h2>${icon('flag', 18)} 每日任务</h2><small>每天 0 点刷新</small></header><ul>${rows}</ul></section>`;
  }
  function achievementRows() {
    const rows = [['出师告捷','完成你的第一节课'],['三日不辍','连续学习 3 天'],['完美初体验','首次三星通关一节课']];
    if(totalXP()>=100) rows.push(['初露锋芒','累计 100 经验']);
    if(state().purchased.size>0) rows.push(['时尚启航','解锁第一件美妆道具']);
    return rows;
  }
  function profile() {
    const s = ui.sample();
    const goal = s.goal || 50;
    const percent = Math.min(100, s.todayXP / goal * 100);
    return `<div class="x-screen x-profile">
      <header class="x-profile-head">${art('hero',79,75)}
        <div><button data-x-panel="name" aria-label="修改昵称">${safeName()} ${icon('pencil',15)}</button><p>加入 3 天</p></div>
        <button class="x-share" data-x-panel="share">分享连胜</button></header>
      <section class="x-surface x-calendar"><h2>${icon('fire',21)} ${s.streak} 天连胜</h2>${week(s.streak)}</section>
      ${stats(s)}
      <button class="x-surface x-goal" data-modal="goal"><span class="x-goal-ring" style="--x-progress:${percent}%"><i>${icon('bolt',13)}${s.todayXP}</i></span>
        <span><b>今日目标</b><small>${s.todayXP} / ${goal} XP · 点圆环修改</small>${percent===100?'<small>今日目标已完成</small>':''}</span></button>
      ${dailyQuests(s.quests)}
      ${profileRow('medal','corn','成就',achievementRows().length+' / 16 解锁','data-x-panel="achievements"')}
      ${profileRow('card','mint','知识卡册',`已收集 ${s.owned} 张 · 集齐单元召唤守护兽`,'data-to="cards"')}
      ${profileRow('settings','cool','设置','声音、触感、外观、提醒、存档','data-x-panel="settings"')}
    </div>`;
  }

  function panel(key) {
    const opts = {
      name: ['给自己起个名字', `<form class="x-name-form"><label>昵称<input name="nickname" value="${safeName()}" maxlength="24" required></label><button class="cta">保存</button></form>`],
      share: ['分享连胜', `<div class="x-share-card">${art('hero',104,96)}<b>${safeName()} · ${ui.sample().streak} 天连胜</b>${week(ui.sample().streak)}</div>`],
      achievements: ['成就', achievementRows().map(([n,d])=>`<p class="x-dlg-row"><b>${n}</b><small>${d}</small></p>`).join('')],
      settings: ['设置', '<div class="x-settings-summary"><p><b>学习方式</b><small>儿童模式（推荐） · 已开启</small></p><p><b>声音与触感</b><small>音效、自动朗读、触感振动</small></p><p><b>外观</b><small>主题 · 跟随系统</small></p><p><b>提醒</b><small>连胜提醒</small></p><p><b>存档</b><small>导出 / 导入学习进度</small></p></div>']
    };
    const [title,body] = opts[key];
    const phone = document.getElementById('phone');
    phone.insertAdjacentHTML('beforeend',`<div class="sheet-wrap"><section class="sheet" role="dialog" aria-modal="true" aria-label="${title}"><button class="icon-btn" data-dismiss aria-label="关闭">${icon('close',18)}</button><h2>${title}</h2>${body}<button class="plain-btn" data-dismiss>${key==='name'?'取消':'关闭'}</button></section></div>`);
    const field=phone.querySelector('.x-name-form input');
    if(field)field.focus();else phone.querySelector('.sheet .icon-btn').focus();
  }
  function refreshActive() {
    const body = document.querySelector('.app-body');
    const render = {shop,profile}[body?.dataset.scene];
    if(render)body.innerHTML=render();
  }
  document.addEventListener('click',e=>{
    const btn=e.target.closest('button');
    if(!btn||btn.disabled)return;
    if(btn.dataset.xPanel)panel(btn.dataset.xPanel);
    if(!btn.dataset.xBuy)return;
    const item=goods.find(([id])=>id===btn.dataset.xBuy);
    if(!item)return;
    const [id,type,,cost]=item;
    if(state().purchased.has(id)||id.endsWith('_default'))state().equipped[type]=id;
    else if(ui.sample().gems>=cost){state().spent+=cost;state().purchased.add(id);}
    refreshActive();
  });
  document.addEventListener('submit',e=>{
    const form=e.target.closest('.x-name-form');
    if(!form)return;
    e.preventDefault();
    const value=form.elements.nickname.value.trim().slice(0,24);
    if(!value)return;
    state().name=value;
    form.closest('.sheet-wrap').remove();
    refreshActive();
  });
  window.extraScreens={league,shop,profile};
})();
