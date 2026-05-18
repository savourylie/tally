// Tally · MainWindow — the 960×640 NSWindow w/ sidebar + content router.

const { useState: useStateMW } = React;

function MainWindow({ onClose, initialTab = 'overview', onReplayOnboarding }) {
  const [tab, setTab] = useStateMW(initialTab);

  const SbItem = ({ id, icon, label, advanced }) => (
    <div className={"sb-item" + (tab === id ? " active" : "") + (advanced ? " advanced" : "")}
         onClick={() => !advanced && setTab(id)}
         style={advanced ? { opacity: 0.45, cursor: 'not-allowed' } : {}}
         title={advanced ? "v0.2+ 才會啟用" : ""}>
      <Icon name={icon} size={16}/>
      {label}
    </div>
  );

  return (
    <div className="win-wrap" onClick={(e) => { if (e.target === e.currentTarget) onClose(); }}>
      <div className="win" data-screen-label="Main window" onClick={(e) => e.stopPropagation()}>
        <div className="win-titlebar">
          <div className="tl-left">
            <span className="tl-dot red" onClick={onClose} title="關閉"></span>
            <span className="tl-dot yellow" title="縮小"></span>
            <span className="tl-dot green" title="放大" style={{ opacity: 0.5 }}></span>
          </div>
          <div className="tl-right">Tally</div>
        </div>
        <div className="win-body">
          <aside className="sidebar">
            <SbItem id="overview" icon="grid" label="總覽"/>
            <SbItem id="apps" icon="apps" label="Apps" advanced/>
            <SbItem id="history" icon="history" label="歷史" advanced/>
            <SbItem id="network" icon="network" label="網路" advanced/>
            <div style={{ height: 8 }}></div>
            <SbItem id="settings" icon="gear" label="設定"/>
            <div style={{ flex: 1 }}></div>
            <div className="sb-section-label" style={{ paddingBottom: 8 }}>
              v0.1 · MVP
            </div>
          </aside>
          <main className="content">
            {tab === 'overview'
              ? <OverviewScreen />
              : <SettingsScreen onReplayOnboarding={onReplayOnboarding}/>}
          </main>
        </div>
      </div>
    </div>
  );
}
Object.assign(window, { MainWindow });
