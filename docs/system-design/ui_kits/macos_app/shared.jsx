// Tally · shared primitives shared between Popover, MainWindow, Onboarding.
// Babel-transpiled; exported to window for cross-file use.

const { useState, useEffect, useRef } = React;

// -- Iconography ------------------------------------------------
// SF Symbols proxies — Lucide-style outlines. Each carries data-sf-symbol
// for the real SwiftUI implementation.
function Icon({ name, size = 16, stroke = 1.8, fill = false, ...rest }) {
  const map = {
    grid: <><rect x="3" y="3" width="7" height="7" rx="1"/><rect x="14" y="3" width="7" height="7" rx="1"/><rect x="3" y="14" width="7" height="7" rx="1"/><rect x="14" y="14" width="7" height="7" rx="1"/></>,
    apps: <><rect x="3" y="4" width="18" height="16" rx="2"/><path d="M3 10h18"/></>,
    history: <><path d="M3 12a9 9 0 1 0 3-6.7"/><path d="M3 4v5h5"/></>,
    network: <><path d="M5 12.5a9 9 0 0 1 14 0"/><path d="M8.5 16a4 4 0 0 1 7 0"/><circle cx="12" cy="19" r="1.2" fill="currentColor" stroke="none"/></>,
    gear: <><circle cx="12" cy="12" r="3"/><path d="M19.4 15a1.7 1.7 0 0 0 .3 1.8l.1.1a2 2 0 1 1-2.8 2.8l-.1-.1a1.7 1.7 0 0 0-1.8-.3 1.7 1.7 0 0 0-1 1.5V21a2 2 0 0 1-4 0v-.1a1.7 1.7 0 0 0-1-1.5 1.7 1.7 0 0 0-1.8.3l-.1.1a2 2 0 1 1-2.8-2.8l.1-.1a1.7 1.7 0 0 0 .3-1.8 1.7 1.7 0 0 0-1.5-1H3a2 2 0 0 1 0-4h.1a1.7 1.7 0 0 0 1.5-1 1.7 1.7 0 0 0-.3-1.8l-.1-.1a2 2 0 1 1 2.8-2.8l.1.1a1.7 1.7 0 0 0 1.8.3h.1a1.7 1.7 0 0 0 1-1.5V3a2 2 0 0 1 4 0v.1a1.7 1.7 0 0 0 1 1.5 1.7 1.7 0 0 0 1.8-.3l.1-.1a2 2 0 1 1 2.8 2.8l-.1.1a1.7 1.7 0 0 0-.3 1.8v.1a1.7 1.7 0 0 0 1.5 1H21a2 2 0 0 1 0 4h-.1a1.7 1.7 0 0 0-1.5 1z"/></>,
    expand: <><path d="M21 3h-5M21 3v5M21 3l-7 7M3 21h5M3 21v-5M3 21l7-7"/></>,
    cloud: <path d="M17.5 18.5a4 4 0 0 0 .5-7.95A6 6 0 0 0 6.7 11 4.5 4.5 0 0 0 7.5 19.95h10z" fill="currentColor"/>,
    download: <><circle cx="12" cy="12" r="10"/><path d="M12 7v8m0 0l-3-3m3 3l3-3" /></>,
    search: <><circle cx="11" cy="11" r="6"/><path d="M21 21l-4.3-4.3"/></>,
    chevron: <path d="M9 6l6 6-6 6"/>,
    chevronDown: <path d="M6 9l6 6 6-6"/>,
    wifi: <><path d="M5 12.5a9 9 0 0 1 14 0"/><path d="M8.5 16a4 4 0 0 1 7 0"/><circle cx="12" cy="19" r="1.2" fill="currentColor" stroke="none"/></>,
    battery: <><rect x="2" y="7" width="18" height="10" rx="2"/><rect x="4" y="9" width="11" height="6" rx="0.5" fill="currentColor" stroke="none"/><path d="M22 11v2"/></>,
    check: <path d="M5 12l5 5L20 7"/>,
    info: <><circle cx="12" cy="12" r="9"/><path d="M12 11v6"/><circle cx="12" cy="8" r="0.6" fill="currentColor"/></>,
    lock: <><rect x="5" y="11" width="14" height="9" rx="2"/><path d="M8 11V8a4 4 0 0 1 8 0v3"/></>,
    spotlight: <><circle cx="11" cy="11" r="6"/><path d="M21 21l-4.3-4.3"/></>,
    timeMachine: <><circle cx="12" cy="12" r="9"/><path d="M12 7v5l3 2"/></>,
  };
  return (
    <svg width={size} height={size} viewBox="0 0 24 24" fill={fill ? "currentColor" : "none"} stroke="currentColor" strokeWidth={stroke} strokeLinecap="round" strokeLinejoin="round" {...rest}>
      {map[name]}
    </svg>
  );
}

