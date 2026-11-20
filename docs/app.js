'use strict';
(async()=>{
  try{
    const r=await fetch('distribution.json',{cache:'no-store',credentials:'omit',signal:AbortSignal.timeout(8000)});
    if(!r.ok)return;
    const distribution=await r.json();
    if(distribution.ready===true&&typeof distribution.manifest==='string'&&new URL(distribution.manifest).protocol==='https:'){
      const status=document.getElementById('availability');if(status)status.textContent='Open the installer from your Home Screen to continue.';
      const action=document.getElementById('native-install');
      if(action){action.href='itms-services://?action=download-manifest&url='+encodeURIComponent(distribution.manifest);action.removeAttribute('aria-disabled');action.textContent='Install iPAStore';}
    }
  }catch{}
})();
