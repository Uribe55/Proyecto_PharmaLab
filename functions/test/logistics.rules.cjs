"use strict";
const {test,before,after,beforeEach}=require('node:test');
const assert=require('node:assert/strict');
const {initializeTestEnvironment,assertSucceeds,assertFails}=require('@firebase/rules-unit-testing');
const {doc,getDoc,getDocs,collection,query,where,writeBatch,serverTimestamp,Timestamp}=require('firebase/firestore');
assert.match(process.env.FIRESTORE_EMULATOR_HOST||'',/^127\.0\.0\.1:8085$/);
let env;const id='abcdefghijklmnopqrst',oid='orderCurrent';
before(async()=>{env=await initializeTestEnvironment({projectId:'demo-pharmalab-logistics',firestore:{host:'127.0.0.1',port:8085,rules:require('fs').readFileSync('../firestore.rules','utf8')}})});
after(async()=>env?.cleanup());
beforeEach(async()=>{await env.clearFirestore();await env.withSecurityRulesDisabled(async c=>{const db=c.firestore(),b=writeBatch(db);for(const [p,d] of Object.entries({
 'usuarios/seller':{rol:'vendedor',estado:true},'usuarios/admin':{rol:'administrador',estado:true},'usuarios/driver':{rol:'repartidor',estado:true},'usuarios/otherDriver':{rol:'repartidor',estado:true},'usuarios/client':{rol:'cliente',estado:true},
 'empleado/EMP002':{cargo:'Repartidor',estado:true,usuario_id:'driver'},'empleado/EMP003':{cargo:'Repartidor',estado:true,usuario_id:'otherDriver'},
 'farmacia_cliente/FARM001':{usuario_id:'client',estado:true,nombre_farmacia:'Farmacia',responsable:'Contacto',telefono:'123'},
 'direcciones/DIR001':{id_cliente:'FARM001',direccion:'Calle',referencia:'Puerta'},
 ['pedidos/'+oid]:{schema_version:'spark_single_v2',estado:'aprobado',id_cliente:'FARM001',id_direccion:'DIR001',numero_comercial:'PED002',total:100},
 ['pedidos/'+oid+'/detalle_pedido/DET001']:{id_producto:'PROD001',producto_nombre:'Producto',cantidad:2,precio_unitario:50},
 'productos/PROD001':{nombre:'Producto'},
 'lotes_productos/LOT001':{cantidad_disponible:20},
 'entregas/ENT001':{estado:'Entregado',id_pedido:'PED001',id_repartidor:'EMP002'},
 'pedidos/PED001':{estado:'Entregado',total:10}
}))b.set(doc(db,p),d);await b.commit();});});
function db(uid){return env.authenticatedContext(uid).firestore();}
function assign(uid='seller',changes={}){const d=db(uid),b=writeBatch(d);b.set(doc(d,'entregas/'+id),{schema_version:'spark_logistics_v1',estado:'asignada',fecha_creacion:serverTimestamp(),fecha_programada:null,id_pedido:oid,id_repartidor:'EMP002',repartidor_uid:'driver',asignado_por:uid,numero_comercial:'ENT-PED002',pedido_numero:'PED002',farmacia:'Farmacia',contacto:'Contacto',telefono:'123',direccion:'Calle',referencia:'Puerta',producto:'PROD001',producto_nombre:'Producto',cantidad:2,...changes});b.set(doc(d,'entregas/'+id+'/detalle_entrega/DENT001'),{id_detalle_pedido:'DET001',cantidad_programada:2,cantidad_entregada:0});b.update(doc(d,'pedidos/'+oid),{id_entrega:id});return b.commit();}
function transition(state,uid='driver',opts={}){const d=db(uid),b=writeBatch(d);b.update(doc(d,'entregas/'+id),{estado:state,fecha_estado:serverTimestamp(),motivo:state==='fallida'?'Farmacia cerrada':'',observacion:state==='fallida'?'Sin atenci?n':''});b.update(doc(d,'pedidos/'+oid),{estado:state,fecha_logistica:serverTimestamp(),...(opts.total?{total:1}:{})});if(!opts.noHistory)b.set(doc(d,'pedidos/'+oid+'/historial_estado/LOG_'+state),{estado_anterior:state==='en_ruta'?'aprobado':'en_ruta',estado_nuevo:state,fecha_cambio:serverTimestamp(),id_usuario:uid,observaciones:state==='fallida'?'Farmacia cerrada: Sin atenci?n':''});if(state==='entregado'&&!opts.noDetail)b.update(doc(d,'entregas/'+id+'/detalle_entrega/DENT001'),{cantidad_entregada:2});return b.commit();}
async function seed(p,data){await env.withSecurityRulesDisabled(async c=>{const b=writeBatch(c.firestore());b.update(doc(c.firestore(),p),data);await b.commit();});}
test('vendedor y administrador asignan aprobado sin despachar',async()=>{await assertSucceeds(assign());assert.equal((await getDoc(doc(db('seller'),'pedidos/'+oid))).data().estado,'aprobado');});
test('administrador asigna',async()=>assertSucceeds(assign('admin')));
for(const role of ['client','driver'])test(role+' no asigna',async()=>assertFails(assign(role)));
test('empleado inactivo rechazado',async()=>{await seed('empleado/EMP002',{estado:false});await assertFails(assign());});
test('cuenta repartidor inactiva rechazada',async()=>{await seed('usuarios/driver',{estado:false});await assertFails(assign());});
test('pendiente rechazado',async()=>{await seed('pedidos/'+oid,{estado:'pendiente'});await assertFails(assign());});
test('duplicado rechazado',async()=>{await assign();await assertFails(assign());});
test('sin detalle no se crea entrega',async()=>{const d=db('seller'),b=writeBatch(d);b.update(doc(d,'pedidos/'+oid),{id_entrega:id});await assertFails(b.commit());});
test('contacto falsificado rechazado',async()=>assertFails(assign('seller',{telefono:'falso'})));
test('solo entregas propias y sin lectura comercial',async()=>{await assign();await assertSucceeds(getDocs(query(collection(db('driver'),'entregas'),where('id_repartidor','==','EMP002'))));await assertFails(getDoc(doc(db('otherDriver'),'entregas/'+id)));await assertFails(getDoc(doc(db('driver'),'pedidos/'+oid)));});
test('ruta y entrega coherentes; stock total y ENT001 intactos',async()=>{await assign();await assertSucceeds(transition('en_ruta'));assert.equal((await getDoc(doc(db('client'),'pedidos/'+oid))).data().estado,'en_ruta');await assertSucceeds(transition('entregado'));const d=db('seller');assert.equal((await getDoc(doc(d,'pedidos/'+oid))).data().total,100);assert.equal((await getDoc(doc(d,'lotes_productos/LOT001'))).data().cantidad_disponible,20);assert.equal((await getDoc(doc(d,'entregas/'+id+'/detalle_entrega/DENT001'))).data().cantidad_entregada,2);assert.equal((await getDoc(doc(db('client'),'pedidos/'+oid))).data().estado,'entregado');await assertFails(transition('entregado'));assert.equal((await getDoc(doc(d,'entregas/ENT001'))).data().estado,'Entregado');});
test('fallida guarda motivo observacion y no cancela',async()=>{await assign();await transition('en_ruta');await assertSucceeds(transition('fallida'));const d=(await getDoc(doc(db('seller'),'entregas/'+id))).data();assert.equal(d.motivo,'Farmacia cerrada');assert.equal(d.observacion,'Sin atenci?n');assert.equal((await getDoc(doc(db('client'),'pedidos/'+oid))).data().estado,'fallida');});
for(const uid of ['client','seller','otherDriver'])test(uid+' no despacha',async()=>{await assign();await assertFails(transition('en_ruta',uid));});
test('historial obligatorio',async()=>{await assign();await assertFails(transition('en_ruta','driver',{noHistory:true}));});
test('total inmutable',async()=>{await assign();await assertFails(transition('en_ruta','driver',{total:true}));});
test('cantidades obligatorias',async()=>{await assign();await transition('en_ruta');await assertFails(transition('entregado','driver',{noDetail:true}));});
