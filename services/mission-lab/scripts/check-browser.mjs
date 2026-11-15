import {chromium} from '@playwright/test';
const browser=await chromium.launch({headless:true,executablePath:process.env.CHROMIUM_PATH||'/usr/bin/chromium'});
try{
 const page=await browser.newPage({viewport:{width:1280,height:1000}}),errors=[];
 page.on('pageerror',e=>errors.push(e.message));
 await page.goto(process.env.MISSION_LAB_TEST_URL||'http://127.0.0.1:8788');
 await page.getByRole('button',{name:'Explain this'}).click();
 await page.getByText('Built-in guide · Gemini unavailable',{exact:true}).waitFor();
 await page.locator('#explanation').filter({hasText:'Dust'}).waitFor();
 await page.screenshot({path:'services/mission-lab/evidence/coach-live.png',fullPage:true});
 await page.getByRole('button',{name:'ϟ Energy',exact:true}).click();
 await page.getByRole('heading',{name:'Power is a rate. Energy is stored.'}).waitFor();
 await page.getByRole('button',{name:'◷ Radiation',exact:true}).click();
 await page.getByRole('heading',{name:'Exposure adds up with time.'}).waitFor();
 await page.waitForFunction(()=>!document.querySelector('#refresh').disabled,{timeout:30000});
 console.log('NASA UI status:',await page.locator('#solar-status').innerText());
 await page.screenshot({path:'services/mission-lab/evidence/desktop.png',fullPage:true});
 await page.setViewportSize({width:390,height:844});
 if(await page.evaluate(()=>document.documentElement.scrollWidth>innerWidth))throw Error('Horizontal overflow');
 await page.screenshot({path:'services/mission-lab/evidence/mobile.png',fullPage:true});
 if(errors.length)throw Error(errors.join('\n'));
 console.log('Browser checks passed: topic navigation, missing-key fallback, desktop/mobile layout, no JS errors.');
}finally{await browser.close()}
