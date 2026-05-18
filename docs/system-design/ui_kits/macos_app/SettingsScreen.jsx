// Tally · SettingsScreen — the 設定 page.
// PRD §6.3: billing cycle, monthly cap, alert thresholds, autostart, advanced toggle.

const { useState: useStateSet } = React;

function SettingsScreen({ onReplayOnboarding }) {
  const [cap, setCap] = useStateSet(20);
  const [unlimited, setUnlimited] = useStateSet(false);
  const [cycleDay, setCycleDay] = useStateSet('1');
  const [a80, setA80] = useStateSet(true);
  const [a95, setA95] = useStateSet(true);
  const [a100, setA100] = useStateSet(false);
  const [autostart, setAutostart] = useStateSet(true);
  const [advanced, setAdvanced] = useStateSet(false);
  const [menubarShow, setMenubarShow] = useStateSet('total');

  return (
    <div data-screen-label="Settings">
      <h2 style={{ margin: '0 0 18px', fontSize: 22, fontWeight: 600, letterSpacing: '-0.01em' }}>設定</h2>

      <div className="set-section">
        <div className="set-row">
          <div>
            <div className="label">每月從幾號開始算</div>
            <div className="desc">和你的網路帳單對齊。預設是每月 1 號。</div>
          </div>
          <select className="tally-select" value={cycleDay} onChange={e => setCycleDay(e.target.value)}>
            <option value="1">1 號</option>
            <option value="15">15 號</option>
            <option value="last">每月最後一天</option>
          </select>
        </div>

        <div className="set-row">
          <div>
            <div className="label">每月可以用多少</div>
            <div className="desc">若沒有上限，Tally 只追蹤、不警告。</div>
          </div>
          <div style={{ display: 'flex', alignItems: 'center', gap: 12 }}>
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

      <div className="set-section">
        <div className="set-row">
          <div>
            <div className="label">快用完時提醒我</div>
            <div className="desc">用了一定比例之後 Tally 會跳通知。</div>
          </div>
          <div style={{ display: 'flex', gap: 14 }}>
            <span className={"check" + (a80 ? " on" : "")} onClick={() => setA80(!a80)}><span className="box"></span>80%</span>
            <span className={"check" + (a95 ? " on" : "")} onClick={() => setA95(!a95)}><span className="box"></span>95%</span>
            <span className={"check" + (a100 ? " on" : "")} onClick={() => setA100(!a100)}><span className="box"></span>100%</span>
          </div>
        </div>

        <div className="set-row">
          <div>
            <div className="label">menu bar 顯示</div>
            <div className="desc">點擊圖示之前你看到的數字。</div>
          </div>
          <select className="tally-select" value={menubarShow} onChange={e => setMenubarShow(e.target.value)}>
            <option value="total">本月總用量</option>
            <option value="remain">剩餘額度</option>
            <option value="none">只顯示圖示</option>
          </select>
        </div>

        <div className="set-row">
          <div>
            <div className="label">開機自動啟動 Tally</div>
            <div className="desc">登入時自動打開，不會跳到前景。</div>
          </div>
          <label className="toggle"><input type="checkbox" checked={autostart} onChange={() => setAutostart(!autostart)}/><span className="slider"></span></label>
        </div>
      </div>

      <div className="set-section">
        <div className="set-row">
          <div>
            <div className="label">Advanced 模式</div>
            <div className="desc">會看到 bundle id、process name、Mbps 等技術細節。
              <a style={{ color: 'var(--fg-3)', marginLeft: 4, fontSize: 11 }}>v0.3 才解鎖</a>
            </div>
          </div>
          <label className="toggle" style={{ opacity: 0.4, pointerEvents: 'none' }}>
            <input type="checkbox" checked={advanced} onChange={() => setAdvanced(!advanced)}/>
            <span className="slider"></span>
          </label>
        </div>

        <div className="set-row">
          <div>
            <div className="label">重新跑一次 Onboarding</div>
            <div className="desc">重新走一次歡迎流程，包含 Network Extension 權限設定。</div>
          </div>
          <button className="btn btn-secondary" onClick={onReplayOnboarding}>啟動</button>
        </div>
      </div>

      <p style={{ fontSize: 11, color: 'var(--fg-3)', textAlign: 'center', marginTop: 22 }}>
        Tally v0.1 · MVP 一般模式 · 所有資料留在你的 Mac 上
      </p>
    </div>
  );
}
Object.assign(window, { SettingsScreen });
