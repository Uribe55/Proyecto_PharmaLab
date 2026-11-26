"use strict";
const {test,beforeEach,afterEach}=require('node:test');
const assert=require('node:assert/strict');
const fs=require('node:fs');
const path=require('node:path');
const {initializeTestEnvironment,assertSucceeds,assertFails}=require('@firebase/rules-unit-testing');
const {doc,collection,getDoc,getDocs,writeBatch,runTransaction,serverTimestamp,Timestamp,onSnapshot,query,where}=require('firebase/firestore');
const {createMockUserToken}=require('@firebase/util');
const projectId='demo-pharmalab-spark-regression';
assert.match(process.env.FIRESTORE_EMULATOR_HOST||'',/^127\.0\.0\.1:(8080|8085)$/);
const [host,port]=process.env.FIRESTORE_EMULATOR_HOST.split(':');
const fixture=JSON.parse(fs.readFileSync(path.join(__dirname,'fixtures/spark-farm004.json'),'utf8').replace(/^\uFEFF/,''));
const local=fs.readFileSync(path.join(__dirname,'../../firestore.rules'),'utf8');
const published=fs.readFileSync(path.join(__dirname,'fixtures/firestore.before-numbering.rules'),'utf8');
const base=`http://${host}:${port}/v1/projects/${projectId}/databases/(default)/documents`;
let env;
async function rules(source){const previous=env;env=await initializeTestEnvironment({projectId,firestore:{host,port:Number(port),rules:source}});if(previous)await previous.cleanup();}
async function rawCommit(writes, token='owner'){
 const response=await fetch(`${base}:commit`,{method:'POST',headers:{'Content-Type':'application/json',Authorization:`Bearer ${token}`},body:JSON.stringify({writes})});
 if(!response.ok)throw Error(`REST ${response.status}: ${(await response.text()).slice(0,400)}`);
 return response.json();
}
function fullName(p){return `projects/${projectId}/databases/(default)/documents/${p}`;}
beforeEach(async()=>{
 await rules(local);await env.clearFirestore();
 // REST tipado conserva doubleValue:150, que el SDK JavaScript convertiría a int.
 await rawCommit(Object.entries(fixture.Documents).map(([p,fields])=>({update:{name:fullName(p),fields}})));
 await env.withSecurityRulesDisabled(async context=>{
  const db=context.firestore(),batch=writeBatch(db);
  for(const [p,data] of Object.entries({
   'configuracion/contadores_pedidos':{ultimo_numero:2,ultimo_id:'PED002',ultimo_documento_id:'existingOrder'},
   'configuracion/contadores_direcciones':{ultimo_numero:2,ultimo_id:'DIR002',ultimo_documento_id:fixture.AddressId},
   'usuarios/other':{rol:'cliente',estado:true},'usuarios/seller':{rol:'vendedor',estado:true},
   'usuarios/inactive':{rol:'cliente',estado:false},'usuarios/admin':{rol:'administrador',estado:true},
   'farmacia_cliente/FARM003':{usuario_id:'other',estado:true},
   'direcciones/OTHERADDRESS':{id_cliente:'FARM003',estado:true},
   'lotes_productos/EXPIRED':{producto_id:'PROD001',cantidad_disponible:100,fecha_vencimiento:Timestamp.fromDate(new Date('2000-01-01'))},
   'configuracion/contadores_farmacia':{ultimo_numero:4,ultimo_id:'FARM004',ultimo_uid:'client'},
   'nits_farmacia/123456789':{usuario_id:'client',farmacia_id:'FARM004'},
   'pedidos/PED001':{estado:'aprobado',id_cliente:'FARM004',id_direccion:fixture.AddressId,total:385,fecha_pedido:Timestamp.fromDate(new Date('2026-01-01'))},
   'pedidos/PED001/detalle_pedido/DET001':{id_producto:'PROD001',cantidad:2,precio_unitario:150,subtotal:300},
   'pedidos/PED001/detalle_pedido/DET002':{id_producto:'PROD002',cantidad:1,precio_unitario:85,subtotal:85}
  }))batch.set(doc(db,p),data);await batch.commit();
 });
});
afterEach(async()=>{await env.cleanup();env=null;});
function client(uid='client'){return env.authenticatedContext(uid,{email:`${uid}@test.invalid`}).firestore();}
function payload(db,{id=doc(collection(db,'pedidos')).id,quantity=1,price=150,farm='FARM004',address=fixture.AddressId,lot='LOTE001',stock=100,number=3,uid='client'}={}){
 const line={id_producto:'PROD001',id_lote:lot,cantidad:quantity,precio_unitario:price,subtotal:price*quantity};
 return {id,writes:[
  {p:`pedidos/${id}`,data:{schema_version:'spark_single_v2',estado:'pendiente',fecha_pedido:serverTimestamp(),id_cliente:farm,id_direccion:address,total:price*quantity,usuario_id:uid,id_operacion:id,numero_comercial:'PED'+String(number).padStart(3,'0'),linea:line,observaciones:''}},
  {p:`pedidos/${id}/detalle_pedido/DET001`,data:{...line}},
  {p:`pedidos/${id}/historial_estado/CONFIRMACION`,data:{estado_anterior:null,estado_nuevo:'pendiente',fecha_cambio:serverTimestamp(),id_usuario:uid}},
  {p:`usuarios/${uid}/operaciones_pedido/${id}`,data:{pedido_id:id,id_cliente:farm,id_direccion:address,linea:{...line},observaciones:'',fecha:serverTimestamp()}},
  {p:`lotes_productos/${lot}`,update:true,data:{cantidad_disponible:stock-quantity,ultimo_pedido_id:id}}
,{p:'configuracion/contadores_pedidos',update:true,data:{ultimo_numero:number,ultimo_id:'PED'+String(number).padStart(3,'0'),ultimo_documento_id:id}}
 ]};
}
function commit(db,data){const batch=writeBatch(db);for(const w of data.writes){if(w.update)batch.update(doc(db,w.p),w.data);else batch.set(doc(db,w.p),w.data);}return batch.commit();}
async function confirm(db,options={},trace={}){
 const data=payload(db,options);trace.stage='counter-read';
 return numberedRun(db,'configuracion/contadores_pedidos',async tx=>{
  trace.stage='operation-read';const op=await tx.get(doc(db,data.writes[3].p));
  trace.stage='order-read';const existing=await tx.get(doc(db,data.writes[0].p));
  if(op.exists()&&existing.exists())return data.id;
  for(const p of [`usuarios/${data.writes[0].data.usuario_id}`,`farmacia_cliente/${data.writes[0].data.id_cliente}`,`direcciones/${data.writes[0].data.id_direccion}`,'productos/PROD001']){trace.stage=`read:${p}`;await tx.get(doc(db,p));}
  const lot=await tx.get(doc(db,'lotes_productos/LOTE001'));
  if(lot.data().cantidad_disponible<(options.quantity??1))throw Error('stock-insuficiente');
  data.writes[4].data.cantidad_disponible=lot.data().cantidad_disponible-(options.quantity??1);
  const counter=await tx.get(doc(db,'configuracion/contadores_pedidos'));
  data.writes[5].data.ultimo_numero=counter.data().ultimo_numero+1;data.writes[5].data.ultimo_id='PED'+String(counter.data().ultimo_numero+1).padStart(3,'0');data.writes[0].data.numero_comercial=data.writes[5].data.ultimo_id;
  trace.stage='commit';for(const w of data.writes){if(w.update)tx.update(doc(db,w.p),w.data);else tx.set(doc(db,w.p),w.data);}return data.id;
 });
}
test('REGRESION: reglas v1 publicadas rechazan contador; v2 permiten numeración',async()=>{
 await rules(published);const old=client(),trace={};
 await assert.rejects(confirm(old,{},trace),error=>error.code==='permission-denied');assert.equal(trace.stage,'counter-read');
 await rules(local);const db=client(),id=await assertSucceeds(confirm(db));
 assert.equal((await getDoc(doc(db,`pedidos/${id}`))).data().estado,'pendiente');
 assert.equal((await getDoc(doc(db,'lotes_productos/LOTE001'))).data().cantidad_disponible,99);
});
test('lectura del ID ausente y registro idempotente no son escrituras',async()=>{
 const db=client(),id=doc(collection(db,'pedidos')).id;
 assert.equal((await assertSucceeds(getDoc(doc(db,`pedidos/${id}`)))).exists(),false);
 assert.equal((await assertSucceeds(getDoc(doc(db,`usuarios/client/operaciones_pedido/${id}`)))).exists(),false);
});
test('seis escrituras con doubles nativos y REQUEST_TIME como Flutter',async()=>{
 const db=client(),id=doc(collection(db,'pedidos')).id;
 const s=v=>({stringValue:v}),i=v=>({integerValue:String(v)}),d=v=>({doubleValue:v});
 const line={id_producto:s('PROD001'),id_lote:s('LOTE001'),cantidad:i(1),precio_unitario:d(150),subtotal:d(150)};
 const map=fields=>({mapValue:{fields}});
 const writes=[
  {update:{name:fullName(`pedidos/${id}`),fields:{schema_version:s('spark_single_v2'),estado:s('pendiente'),id_cliente:s('FARM004'),id_direccion:s(fixture.AddressId),total:d(150),usuario_id:s('client'),id_operacion:s(id),numero_comercial:s('PED003'),linea:map(line),observaciones:s('')}},updateTransforms:[{fieldPath:'fecha_pedido',setToServerValue:'REQUEST_TIME'}]},
  {update:{name:fullName(`pedidos/${id}/detalle_pedido/DET001`),fields:line}},
  {update:{name:fullName(`pedidos/${id}/historial_estado/CONFIRMACION`),fields:{estado_anterior:{nullValue:null},estado_nuevo:s('pendiente'),id_usuario:s('client')}},updateTransforms:[{fieldPath:'fecha_cambio',setToServerValue:'REQUEST_TIME'}]},
  {update:{name:fullName(`usuarios/client/operaciones_pedido/${id}`),fields:{pedido_id:s(id),id_cliente:s('FARM004'),id_direccion:s(fixture.AddressId),linea:map(line),observaciones:s('')}},updateTransforms:[{fieldPath:'fecha',setToServerValue:'REQUEST_TIME'}]},
  {update:{name:fullName('configuracion/contadores_pedidos'),fields:{ultimo_numero:i(3),ultimo_id:s('PED003'),ultimo_documento_id:s(id)}},updateMask:{fieldPaths:['ultimo_numero','ultimo_id','ultimo_documento_id']}},
  {update:{name:fullName('lotes_productos/LOTE001'),fields:{cantidad_disponible:i(99),ultimo_pedido_id:s(id)}},updateMask:{fieldPaths:['cantidad_disponible','ultimo_pedido_id']}}
 ];
 await rawCommit(writes,createMockUserToken({sub:'client'},projectId));
 assert.equal((await getDoc(doc(db,`pedidos/${id}`))).data().total,150);
});
for(let missing=0;missing<6;missing++)test(`atomicidad: falta escritura ${missing}`,async()=>{const db=client(),data=payload(db);data.writes.splice(missing,1);await assertFails(commit(db,data));});
for(const options of [{price:1},{quantity:0},{quantity:-1},{quantity:1.5},{quantity:101},{farm:'FARM003'},{address:'OTHERADDRESS'},{lot:'EXPIRED'}])test(`rechazo ${JSON.stringify(options)}`,async()=>{const db=client();await assertFails(commit(db,payload(db,options)));});
test('cliente inactivo rechazado',async()=>{const db=client('inactive');await assertFails(commit(db,payload(db)));});
test('descuento aislado o stock negativo rechazados',async()=>{const db=client();await assertFails(commit(db,{writes:[{p:'lotes_productos/LOTE001',update:true,data:{cantidad_disponible:99}}]}));const data=payload(db);data.writes[4].data.cantidad_disponible=-1;await assertFails(commit(db,data));});
test('detalle e historial manipulados rechazados',async()=>{const db=client();for(const index of [1,2]){const data=payload(db);data.writes[index].data.extra=true;await assertFails(commit(db,data));}});
test('reintento no duplica pedido ni descuento',async()=>{const db=client(),id=doc(collection(db,'pedidos')).id;await confirm(db,{id});await confirm(db,{id});assert.equal((await getDoc(doc(db,'lotes_productos/LOTE001'))).data().cantidad_disponible,99);});
test('concurrencia sin sobreventa',async()=>{const db=client();const results=await Promise.allSettled([confirm(db,{quantity:60}),confirm(db,{quantity:60})]);assert.equal(results.filter(r=>r.status==='fulfilled').length,1);assert.equal((await getDoc(doc(db,'lotes_productos/LOTE001'))).data().cantidad_disponible,40);});
function approve(db,id,uid='seller',extra={}){const batch=writeBatch(db);batch.update(doc(db,`pedidos/${id}`),{estado:'aprobado',aprobado_por:uid,fecha_aprobacion:serverTimestamp(),...extra});batch.set(doc(db,`pedidos/${id}/historial_estado/APROBACION`),{estado_anterior:'pendiente',estado_nuevo:'aprobado',fecha_cambio:serverTimestamp(),id_usuario:uid});return batch.commit();}
test('vendedor recibe snapshots y aprobación actualiza cliente sin nuevo descuento',async()=>{
 const db=client(),seller=client('seller');let id;
 const pending=new Promise((resolve,reject)=>{const unsub=onSnapshot(query(collection(seller,'pedidos'),where('estado','==','pendiente')),snapshot=>{if(snapshot.size){id=snapshot.docs[0].id;unsub();resolve();}},reject);});
 await confirm(db);await pending;
 const approved=new Promise((resolve,reject)=>{const unsub=onSnapshot(doc(db,`pedidos/${id}`),snapshot=>{if(snapshot.data()?.estado==='aprobado'){unsub();resolve();}},reject);});
 await assertSucceeds(approve(seller,id));await approved;
 assert.equal((await getDoc(doc(db,'lotes_productos/LOTE001'))).data().cantidad_disponible,99);
 await assertFails(approve(seller,id));
});
test('cliente no aprueba, vendedor no altera total ni omite historial',async()=>{const db=client(),id=await confirm(db),seller=client('seller');await assertFails(approve(db,id,'client'));await assertFails(approve(seller,id,'seller',{total:1}));await assertFails(commit(seller,{writes:[{p:`pedidos/${id}`,update:true,data:{estado:'aprobado',aprobado_por:'seller',fecha_aprobacion:serverTimestamp()}}]}));});
test('PED001 permanece aprobado con total histórico y dos detalles',async()=>{const db=client();await assertFails(approve(client('seller'),'PED001'));assert.equal((await getDoc(doc(db,'pedidos/PED001'))).data().total,385);assert.equal((await getDocs(collection(db,'pedidos/PED001/detalle_pedido'))).size,2);});
function register(db,uid,nit='987654321',number=5){const farm=`FARM00${number}`,batch=writeBatch(db);batch.set(doc(db,`usuarios/${uid}`),{correo:`${uid}@test.invalid`,nombre:'Prueba',rol:'cliente',estado:true,fecha_registro:serverTimestamp()});batch.set(doc(db,`farmacia_cliente/${farm}`),{usuario_id:uid,nombre_farmacia:'Prueba',nit,responsable:'Prueba',telefono:'70000000',direccion_fiscal:'Prueba',estado:true,fecha_registro:serverTimestamp()});batch.set(doc(db,`nits_farmacia/${nit}`),{usuario_id:uid,farmacia_id:farm});batch.update(doc(db,'configuracion/contadores_farmacia'),{ultimo_numero:number,ultimo_id:farm,ultimo_uid:uid});return batch.commit();}
test('registro transaccional de farmacia y NIT único sin regresiones',async()=>{await assertSucceeds(register(client('new'),'new'));await assertFails(register(client('new2'),'new2','987654321',6));});

