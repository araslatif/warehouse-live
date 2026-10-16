const fs=require('fs'),vm=require('vm'),assert=require('assert'),path=require('path');
const root=path.join(__dirname,'..'),html=fs.readFileSync(path.join(root,'index.html'),'utf8');
let server={revision:10,state:{value:'first'}},resolver=null,reads=0;
const timers=[],handlers={},channel={on(type,filter,fn){handlers[type+':'+(filter.event||'')]=fn;return this},subscribe(fn){this.status=fn;return this},track:async()=>{},presenceState:()=>({})};
const ctx={console,Promise,JSON,Number,Date,document:{hidden:false},db:{channel:()=>channel,removeChannel(){}},liveChannel:null,presenceKey:'test',realtimeHealthy:false,connectedDevices:[],clients:0,updateLive(){},myPresencePayload:()=>({}),t:x=>x,connectionError:()=>assert.fail('unexpected error'),
 snapshotRequest:null,revisionProbe:null,localSaveCount:0,customMarketSaving:false,supplySaveBusy:false,driverDrag:null,syncMutationVersion:0,
 serverNoticeVersion:0,serverUpdatePending:false,serverUpdateTimer:null,directoryUpdatePending:false,marketDirectoryRequest:null,lastRenderedSnapshotSignature:'',lastMarketDirectoryAt:0,lastFullSnapshotAt:0,lastRevisionCheckAt:0,serverSnapshotLoaded:true,revision:10,state:{value:'first'},
 setTimeout(fn){timers.push(fn);return timers.length},clearTimeout(){},remoteReadClient:()=>({from:()=>({select:()=>({eq:()=>({single:async()=>{reads++;if(resolver===true)return new Promise(resolve=>{resolver=resolve});return {data:server}}})})})}),normalizeState:x=>JSON.parse(JSON.stringify(x)),replayPendingWarehouseActions:x=>x,refreshPendingNotice(){},loadAllMarkets:async()=>{ctx.directoryReads=(ctx.directoryReads||0)+1},applyServerSnapshot(data){ctx.state=data.state;ctx.revision=data.revision;ctx.lastRenderedSnapshotSignature=JSON.stringify(data.state);return true}};
vm.createContext(ctx);vm.runInContext(['function requestServerUpdate(','function connectLive(','function loadSnapshot(','function checkServerRevision('].map(p=>html.split('\n').find(l=>l.startsWith(p))).join('\n'),ctx);
const settle=async()=>{await new Promise(r=>setImmediate(r));if(ctx.revisionProbe)await ctx.revisionProbe;await new Promise(r=>setImmediate(r))};
(async()=>{
 ctx.connectLive();assert(handlers['broadcast:state-changed']);
 server={revision:11,state:{value:'peer committed'}};
 handlers['broadcast:state-changed']({payload:{revision:11}});await settle();assert.equal(ctx.state.value,'peer committed');
 // Database edits can have the same revision; a notification still forces a read.
 server={revision:11,state:{value:'same revision'}};handlers['broadcast:state-changed']({payload:{revision:11}});await settle();assert.equal(ctx.state.value,'same revision');
 ctx.localSaveCount=1;const n=reads;server={revision:12,state:{value:'while saving'}};handlers['postgres_changes:*']({new:server});await settle();assert.equal(reads,n);assert(ctx.serverUpdatePending);
 ctx.localSaveCount=0;await ctx.checkServerRevision(true);assert.equal(ctx.state.value,'while saving');assert(!ctx.serverUpdatePending);
 // A notification arriving during a read must not be acknowledged by that older read.
 resolver=true;ctx.requestServerUpdate();await new Promise(r=>setImmediate(r));const finish=resolver;
 ctx.requestServerUpdate();finish({data:{revision:12,state:{value:'older in-flight'}}});resolver=null;await settle();assert(ctx.serverUpdatePending);
 server={revision:13,state:{value:'newest'}};await ctx.checkServerRevision(true);assert.equal(ctx.state.value,'newest');assert(!ctx.serverUpdatePending);
 const beforeDirectory=ctx.directoryReads||0;handlers['broadcast:directory-changed']({payload:{table:'markets'}});await settle();assert.equal(ctx.directoryReads,beforeDirectory+1);
 assert(html.includes('./vendor/supabase-2.118.0.js'));assert(fs.existsSync(path.join(root,'public/vendor/supabase-2.118.0.js')));
 const sql=fs.readFileSync(path.join(root,'ENABLE_SERVER_PUSH_V70.sql'),'utf8');assert(sql.includes("'state-changed','warehouse-live',false"));assert(!sql.includes('save_warehouse_state('));
 console.log('PASS actual receive handlers: immediate broadcast/CDC reads, same-revision hints, busy retry, notification during in-flight read, directory events and bundled SDK; SQL leaves save RPCs unchanged');
})().catch(e=>{console.error(e);process.exitCode=1});
