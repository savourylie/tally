// Tally · OverviewScreen — the 總覽 page inside the main window.
// PRD §6.3: big number, progress, current network sentence, Top 10 cards.

function OverviewScreen() {
  const pct = Math.round((TOTAL_GB / CAP_GB) * 100);
  const estimate = 18.0; // PRD: "以目前速度，月底會用到 18 GB"
  return (
    <div data-screen-label="Overview">
      <div className="hero">
        <div className="hero-row">
          <div>
            <div className="hero-lbl">這個月用了</div>
            <div>
              <span className="hero-num">{TOTAL_GB.toFixed(1)}</span>
              <span className="hero-unit">GB</span>
            </div>
          </div>
          <div className="hero-remain">
            <div className="hero-remain"><span className="c">還可以用</span></div>
            <div className="v">{(CAP_GB - TOTAL_GB).toFixed(1)} GB</div>
            <div className="c">到 6 月 1 日重置</div>
          </div>
        </div>
        <div className="hero-progress"><div style={{ width: pct + '%' }}></div></div>
        <div className="hero-est">
          以目前的速度，月底大概會用到 <strong>{estimate.toFixed(0)} GB</strong>
        </div>
        <div className="hero-net">
          <Icon name="wifi" size={14} stroke={1.8}/>
          你現在連在 <strong style={{ color: 'var(--fg-1)' }}>家裡的 Wi-Fi</strong>
        </div>
      </div>

      <div className="section-header">
        <h3>這個月用最多的</h3>
        <span className="hint">— 點任一項看細節</span>
        <span className="filter">依用量排序</span>
      </div>

      <div className="list">
        {MOCK_APPS.map(app => (
          <div className="app-row" key={app.name}>
            <AppIcon name={app.name} size={32} />
            <div>
              <div className="name">{app.name}</div>
              <div className="sub">{app.sub}</div>
            </div>
            <div className="num">{app.gb.toFixed(2)} GB</div>
            <div className="pct">佔 {app.pct}%</div>
          </div>
        ))}
      </div>
    </div>
  );
}
Object.assign(window, { OverviewScreen });