test('dos clientes concurrentes reciben PED003 y PED004 sin duplicar stock',async()=>{
 const a=client(),b=client('other');
 const ids=await Promise.all([confirm(a),confirm(b,{uid:'other',farm:'FARM003',address:'OTHERADDRESS'})]);
 const numbers=await Promise.all([getDoc(doc(a,`pedidos/${ids[0]}`)),getDoc(doc(b,`pedidos/${ids[1]}`))]);
 assert.deepEqual(numbers.map(d=>d.data().numero_comercial).sort(),['PED003','PED004']);
 assert.equal((await getDoc(doc(a,'lotes_productos/LOTE001'))).data().cantidad_disponible,98);
 assert.equal((await getDoc(doc(a,'configuracion/contadores_pedidos'))).data().ultimo_numero,4);
});
for(const mode of ['solo','salto','reuso','referencia','codigo','tipo','extra','v1','LINEA1'])test(`contador pedido rechaza ${mode}`,async()=>{
 const db=client(),data=payload(db);
 if(mode==='solo')data.writes=[data.writes[5]];
 if(mode==='salto') {data.writes[5].data.ultimo_numero=4;data.writes[5].data.ultimo_id='PED004';data.writes[0].data.numero_comercial='PED004';}
 if(mode==='reuso') {data.writes[5].data.ultimo_numero=2;data.writes[5].data.ultimo_id='PED002';data.writes[0].data.numero_comercial='PED002';}
 if(mode==='referencia')data.writes[5].data.ultimo_documento_id='ZZZZZZZZZZZZZZZZZZZZ';
 if(mode==='codigo')data.writes[0].data.numero_comercial='PED999';
 if(mode==='tipo')data.writes[5].data.ultimo_numero='3';
 if(mode==='extra')data.writes[5].data.extra=true;
 if(mode==='v1')data.writes[0].data.schema_version='spark_single_v1';
 if(mode==='LINEA1')data.writes[1].p=data.writes[1].p.replace('DET001','LINEA1');
 await assertFails(commit(db,data));
});
function addressPayload(db,{id=doc(collection(db,'direcciones')).id,number=3,farm='FARM004'}={}) {
 const code='DIR'+String(number).padStart(3,'0');
 return {id,writes:[{p:`direcciones/${id}`,data:{id_cliente:farm,nombre:'Casa',direccion:'Av de prueba',referencia:'',latitud:null,longitud:null,estado:true,numero_comercial:code}},
 {p:'configuracion/contadores_direcciones',update:true,data:{ultimo_numero:number,ultimo_id:code,ultimo_documento_id:id}}]};
}
async function addAddress(db,farm='FARM004') {
 const data=addressPayload(db,{farm});
 return numberedRun(db,'configuracion/contadores_direcciones',async tx=>{
  const counter=await tx.get(doc(db,'configuracion/contadores_direcciones'));await tx.get(doc(db,`direcciones/${data.id}`));
  const n=counter.data().ultimo_numero+1;data.writes[0].data.numero_comercial='DIR'+String(n).padStart(3,'0');
  data.writes[1].data.ultimo_numero=n;data.writes[1].data.ultimo_id=data.writes[0].data.numero_comercial;
  for(const w of data.writes) {if(w.update)tx.update(doc(db,w.p),w.data);else tx.set(doc(db,w.p),w.data);}return data.id;
 });
}

