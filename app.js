'use strict';
const tabs = [...document.querySelectorAll('[role="tab"]')];
function activate(tab, focus=false) {
  for (const candidate of tabs) {
    const selected = candidate === tab;
    candidate.setAttribute('aria-selected', String(selected));
    candidate.tabIndex = selected ? 0 : -1;
    document.getElementById(candidate.getAttribute('aria-controls')).hidden = !selected;
  }
  if (focus) tab.focus();
}
for (const tab of tabs) {
  tab.addEventListener('click', () => activate(tab));
  tab.addEventListener('keydown', event => {
    const index=tabs.indexOf(tab);
    if (event.key==='ArrowRight'||event.key==='ArrowLeft') {
      event.preventDefault(); activate(tabs[(index+1)%tabs.length],true);
    } else if(event.key==='Home'||event.key==='End') {
      event.preventDefault(); activate(tabs[event.key==='Home'?0:tabs.length-1],true);
    }
  });
}
(async()=>{
  const status=document.getElementById('release-status');
  try {
    const response=await fetch('https://api.github.com/repos/maximus8889/iPASTORE/releases/latest', {credentials:'omit', signal:AbortSignal.timeout(10000)});
    if(!response.ok) throw new Error('No published release');
    const release=await response.json();
    const ipa=release.assets?.find(asset=>asset.name==='iPASTORE.ipa');
    if(!ipa || !ipa.browser_download_url?.startsWith('https://github.com/maximus8889/')) throw new Error('No IPA');
    for(const link of document.querySelectorAll('.ipa-download'))link.href=ipa.browser_download_url;
    document.getElementById('setup-link').href='sideinstaller://install?url='+encodeURIComponent(ipa.browser_download_url);
    document.getElementById('feather-link').href='feather://install/'+ipa.browser_download_url;
    document.getElementById('version').textContent=String(release.tag_name).slice(0,40)+' · iOS 17.5+';
    status.textContent='Latest release · '+new Date(release.published_at).toLocaleDateString(undefined,{year:'numeric',month:'short',day:'numeric'});
  } catch {
    status.textContent='No public IPA release is available yet. Setup instructions remain available above.';
    for(const link of document.querySelectorAll('.ipa-download,#setup-link,#feather-link')){
      link.setAttribute('aria-disabled','true');
      link.addEventListener('click',e=>{e.preventDefault();status.textContent='The iPAStore IPA has not been published yet. Check back after the first release.';});
    }
  }
})();
