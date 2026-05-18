// Tally · Onboarding — three full-screen modal steps.
// PRD §9: Welcome → Permission → Settings.

const { useState: useStateOnb } = React;

function Onboarding({ onClose }) {
  const [step, setStep] = useStateOnb(0);
  const [cycleDay, setCycleDay] = useStateOnb('1');
  const [cap, setCap] = useStateOnb(20);
  const [unlimited, setUnlimited] = useStateOnb(false);

  const steps = [
    {
      eyebrow: '第 1 步 / 共 3 步',
      title: '歡迎使用 Tally',
      text: <>Tally 追蹤你 Mac 的網路流量，每個月告訴你用了多少、哪些 app 用得最多。<br/><br/>
        <strong style={{ color: 'var(--fg-1)' }}>不會擋網路、不會上傳任何資料到雲端</strong>。所有東西留在你電腦裡。</>,
      art: (
        <svg width="120" height="120" viewBox="0 0 120 120">
          <rect width="120" height="120" rx="28" fill="#FDF6E8" stroke="#F4D38C"/>
          <g stroke="#E89B2F" strokeWidth="8" strokeLinecap="round" fill="none">
            <line x1="32" y1="36" x2="32" y2="84"/>
            <line x1="48" y1="36" x2="48" y2="84"/>
            <line x1="64" y1="36" x2="64" y2="84"/>
            <line x1="80" y1="36" x2="80" y2="84"/>
            <line x1="24" y1="80" x2="88" y2="40"/>
          </g>
        </svg>
      ),
      cta: '繼續',
    },
    {
      eyebrow: '第 2 步 / 共 3 步',
      title: '允許 Tally 看到網路使用情況',
      text: <>Tally 需要安裝一個系統小工具（Network Extension）才能算出每個 app 用了多少流量。<br/><br/>
        按下「繼續」之後，macOS 會彈出一個對話框，請你到 <strong style={{ color: 'var(--fg-1)' }}>系統設定 → 隱私與安全性</strong> 批准。這一步是 macOS 規定的，沒辦法跳過。</>,
      art: (
        <svg width="100" height="100" viewBox="0 0 24 24" fill="none" stroke="#E89B2F" strokeWidth="1.4">
          <rect x="5" y="11" width="14" height="9" rx="2"/>
          <path d="M8 11V8a4 4 0 0 1 8 0v3"/>
          <circle cx="12" cy="15.5" r="1" fill="#E89B2F"/>
        </svg>
      ),
      cta: '繼續',
    },
    {
      eyebrow: '第 3 步 / 共 3 步',
      title: '基本設定',
      text: <>稍微告訴 Tally 你的網路方案，這樣才能算出剩餘額度。等一下還可以從「設定」改。</>,
      art: (
        <div style={{ display: 'flex', flexDirection: 'column', gap: 10, width: 280, fontSize: 12 }}>
          <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
            <span>每月從幾號開始算</span>
            <select className="tally-select" value={cycleDay} onChange={e => setCycleDay(e.target.value)}>
              <option value="1">1 號</option><option value="15">15 號</option><option value="last">每月最後一天</option>
            </select>
          </div>
          <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
            <span>每月可以用多少</span>
            <div style={{ display: 'flex', gap: 10, alignItems: 'center' }}>
              <span className={"check" + (unlimited ? " on" : "")} onClick={() => setUnlimited(!unlimited)}>
                <span className="box"></span>沒有上限
              </span>
              <div className="stepper" style={{ opacity: unlimited ? 0.4 : 1, pointerEvents: unlimited ? 'none' : 'auto' }}>
                <button onClick={() => setCap(c => Math.max(1, c - 1))}>−</button>
                <input value={`${cap} GB`} readOnly />
                <button onClick={() => setCap(c => c + 1)}>+</button>
              </div>
            </div>
          </div>
        </div>
      ),
      cta: '完成',
    },
  ];

  const s = steps[step];

  return (
    <div className="onb-overlay" onClick={(e) => { if (e.target === e.currentTarget) onClose(); }}>
      <div className="onb" data-screen-label={`Onboarding ${step + 1}`}>
        <div className="onb-art">{s.art}</div>
        <div className="onb-body">
          <div className="onb-eyebrow">{s.eyebrow}</div>
          <h2 className="onb-title">{s.title}</h2>
          <p className="onb-text">{s.text}</p>
        </div>
        <div className="onb-actions">
          <div className="onb-dots">
            {steps.map((_, i) => <div key={i} className={"onb-dot" + (i === step ? " on" : "")}></div>)}
          </div>
          {step > 0 && <button className="btn btn-ghost" onClick={() => setStep(step - 1)}>上一步</button>}
          <button className="btn btn-primary" onClick={() => step < steps.length - 1 ? setStep(step + 1) : onClose()}>
            {s.cta}
          </button>
        </div>
      </div>
    </div>
  );
}
Object.assign(window, { Onboarding });
