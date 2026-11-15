import {createService} from '../../nasa-context-worker/src/index.js';
import {createCoach,json,MODEL} from './coach.js';
import {PAGE,STYLE,APP} from './ui.js';
let solar,coach;
const security={'X-Content-Type-Options':'nosniff','Referrer-Policy':'no-referrer','Content-Security-Policy':"default-src 'self'; script-src 'self'; style-src 'self'; img-src 'self' blob:; connect-src 'self'; frame-ancestors 'none'; base-uri 'none'; form-action 'none'",'Permissions-Policy':'camera=(), microphone=(), geolocation=()'};
export default {async fetch(request,env){
 const path=new URL(request.url).pathname;
 if(path==='/api/coach'){
  coach??=createCoach({cache:caches.default});
  return coach(request,env);
 }
 if(!['GET','HEAD'].includes(request.method))return json({error:'Method not allowed'},405);
 if(path.startsWith('/v1/solar/')){solar??=createService({cache:caches.default});return solar.fetch(request);}
 if(path==='/api/status')return json({service:'KŌMAKU Mission Science Lab',gemini_configured:!!env.GEMINI_API_KEY,request_protection_configured:!!env.COACH_LIMITER,model:MODEL,scope:'Companion demo; does not alter game physics. Credential presence is not a successful generation test.'});
 const assets={'/':[PAGE,'text/html; charset=utf-8'],'/style.css':[STYLE,'text/css'],'/app.js':[APP,'text/javascript']};
 if(!Object.hasOwn(assets,path))return json({error:'Not found'},404);
 const [body,type]=assets[path];return new Response(request.method==='HEAD'?null:body,{headers:{...security,'Content-Type':type,'Cache-Control':'public, max-age=60'}});
}};