// Mismo protocolo que numbered_transaction.dart: reintentos limitados, mismo ID,
// solo ante permission-denied Y avance del contador comprobado en el servidor.
async function numberedRun(db,path,prepare) {
 for(let attempt=0;;attempt++) {
  let observed;
  try {return await runTransaction(db,async tx=>{
   observed=(await tx.get(doc(db,path))).data().ultimo_numero;
   return prepare(tx);
  });} catch(error) {
   if(error.code!=='permission-denied'||attempt>=2||!Number.isInteger(observed))throw error;
   const current=(await getDoc(doc(db,path))).data().ultimo_numero;
   if(!Number.isInteger(current)||current<=observed)throw error;
  }
 }
}
test('direcciones de dos clientes concurrentes DIR003 DIR004 y referencias internas conservadas',async()=>{
 const a=client(),b=client('other');const ids=await Promise.all([addAddress(a),addAddress(b,'FARM003')]);
 const docs=await Promise.all([getDoc(doc(a,`direcciones/${ids[0]}`)),getDoc(doc(b,`direcciones/${ids[1]}`))]);
 assert.deepEqual(docs.map(d=>d.data().numero_comercial).sort(),['DIR003','DIR004']);
 assert.equal((await getDoc(doc(a,`direcciones/${fixture.AddressId}`))).exists(),true);
});
for(const mode of ['sin-contador','solo-contador','ajena','salto','tipo','referencia','codigo'])test(`contador dirección rechaza ${mode}`,async()=>{
 const db=client(),data=addressPayload(db);
 if(mode==='sin-contador')data.writes.pop();
 if(mode==='solo-contador')data.writes.shift();
 if(mode==='ajena')data.writes[0].data.id_cliente='FARM003';
 if(mode==='salto'){data.writes[1].data.ultimo_numero=9;data.writes[1].data.ultimo_id='DIR009';data.writes[0].data.numero_comercial='DIR009';}
 if(mode==='tipo')data.writes[1].data.ultimo_numero='3';
 if(mode==='referencia')data.writes[1].data.ultimo_documento_id='ZZZZZZZZZZZZZZZZZZZZ';
 if(mode==='codigo')data.writes[0].data.numero_comercial='DIR999';
 await assertFails(commit(db,data));
});
test('código de dirección inmutable; dirección histórica editable sin migrarla',async()=>{
 const db=client(),id=await addAddress(db);
 await assertFails(commit(db,{writes:[{p:`direcciones/${id}`,update:true,data:{numero_comercial:'DIR999'}}]}));
 await assertSucceeds(commit(db,{writes:[{p:`direcciones/${fixture.AddressId}`,update:true,data:{referencia:'nueva referencia'}}]}));
});
test('pedido histórico v1 LINEA1 sigue legible y aprobable sin tocar inventario',async()=>{
 const db=client(),seller=client('seller'),id='HHHHHHHHHHHHHHHHHHHH';
 await env.withSecurityRulesDisabled(async c=>{const b=writeBatch(c.firestore());b.set(doc(c.firestore(),`pedidos/${id}`),{schema_version:'spark_single_v1',estado:'pendiente',id_cliente:'FARM004',total:150,numero_comercial:'PED002'});b.set(doc(c.firestore(),`pedidos/${id}/detalle_pedido/LINEA1`),{id_producto:'PROD001',cantidad:1});await b.commit();});
 assert.equal((await getDocs(collection(db,`pedidos/${id}/detalle_pedido`))).docs[0].id,'LINEA1');
 await assertSucceeds(approve(seller,id));assert.equal((await getDoc(doc(db,'lotes_productos/LOTE001'))).data().cantidad_disponible,100);
});

