(function studyPrototype() {
  'use strict';
  const paths = {
    book:'<path d="M3 5c3-1 6-.6 9 1.5C15 4.4 18 4 21 5v14c-3-.9-6-.5-9 1.4C9 18.5 6 18.1 3 19zM12 6.5v13"/>',
    house:'<path d="m3 10 9-7 9 7v9.5a1 1 0 0 1-1 1h-5v-6h-6v6H4a1 1 0 0 1-1-1z"/>',
    trophy:'<path d="M7 3h10v5c0 4-2 7-5 7s-5-3-5-7zM7 5H3v2c0 3 2 5 5 5m9-7h4v2c0 3-2 5-5 5m-4 3v5m-4 1h8"/>',
    repeat:'<path d="M4 8a8 8 0 1 1-.4 7M4 3v5h5"/>',
    bag:'<rect x="4" y="7.5" width="16" height="14" rx="3"/><path d="M8.5 9V6a3.5 3.5 0 0 1 7 0v3"/>',
    user:'<circle cx="12" cy="8" r="4"/><path d="M4 21v-2a8 6 0 0 1 16 0v2"/>',
    diamond:'<path d="m2 8 4-5h12l4 5-10 13zM2 8h20M7 3l5 18 5-18"/>',
    fire:'<path d="M13 2c.8 5 4 5.7 4 10 1-1 1.7-2 1.6-3.5C23 14.5 19.5 21 12 21c-6.5 0-10-6.5-6.3-11.7.2 2.3.9 3 1.8 3.6C6.6 7.2 11 6.2 13 2Z"/>',
    check:'<path d="m5 12 4.5 4.5L19 7"/>', chevron:'<path d="m9 5 7 7-7 7"/>',
    card:'<path d="m5 17-2 .1L2 5l13-1 .2 2"/><rect x="6" y="7" width="15" height="14" rx="2.5"/><path d="m13.5 10.6.9 2.3 2.4.8-2.4 1-.9 2.3-1-2.3-2.4-1 2.4-.8z"/>',
    target:'<circle cx="12" cy="12" r="9"/><circle cx="12" cy="12" r="5"/><circle cx="12" cy="12" r="1.2"/>',
    lock:'<rect x="5" y="10" width="14" height="11" rx="3"/><path d="M8 10V7a4 4 0 0 1 8 0v3m-4 4v3"/>',
    settings:'<path d="m9 3 6 0 1 3 3 .5 2 4-2 2 .2 3-3.7 3-2-1-2 2.5-4-1-1-3-2.6-1-1.1-4 2-2 .2-3 3-1z"/><circle cx="12" cy="12" r="3"/>',
    medal:'<circle cx="12" cy="9" r="6.5"/><path d="m7 14-2 7 5-2 2 2 2-2 5 2-2-7"/>',
    heart:'<path d="M12 21S2 14.3 2 8.1C2 3 8.4 1.6 12 6.2 15.6 1.6 22 3 22 8.1 22 14.3 12 21 12 21z"/>',
    calendar:'<rect x="3" y="5" width="18" height="16" rx="3"/><path d="M3 10h18M8 3v4m8-4v4m-9 7h3m3 0h3"/>',
    star:'<path d="m12 2 3 6.3 7 .9-5.1 5 1.2 7-6.1-3.3-6.1 3.3 1.2-7-5.1-5 7-.9z"/>',
    shield:'<path d="m12 2 8 3v6c0 5.5-3.6 8.5-8 11-4.4-2.5-8-5.5-8-11V5z"/><path d="m8 12 3 3 5-6"/>',
    clock:'<circle cx="12" cy="12" r="9"/><path d="M12 6v6l4 2"/>',
    leaf:'<path d="M20.5 3c1.5 10-3.8 18-12 15-8-3 0-15 12-15ZM4 21l11-12"/>',
    bolt:'<path d="m13 2-9 12h7l-1 8 10-13h-7z"/>', flag:'<path d="M5 21V3m0 1c5-3 8 3 14 0v9c-6 3-9-3-14 0"/>',
    gift:'<rect x="3" y="8" width="18" height="4" rx="1"/><path d="M5 12v9h14v-9M12 8v13m0-13C2 10 5-1 10 4l2 4c10 2 7-9 2-4z"/>',
    arrow:'<path d="M4 12h16m-6-6 6 6-6 6"/>', pencil:'<path d="m4 16 11-11a2.4 2.4 0 0 1 4 4L8 20l-5 1zM14 6l4 4"/>',
    chart:'<path d="M3 3v18h18M7 17v-4m5 4V9m5 8V5"/>', close:'<path d="m5 5 14 14M19 5 5 19"/>',
    checkCircle:'<circle cx="12" cy="12" r="9"/><path d="m7.7 12 3 3 5.5-6"/>', back:'<path d="m15 5-7 7 7 7"/>',
    key:'<circle cx="15.5" cy="8.5" r="5"/><path d="m11.6 12.4-8 8V17l2.5-.5.5-2.5 2.5-.5"/>',
    sparkles:'<path d="m10 3 2 6 6 2-6 2-2 6-2-6-6-2 6-2zm8 10 1.2 3.8L23 18l-3.8 1.2L18 23l-1.2-3.8L13 18l3.8-1.2z"/>',
    grid:'<rect x="3" y="3" width="7" height="7" rx="1"/><rect x="14" y="3" width="7" height="7" rx="1"/><rect x="3" y="14" width="7" height="7" rx="1"/><rect x="14" y="14" width="7" height="7" rx="1"/>'
  };
  const notes = {
    home:   ['学习路径','从课本开始','一年级数学的第一单元有三课。沿着地图可以看到学过的课、当前课程和单元挑战。','点当前节点，再点「开始」预览第 3 题。顶部卡牌和目标环也可点击。'],
    lesson: ['课堂练习','从课本开始','选用种子课本中第 3 题的真实题干和四个选项。杯盖与杯子一一对应，孩子可以直接数。','任选一项再点「检查」。此处演示一题，其余四题按首次答对处理，随后预览对应的结算。'],
    result: ['课程结算','从课本开始','默认展示普通工作日首次答对 4/5 的结算样例。40 XP 即时到账。28 宝石包含首次达成当日目标的 20 宝石。','点「去收服心魔」进入试炼。也可以回到课堂选择正确答案，查看首次满分的金卡。'],
    review: ['错题本','把错题学会','心魔录让孩子从一节具体的课找回封存的宝箱。到期复习和待收服心魔分别显示。','打开待收服的宝箱，可以再次看到原题和相应的同类题。'],
    remedy: ['心魔试炼','把错题学会','先订正原题，再答对两道同类题。成功解封后收回本课宝石、银卡和收服奖励。','点「开始收服」，按题目作答。连续答错时，可先查看讲解。'],
    cards:  ['知识卡册','把错题学会','示例展示宝箱解封后的第一单元。已获卡能翻面查看本课小结，集齐三张可召唤单元守护兽。','点一张已获得的卡，翻到背面读核心概念和方法。'],
    league: ['排行','看见学习进度','完成 10 课后开放本地联赛。这一屏展示只完成一课时的解锁提示。','通过底栏返回学习，继续完成解锁所需的课程。'],
    shop:   ['商店','看见学习进度','宝石余额与道具价格并排呈现，便于比较。道具与装扮沿用项目内的定价和库存规则。','浏览道具和装扮，再用底栏前往「我的」查看学习记录。'],
    profile:['我的','看见学习进度','连胜日历记录学习天数。「今日目标」下方列出三项每日任务的进度和宝石奖励。','完成任务后点「领取」收下宝石。下方的知识卡册可以查看已学知识。']
  };
  const sourceLinks={home:['Books.ets','components/PathMap.ets','components/Widgets.ets'],lesson:['Lesson.ets','Questions.ets'],result:['LessonResult.ets'],review:['ReviewLeagueShop.ets'],remedy:['Remedy.ets','domain/KidsMode.ets'],cards:['Cards.ets'],league:['ReviewLeagueShop.ets'],shop:['ReviewLeagueShop.ets'],profile:['Profile.ets','components/Widgets.ets']};
  const groups = [['从课本开始',['home','lesson','result']],['把错题学会',['review','remedy','cards']],['看见学习进度',['league','shop','profile']]];
  const params = new URLSearchParams(location.search);
  const capture = params.has('capture');
  const titles = ['1~10各数的数数与认读','同样多、多、少的含义','比多少的实践应用'];
  const claimedQuests = new Set();
  let todayXP=20, dailyLessons=0, dailyReviews=0;
  let goal=50, due=false, lessonGems=28, remedyReturn='home', albumReturn='home';
  const prefs=[true,true,true];
  let scene = 'home', phase = 'before', answer = null, checked = false, cardTab = 'home';
  const byId = id => document.getElementById(id);
  function icon(name, size=20) {
    return `<svg class="ui-icon" aria-hidden="true" width="${size}" height="${size}" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.85" stroke-linecap="round" stroke-linejoin="round">${paths[name] || ''}</svg>`;
  }
  function art(name,width,height) {
    return `<img class="study-art" alt="" src="assets/${name}.webp" width="${width}" height="${height}">`;
  }
  function sample() {
    const quests = [
      {id:'earnXP-30',icon:'bolt',title:'获得 30 点经验',progress:todayXP,target:30,reward:10},
      {id:'finishLessons-2',icon:'book',title:'完成 2 节小课',progress:dailyLessons,target:2,reward:20},
      {id:'reviewMistakes-1',icon:'repeat',title:'复习 1 道错题',progress:dailyReviews,target:1,reward:10}
    ].map(q => ({...q, progress:Math.min(q.progress,q.target), claimed:claimedQuests.has(q.id)}));
    const questGems = quests.reduce((sum,q) => sum + (q.claimed ? q.reward : 0), 0);
    return {done:phase==='before'?1:2, owned:['unsealed','gold'].includes(phase)?2:1,
      gems:128+questGems+(phase==='gold'?lessonGems:phase==='unsealed'?lessonGems+2:0)-(window.studyTabState?.spent || 0),
      quests, todayXP, goal, perfect:phase==='gold'?2:1,
      sealedGems:lessonGems, streak:3};
  }
  window.ui = {icon, art, sample,
    reviewOriginal(isCorrect){due=!isCorrect;},
    recordReview(isCorrect){dailyReviews++;if(isCorrect)todayXP+=10;},
    closeCards(){go(albumReturn);},closeRemedy(){go(remedyReturn);},unseal(){phase='unsealed';go(remedyReturn);}
  };
  function statusBar() {
    return `<div class="phone-status"><time>09:41</time><span class="signal" aria-label="网络信号"><i></i><i></i><i></i><i></i></span><svg width="16" height="13" viewBox="0 0 18 14" aria-hidden="true" fill="currentColor"><path d="M.5 4Q9-3 17.5 4l-1.8 1.8q-6.6-5.3-13.4 0zm3.1 3.1Q9 2.7 14.4 7.1l-1.9 1.8q-3.5-2.7-7 0zm3.1 3.2q2.3-2.1 4.6 0L9 13z"/></svg><span class="battery"></span></div>`;
  }
  function bottomNav() {
    const items=[['home','house','学习'],['league','trophy','排行'],['review','book','错题本'],['shop','bag','商店'],['profile','user','我的']];
    return `<nav class="bottom-nav" aria-label="应用导航">${items.map(([id,i,label])=>`<button class="${(scene===id||(scene==='cards'&&id===cardTab))?'active':''}" data-to="${id}"><span>${icon(i,22)}</span>${label}</button>`).join('')}</nav>`;
  }
function home() {
    const s=sample();
    const nodes=titles.map((label,i)=>{
      const current=i===s.done,done=i<s.done;
      return `<button class="map-stop stop-${i+1} ${current?'current':done?'done':'locked'}" aria-haspopup="dialog" data-modal="${['first','start','third'][i]}">
        <span class="node-icon">${icon(done?'star':current?'pencil':'lock',24)}</span>
        <span class="node-label"><small>第 ${i+1} 课 · ${done?'已完成':current?'当前课程':'未解锁'}</small><strong>${label}</strong></span></button>`;
    }).join('');
    return `<div class="learn-page"><header class="home-stats">
      <span class="stat-badge streak" title="连胜 3 天">${icon('fire',18)} 3 天</span>
      <span class="stat-badge money" title="宝石余额">${icon('diamond',17)} ${s.gems}</span>
      <button class="stat-badge card-count" data-to="cards" aria-label="知识卡册，${s.owned} 张">${icon('card',18)} ${s.owned}</button>
      ${phase==='sealed'?`<button class="stat-badge" data-to="review" aria-label="1 只心魔">👾 1</button>`:''}
      <button class="goal-toggle" data-modal="goal" aria-label="每日目标 ${s.todayXP}/${s.goal} XP"><i style="--goal:${Math.min(100,100*s.todayXP/s.goal)}%">${icon('bolt',14)}</i><span>今日目标<b>${s.todayXP} / ${s.goal}</b></span></button>
      </header>
      <div class="book-row"><button class="book-title" data-modal="book"><span class="book-symbol">${icon('book',21)}</span><span><strong>人教版数学 · 一年级上册</strong><small>旧版 · ${s.done} 课已完成</small></span></button><button class="switch-book" data-modal="switch">换课本</button></div>
      <section class="map-panel"><div class="unit-banner"><div><small>第 1 单元</small><h1>准备课</h1></div><button data-modal="book">${icon('book',17)} 知识手册</button></div>
      <div class="path-map"><svg class="path-line" aria-hidden="true"><path fill="none" stroke="#cbddba" stroke-width="5" stroke-dasharray="0 9" stroke-linecap="round"/></svg>
      <span class="map-panda">${art('hero',90,87)}</span>${nodes}<button class="map-stop stop-exam locked" data-modal="exam"><span class="node-icon">${icon("trophy",20)}</span><span class="node-label"><small>单元挑战 · 未解锁</small><strong>第 1 单元挑战</strong></span></button></div></section>
    </div>`;
  }
  const answers=['同样多','杯子多','盖子多','无法确定'];
  function cupDiagram() {
    const pairs=Array.from({length:3},()=>`<div class="cup-pair"><div class="lid"><i></i></div><div class="paired"></div><div class="cup-holder"><i></i><b></b></div><div class="cup-shadow"></div></div>`).join('');
    return `<figure class="math-board" aria-label="3 个盖子和 3 个杯子一一对应"><div class="pair-row">${pairs}</div></figure>`;
  }
function lesson() {
    return `<div class="lesson-page"><div class="lesson-progress"><button class="icon-btn" aria-label="离开练习" data-modal="exit">${icon('close',20)}</button>
      <div class="progress-segs" aria-label="已完成 2/5"><i></i></div><span class="lesson-gift" title="本课宝箱">${checked&&answer!==0?'👾 1':art('chest',28,25)}</span><button class="icon-btn" data-modal="settings" aria-label="练习设置">${icon('settings',18)}</button></div>
      <div class="q-header"><strong>选择正确答案</strong><span>第 3 / 5 题</span></div>
      <div class="question-stem"><h1>桌上有3个杯子和3个盖子，杯子和盖子的数量关系是？</h1><button data-action="read" class="audio-btn" aria-label="朗读题干"><svg viewBox="0 0 24 24" width="18" height="18" fill="none" stroke="currentColor" stroke-width="2"><path d="M3 9h4l5-5v16l-5-5H3z" fill="currentColor"/><path d="M15 8q4 4 0 8m3-11q7 7 0 14"/></svg></button></div>
      ${cupDiagram()}<div class="answer-grid">${answers.map((text,index)=>`<button data-answer="${index}" aria-pressed="${answer===index}" ${checked?'disabled':''} class="option ${answer===index?'picked':''} ${checked&&index===0?'correct':''} ${checked&&index===answer&&index!==0?'wrong':''}"><span>${'ABCD'[index]}</span><strong>${text}</strong>${answer===index?icon('checkCircle',16):''}</button>`).join('')}</div>
      <div class="lesson-action">${checked?`<div class="answer-feedback ${answer===0?'good':''}">${icon(answer===0?'checkCircle':'book',20)}<div><b>${answer===0?'答对了！':'正确答案：同样多'}</b><p>数量都是3，所以同样多。</p></div></div>`:''}
      <button class="cta" ${answer===null?'disabled':''} data-action="${checked?'finish':'check'}">${checked?(answer===0?'继续':'知道了'):'检查'}</button></div></div>`;
  }
function result() {
    const gold=phase==='gold',sealed=phase==='sealed';
    const stats=[['bolt',gold?'+60':'+40','经验'],['diamond',gold?'+'+lessonGems:'+0','宝石'],['target',gold?'100%':'80%','正确率'],['fire','3 天','连胜']];
    return `<div class="result-page"><div class="result-scroll"><header class="award-stage"><span class="rays"></span><div class="congrats">${art('hero',112,112)}</div><div class="stage-stars" aria-label="${gold?3:2} 星"><span>★</span><span>★</span><span class="${gold?'':'empty'}">★</span></div><h1>${titles[1]}</h1><p>${gold?'5':'4'} / 5 题首次答对</p></header>
      <div class="result-stats">${stats.map(([i,val,txt])=>`<div class="res-${i}">${icon(i,17)}<strong>${val}</strong><small>${txt}</small></div>`).join('')}</div>
      <section class="reward-card"><div class="reward-top">${art(gold?'cards':'chest',83,73)}<div><span class="amber-chip">${icon(gold?'card':'lock',12)} ${gold?'金卡':sealed?'1 只心魔待收服':'已解封'}</span><h2>${gold?'获得知识卡！':sealed?'宝箱被心魔封住了':'宝箱已解封'}</h2></div></div>
      <p>${gold?'首次满星获得金卡，已收进知识卡册。':sealed?`经验已到账。收服后取回 ${lessonGems} 宝石和本课银卡，再得 2 宝石收服奖励。`:`已收下本课银卡和 ${lessonGems+2} 宝石。`}</p>
      <button class="reward-btn" data-to="${sealed?'remedy':'cards'}">${sealed?'去收服心魔':'查看知识卡册'} ${icon('chevron',15)}</button></section></div>
      <div class="result-action"><button class="share-btn" data-modal="share">${icon('arrow',15)} 分享成绩</button><button class="cta" data-to="home">继续</button></div></div>`;
  }
  function drawPath(map) {
    const svg = map.querySelector('.path-line');
    const toLocal = svg.getScreenCTM().inverse();
    const centers = Array.from(map.querySelectorAll('.node-icon'), node => {
      const rect = node.getBoundingClientRect();
      return new DOMPoint(rect.x + rect.width / 2, rect.y + rect.height / 2).matrixTransform(toLocal);
    });
    let curve = `M ${centers[0].x} ${centers[0].y}`;
    for (let i = 1; i < centers.length; i++) {
      const from = centers[i - 1], to = centers[i];
      const midY = (from.y + to.y) / 2;
      curve += ` C ${from.x} ${midY}, ${to.x} ${midY}, ${to.x} ${to.y}`;
    }
    svg.querySelector('path').setAttribute('d', curve);
  }
  const mapResize = new ResizeObserver(entries => {
    for (const entry of entries) drawPath(entry.target);
  });
  function paint() {
    const immersive=['lesson','result','remedy'].includes(scene);
    const renderers={home,lesson,result,...window.extraScreens,...window.recoveryScreens};
    const content=scene==='cards'?renderers.cards(sample().owned,phase==='gold'?3:2):scene==='review'?renderers.review(phase==='sealed',due,phase==='sealed'||phase==='unsealed'):renderers[scene]();
    const phone=byId('phone');
    mapResize.disconnect();
    phone.innerHTML=statusBar()+`<div class="app-body" data-scene="${scene}">${content}</div>`+(immersive?'':bottomNav())+'<div class="gesture" aria-hidden="true"><i></i></div>';
    phone.classList.toggle('immersive',immersive);
    if (scene === 'home') mapResize.observe(phone.querySelector('.path-map'));

    const [name,group,desc,action]=notes[scene];
    byId('scene-name').textContent=name;
    byId('group-name').textContent=group;
    byId('scene-desc').textContent=desc;
    byId('scene-action').textContent=action;
    byId('source-ref').innerHTML=sourceLinks[scene].map(file=>{
      const name=file.split('/').pop();
      return '<a href="../../entry/src/main/ets/'+(file.includes('/')?file:'features/'+file)+'">'+name+'</a>';
    }).join(' · ');
    byId('download').href=`screens/${scene}.png`;
    byId('scene-picker').value=scene;
    const ids=Object.keys(notes);
    byId('page-mark').textContent=`${String(ids.indexOf(scene)+1).padStart(2,'0')} / ${String(ids.length).padStart(2,'0')}`;
    document.querySelectorAll('[data-show]').forEach(b=>b.classList.toggle('active',b.dataset.show===scene));
  }
  function preset(id) {
    claimedQuests.clear();goal=50;lessonGems=28;remedyReturn='home';albumReturn='home';due=['review','result','remedy'].includes(id);window.resetStudyTabs?.();
    phase=({result:'sealed',review:'sealed',remedy:'sealed',cards:'unsealed'})[id]||'before';
    dailyLessons=phase==='before'?0:1;
    todayXP=phase==='before'?20:60;
    dailyReviews=0;
    answer=null; checked=false; cardTab='home';
    go(id);
  }
  function go(id) {
    if (!Object.hasOwn(notes,id)) return;
    if(id==='cards'&&['home','profile','review'].includes(scene)){cardTab=scene;albumReturn=scene;}
    if(id==='remedy')remedyReturn=scene==='review'?'review':'home';
    if(id==='lesson'&&scene!=='lesson'){answer=null;checked=false;}
    scene=id;
    if(!capture)history.replaceState(null,'',`#${id}`);
    paint();
  }
function modal(name) {
    const s=sample();
    const modals={
      exam:['第 1 单元挑战','准备课','<p>完成本单元的 3 节课后开放挑战。</p>'],
      book:['单元知识手册','第 1 单元 · 准备课',`<h3>本单元知识点</h3><ol>${titles.map((v,i)=>`<li>${v}<small>${i<s.done?'已完成':i===s.done?'当前课程':'未解锁'}</small></li>`).join('')}</ol>`],
      switch:['选择课本','一年级',`<div class="sample-book">${icon('book',27)}<div><b>人教版小学数学一年级上册（旧版）</b><p>学习中 · 已下载</p></div></div>`],
      goal:['每日目标','选择你的每日 XP 目标',`<div class="goal-list">${[20,50,100,200].map(n=>'<button data-goal="'+n+'" aria-pressed="'+(goal===n)+'">'+n+' XP</button>').join('')}</div>`],
      first:['第 1 / 3 节',titles[0],'<p>这节课的知识卡已收进卡册。</p><button class="cta" data-to="cards">查看知识卡</button>'],
      start:[titles[1],'第 2 / 3 节 · 5 道题',`<button class="cta" data-to="lesson">${s.done===2?'再练一次':'开始'}</button>`],
      third:['第 3 / 3 节',titles[2],s.done<2?'<p>完成上一课后即可解锁。</p>':'<p>本课学习用一一对应的方法比较数量。</p>'],
      settings:['练习设置','',`<div class="setting-rows">${['音效','触感振动','自动朗读'].map((v,i)=>`<label>${v}<input type="checkbox" data-pref="${i}" ${prefs[i]?'checked':''}></label>`).join('')}</div>`],
      share:['分享成绩',titles[1],`<div class="share-preview">${art('hero',90,86)}<b>又过一课！</b><p>${phase==='gold'?'3 星 · 100%':'2 星 · 80%'} 正确率</p></div>`],
      exit:['确定退出？','',`<p>已答对 2 / 5 题，现在放弃太可惜啦。</p><button class="cta" data-to="home">退出练习</button>`]
    };
    const [head,sub,html]=modals[name];
    byId('phone').insertAdjacentHTML('beforeend',`<div class="sheet-wrap"><section class="sheet" role="dialog" aria-modal="true" aria-label="${head}"><button class="icon-btn" data-dismiss aria-label="关闭">${icon('close',18)}</button><h2>${head}</h2>${sub?`<small>${sub}</small>`:''}${html}<button class="plain-btn" data-dismiss>${name==='exit'?'继续学习':'关闭'}</button></section></div>`);
    byId('phone').querySelector('.sheet button').focus();
  }
  function handleClick(event) {
    const b=event.target.closest('button');
    if(!b||b.disabled)return;
    if(b.dataset.show){preset(b.dataset.show);return;}
    if(b.dataset.to){go(b.dataset.to);return;}
    if(b.dataset.modal){modal(b.dataset.modal);return;}
    if(b.hasAttribute('data-dismiss')){b.closest('.sheet-wrap').remove();return;}
    if(b.hasAttribute('data-answer')){answer=Number(b.dataset.answer);paint();return;}
    if(b.dataset.goal){goal=Number(b.dataset.goal);paint();return;}
    if(b.dataset.action==='quest'){
      const quest = sample().quests.find(q => q.id===b.dataset.quest);
      if(!quest || quest.claimed || quest.progress<quest.target)return;
      const scrollTop = b.closest('.app-body').scrollTop;
      claimedQuests.add(quest.id);
      paint();
      byId('phone').querySelector('.app-body').scrollTop=scrollTop;
      return;
    }
    if(b.dataset.action==='read'){
      if('speechSynthesis' in window){window.speechSynthesis.cancel();const utterance=new SpeechSynthesisUtterance(document.querySelector('.question-stem h1').textContent);utterance.lang='zh-CN';utterance.rate=.85;window.speechSynthesis.speak(utterance);}
      return;
    }
    if(b.dataset.action==='check'&&answer!==null){checked=true;paint();return;}
    if(b.dataset.action==='finish'){
      const earned=answer===0?60:40;
      lessonGems=(answer===0?28:8)+(todayXP<goal&&todayXP+earned>=goal?20:0);
      todayXP+=earned;
      dailyLessons++;
      phase=answer===0?'gold':'sealed';due=phase==='sealed';go('result');
    }
  }
  document.documentElement.classList.toggle('capture',capture);
  byId('brand-icon').innerHTML=icon('book',19);
  byId('scene-list').innerHTML=groups.map(([name,ids])=>`<section><h3>${name}</h3>${ids.map(id=>`<button data-show="${id}">${notes[id][0]}${icon('chevron',13)}</button>`).join('')}</section>`).join('');
  byId('scene-picker').innerHTML=groups.map(([name,ids])=>`<optgroup label="${name}">${ids.map(id=>`<option value="${id}">${notes[id][0]}</option>`).join('')}</optgroup>`).join('');
  byId('scene-picker').addEventListener('change', e=>preset(e.target.value));
  document.addEventListener('click',handleClick);
  document.addEventListener('change',e=>{if(e.target.hasAttribute('data-pref'))prefs[Number(e.target.dataset.pref)]=e.target.checked;});
  document.addEventListener('keydown',e=>{if(e.key==='Escape')byId('phone').querySelector('.sheet-wrap')?.remove();});
  function fit() {
    const stage=document.querySelector('.phone-stage');
    const scale=capture||innerWidth<=700?1:Math.min(1,Math.max(.54,(innerHeight-126)/844),(stage.clientWidth-32)/390);
    document.documentElement.style.setProperty('--phone-scale',scale);
  }
  fit();window.addEventListener('resize',fit);
  const id=params.get('capture')||location.hash.slice(1)||'home';
  preset(Object.hasOwn(notes,id)?id:'home');
})();
