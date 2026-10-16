const fs=require('fs'),vm=require('vm'),assert=require('assert');
const html=fs.readFileSync(require('path').join(__dirname,'..','index.html'),'utf8');
const lines=html.split('\n');
assert(html.includes('restRefreshTimer=setInterval(()=>checkServerRevision(true),2000)'),'automatic full snapshot check every two seconds');
let now=10000,reads=0,renders=0,server={revision:2,state:{name:'peer edit'}};
const ctx={document:{hidden:false,addEventListener(){}},Date:{now:()=>now},Promise,JSON,Number,console,
 db:null,restRefreshTimer:null,syncEventsInstalled:false,window:{addEventListener(){}},setInterval(fn,ms){ctx.intervalCallback=fn;ctx.intervalPeriod=ms;return 1},clearInterval(){},upgradeRealtimeConnection(){},flushPendingWarehouseActions(){},snapshotRequest:null,revisionProbe:null,lastFullSnapshotAt:0,lastRevisionCheckAt:0,lastMarketDirectoryAt:0,
 serverNoticeVersion:0,serverUpdatePending:false,serverUpdateTimer:null,directoryUpdatePending:false,marketDirectoryRequest:null,lastRenderedSnapshotSignature:'',clearTimeout(){},setTimeout(){return 1},serverSnapshotLoaded:true,realtimeHealthy:true,revision:1,state:{name:'old'},syncMutationVersion:0,
 localSaveCount:0,customMarketSaving:false,supplySaveBusy:false,driverDrag:false,serverConnectionProblem:false,
 remoteReadClient:()=>({from:()=>({select:()=>({eq:()=>({single:async()=>{reads++;return {data:server}}})})})}),
 normalizeState:x=>x,replayPendingWarehouseActions:x=>x,refreshPendingNotice(){},t:x=>x,
 connectionError:()=>assert.fail('unexpected connection error'),loadAllMarkets:async()=>{},
 applyServerSnapshot(data){ctx.state=data.state;ctx.revision=data.revision;ctx.lastRenderedSnapshotSignature=JSON.stringify(ctx.state);renders++;return true}};
vm.createContext(ctx);vm.runInContext(['function loadSnapshot(','function checkServerRevision(','function startDatabaseUpdates('].map(p=>lines.find(l=>l.startsWith(p))).join('\n'),ctx);
(async()=>{
 await ctx.checkServerRevision();assert.equal(ctx.state.name,'peer edit');assert.equal(renders,1);
 now+=2001;await ctx.checkServerRevision();assert.equal(renders,2,'each timer refresh repaints just like the manual Refresh button');
 server={revision:2,state:{name:'same revision peer edit'}};now+=2001;
 await ctx.checkServerRevision();assert.equal(ctx.state.name,'same revision peer edit','heartbeat recovers even without a revision change or live event');
 ctx.localSaveCount=1;server={revision:3,state:{name:'later'}};now+=2001;const before=reads;
 await ctx.checkServerRevision();assert.equal(reads,before,'active writes are protected');
 ctx.localSaveCount=0;await ctx.checkServerRevision();assert.equal(ctx.state.name,'later','next tick retries after busy period');
 server={revision:4,state:{name:'live missed'}};now+=1000;await ctx.checkServerRevision();assert.equal(ctx.state.name,'live missed','healthy live channel cannot suppress fallback polling');
 ctx.startDatabaseUpdates();assert.equal(ctx.intervalPeriod,2000);ctx.document.hidden=true;server={revision:5,state:{name:'hidden tab update'}};await ctx.intervalCallback();assert.equal(ctx.state.name,'hidden tab update','hidden browser tabs must not be skipped by app code');
 console.log('PASS automatic/manual-equivalent repaint, peer updates, equal revision recovery, busy retry, live-channel fallback and hidden-tab refresh');
})().catch(e=>{console.error(e);process.exitCode=1});