// -- App icon (placeholder; real Mac would pull from NSWorkspace) ----
const APP_PALETTE = {
  Chrome:   { bg: 'linear-gradient(135deg, #DB4437, #F4B400 60%, #0F9D58)', letter: 'C' },
  Slack:    { bg: '#4A154B', letter: '#' },
  Safari:   { bg: 'linear-gradient(135deg, #4FBFE8, #1A6AB4)', letter: 'S' },
  Discord:  { bg: '#5865F2', letter: 'D' },
  Spotify:  { bg: '#1ED760', letter: '♫' },
  Figma:    { bg: 'linear-gradient(135deg, #F24E1E, #A259FF)', letter: 'F' },
  VSCode:   { bg: '#0078D4', letter: '<' },
  Zoom:     { bg: '#2D8CFF', letter: 'Z' },
};
const CATEGORY_ICON = {
  iCloud:   { bg: '#2D86F0', node: <Icon name="cloud" size={18} fill stroke={0} /> },
  '軟體更新': { bg: '#3F8C4F', node: <Icon name="download" size={18} stroke={2} /> },
  'Spotlight 搜尋': { bg: '#5B7AB3', node: <Icon name="spotlight" size={16} stroke={2.4} /> },
  'Time Machine 備份': { bg: '#7F58B0', node: <Icon name="timeMachine" size={18} stroke={2} /> },
  '系統其他': { bg: '#6B6557', node: <Icon name="gear" size={16} stroke={2} /> },
};

function AppIcon({ name, size = 32 }) {
  const cat = CATEGORY_ICON[name];
  if (cat) {
    return (
      <div className="app-icon" style={{ background: cat.bg, width: size, height: size }} data-app-icon={name}>
        {cat.node}
      </div>
    );
  }
  const p = APP_PALETTE[name] || { bg: '#8E8779', letter: name?.[0] || '?' };
  return (
    <div className="app-icon" style={{ background: p.bg, width: size, height: size, fontSize: size * 0.42 }} data-app-icon={name}>
      {p.letter}
    </div>
  );
}

// Mock data — drawn from PRD §7 examples
const MOCK_APPS = [
  { name: 'Chrome',           gb: 4.23, pct: 34, sub: '瀏覽器 · 主要流量來源' },
  { name: 'iCloud',           gb: 2.10, pct: 17, sub: '含 同步、照片、備份' },
  { name: 'Slack',            gb: 1.09, pct:  9, sub: '訊息、檔案' },
  { name: 'Spotify',          gb: 0.92, pct:  7, sub: '串流音樂' },
  { name: 'Figma',            gb: 0.81, pct:  7, sub: '設計檔同步' },
  { name: '軟體更新',          gb: 0.65, pct:  5, sub: '系統 · 不能關，但可以了解' },
  { name: 'Zoom',             gb: 0.58, pct:  5, sub: '視訊通話' },
  { name: 'Safari',           gb: 0.47, pct:  4, sub: '另一個瀏覽器' },
  { name: 'Spotlight 搜尋',   gb: 0.28, pct:  2, sub: '系統索引' },
  { name: '系統其他',         gb: 0.31, pct:  2, sub: 'mDNSResponder 等' },
];
const TOTAL_GB = 12.44;
const CAP_GB   = 20;

Object.assign(window, { Icon, AppIcon, MOCK_APPS, TOTAL_GB, CAP_GB });
