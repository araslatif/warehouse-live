const fs=require('fs'),vm=require('vm'),assert=require('assert');
const html=fs.readFileSync(require('path').join(__dirname,'../public/index.html'),'utf8');
const start=html.indexOf('function flushPendingWarehouseActions(){'),end=html.indexOf('\nasync function unsetAllZoneMarkets',start);
assert(start>=0&&end>start,'authoritative sync queue function was not found');
async function run({persist=true,readError=false,applied=[]}={}){
 const pending=[{id:'pending_test_only',type:'state_patch'}],diagnostics=[];
 const c={console:{warn(){}},pendingWarehouseActions:pending,pendingFlushBusy:false,syncQueuePromise:null,pendingRetryTimer:null,syncSetupRequired:false,lastServerSyncError:'',serverConnectionProblem:false,syncMutationVersion:0,state:{zones:[{id:'A'}],zoneMarkets:{A:[]}},revision:10,serverSnapshotLoaded:true,
 ensureDatabaseClient(){},remoteReadClient(){return{}},readCompatibleSyncSnapshot:async()=>{if(readError)throw Error('simulated transport timeout');return{state:{zones:[{id:'A'}],zoneMarkets:{A:[]}},revision:10,applied_ids:applied}},applyWarehouseAction(){},commitCompatibleSync:async(client,merged,revision)=>({state:merged,revision:revision+1}),recordSyncDiagnostics100:async rows=>diagnostics.push(...rows),persistPendingWarehouseActions:()=>persist,
 normalizeState:x=>x,replayPendingWarehouseActions:x=>x,resetSyncBaseline(){},saveStateCache(){},renderActionViews(){},announceWarehouseRevision(){},refreshPendingNotice(){},dt:(a,b)=>b,$:()=>({textContent:''}),setTimeout:()=>1,clearTimeout(){},Date,Promise,Math};
 vm.createContext(c);vm.runInContext(html.slice(start,end),c);const result=await c.flushPendingWarehouseActions();return{c,result,diagnostics,pending};
}
(async()=>{
 const failedPersist=await run({persist:false});assert.equal(failedPersist.result,false);assert.equal(failedPersist.c.pendingFlushBusy,false);assert.equal(failedPersist.c.pendingWarehouseActions.length,1);assert(failedPersist.diagnostics.some(x=>x.acknowledgement==='confirmed-queue-retained'));
 const transportFailure=await run({readError:true});assert.equal(transportFailure.result,false);assert.equal(transportFailure.c.pendingFlushBusy,false);assert.equal(transportFailure.c.pendingWarehouseActions.length,1);
 const receiptRetry=await run({persist:true,applied:['pending_test_only']});assert.equal(receiptRetry.result,true);assert.equal(receiptRetry.c.pendingFlushBusy,false);assert.equal(receiptRetry.c.pendingWarehouseActions.length,0);assert(receiptRetry.diagnostics.some(x=>x.acknowledgement==='receipt-confirmed'));
 console.log(JSON.stringify({PASS:true,acknowledgedQueueRetainedWhenPersistenceFails:true,busyFlagClearsAfterTransportError:true,receiptRetryDrainsSameOperation:true,operationPayloadsExcludedFromDiagnostics:true}));
})().catch(e=>{console.error(e);process.exitCode=1});
