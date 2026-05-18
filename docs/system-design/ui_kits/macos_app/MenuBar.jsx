// Tally · MenuBar (faux desktop menu bar that hosts the tally icon)
const { useState: useStateMB } = React;

function MenuBar({ usageLabel, onTallyClick, popoverOpen }) {
  return (
    <div className="menubar">
      <span className="apple">
        <svg width="14" height="14" viewBox="0 0 24 24" fill="currentColor"><path d="M16.5 12.5c0-2.5 2-3.7 2.1-3.8-1.1-1.7-2.9-2-3.5-2-1.5-.2-2.9.9-3.7.9s-1.9-.9-3.2-.9c-1.6 0-3.2 1-4 2.5-1.7 3-.4 7.3 1.2 9.7.8 1.2 1.8 2.5 3.1 2.4 1.2 0 1.7-.8 3.2-.8s1.9.8 3.2.8c1.3 0 2.2-1.2 3-2.4.9-1.4 1.3-2.7 1.3-2.7s-2.7-1-2.7-3.7zm-2.6-6.6c.7-.8 1.1-2 1-3.2-1 0-2.3.7-3 1.5-.7.7-1.2 1.9-1.1 3.1 1.2.1 2.4-.6 3.1-1.4z"/></svg>
      </span>
      <span className="app-name">Tally</span>
      <span className="menu-item">檔案</span>
      <span className="menu-item">編輯</span>
      <span className="menu-item">顯示</span>
      <span className="menu-item">視窗</span>
      <span className="menu-item">說明</span>
      <span className="spacer"></span>
      <div className="right-cluster">
        <span className={"tally-icon" + (popoverOpen ? " active" : "")}
              onClick={onTallyClick}
              title="Tally — 本月流量"
              data-comment-anchor="menubar-tally-icon">
          <svg width="14" height="14" viewBox="0 0 22 22">
            <g stroke="currentColor" strokeWidth="1.7" strokeLinecap="round" fill="none">
              <line x1="5" y1="6" x2="5" y2="16"/>
              <line x1="9" y1="6" x2="9" y2="16"/>
              <line x1="13" y1="6" x2="13" y2="16"/>
              <line x1="17" y1="6" x2="17" y2="16"/>
              <line x1="3.5" y1="15" x2="18.5" y2="7"/>
            </g>
          </svg>
          <span>{usageLabel}</span>
        </span>
        <Icon name="wifi" size={14} stroke={2} />
        <Icon name="battery" size={16} stroke={1.6} />
        <span className="clock">週日 14:32</span>
      </div>
    </div>
  );
}
Object.assign(window, { MenuBar });
