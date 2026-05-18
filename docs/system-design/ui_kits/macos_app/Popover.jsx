// Tally · Popover — the 3-second glance.
// Matches PRD §6.1 exactly: big number, progress, top-5, "open full window".

function Popover({ onOpenMain, onClose }) {
  const pct = Math.round((TOTAL_GB / CAP_GB) * 100);
  const top5 = MOCK_APPS.slice(0, 5);
  return (
    <div className="popover" role="dialog" aria-label="Tally" data-screen-label="Popover">
      <div className="pop-hero">
        <span className="num">{TOTAL_GB.toFixed(1)}</span>
        <span className="unit">GB</span>
        <span className="meta">
          <div className="pop-meta-num">{(CAP_GB - TOTAL_GB).toFixed(1)} GB</div>
          <div>還能用</div>
        </span>
      </div>
      <div className="pop-progress" aria-label={`已用 ${pct}%`}>
        <div style={{ width: pct + '%' }}></div>
      </div>
      <div className="pop-net">
        <Icon name="wifi" size={12} stroke={2} />
        你現在連在 <strong style={{ color: 'var(--fg-1)', fontWeight: 500 }}>家裡的 Wi-Fi</strong>
      </div>

      <div className="pop-section-label">這個月用最多的</div>
      {top5.map(app => (
        <div className="pop-row" key={app.name}>
          <AppIcon name={app.name} size={20} />
          <span style={{ fontSize: 12 }}>{app.name}</span>
          <span className="num">{app.gb.toFixed(2)} GB</span>
        </div>
      ))}

      <div className="pop-divider"></div>
      <div className="pop-footer">
        <button className="open-btn" onClick={onOpenMain}>
          <Icon name="expand" size={13} stroke={1.8} />
          打開完整畫面
        </button>
        <button className="gear" title="設定" onClick={onOpenMain}>
          <Icon name="gear" size={15} />
        </button>
      </div>
    </div>
  );
}
Object.assign(window, { Popover });