test('segundo cliente autorizado confirma',async()=>{const db=client('other');assert.equal((await getDoc(doc(db,'usuarios/other'))).data().rol,'cliente');await confirm(db,{uid:'other',farm:'FARM003',address:'OTHERADDRESS'});});
test('segundo cliente autorizado registra dirección',async()=>{await addAddress(client('other'),'FARM003');});

test('contador double nativo rechazado aunque tenga valor entero',async()=>{
 // Simula un contador inicial creado por error como double desde Console.
 await rawCommit([{update:{name:fullName('configuracion/contadores_pedidos'),fields:{ultimo_numero:{doubleValue:2},ultimo_id:{stringValue:'PED002'},ultimo_documento_id:{stringValue:'existingOrder'}}}}]);
 const db=client();await assertFails(confirm(db));
 assert.equal((await getDoc(doc(db,'lotes_productos/LOTE001'))).data().cantidad_disponible,100);
});
test('dos pedidos o direcciones no comparten el incremento de un contador',async()=>{
 const db=client(),a=payload(db),b=payload(db);
 await assertFails(commit(db,{writes:[...a.writes.slice(0,4),...b.writes]}));
 const x=addressPayload(db),y=addressPayload(db);
 await assertFails(commit(db,{writes:[x.writes[0],...y.writes]}));
});
