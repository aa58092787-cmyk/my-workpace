import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.49.1';
import { SUPABASE_URL, SUPABASE_PUBLIC_KEY } from './config.js';

export const db = SUPABASE_URL.startsWith('https://') && SUPABASE_PUBLIC_KEY && !SUPABASE_PUBLIC_KEY.includes('YOUR_')
  ? createClient(SUPABASE_URL, SUPABASE_PUBLIC_KEY, { auth: { persistSession:false, autoRefreshToken:true, detectSessionInUrl:false } }) : null;
function client(){ if(!db) throw Error('config.js의 Supabase 연결 설정을 확인하세요.'); return db; }
function checked({data,error}){ if(error) throw error; return data; }
export async function login(email,password){return checked(await client().auth.signInWithPassword({email,password}));}
export async function signup(email,password){return checked(await client().auth.signUp({email,password}));}
export async function logout(){checked(await client().auth.signOut());}
export async function currentUser(){const data=checked(await client().auth.getUser());if(!data.user)throw Error('로그인이 필요합니다.');return data.user;}
const columns='id,title,description,status,priority,due,created_at';
function payload(task){const data={};for(const k of ['title','description','status','priority','due'])if(Object.hasOwn(task,k))data[k]=k==='due'?(task[k]||null):task[k];return data;}
export async function listTasks(){
 const result=[];let start=0;
 while(true){const rows=checked(await client().from('tasks').select(columns).order('created_at').order('id').range(start,start+499));result.push(...rows.map(t=>({...t,due:t.due||''})));if(rows.length<500)break;start+=500;}
 return result;
}
export async function createTask(task){const user=await currentUser();return checked(await client().from('tasks').insert({...payload(task),user_id:user.id}).select('id').single());}
export async function updateTask(id,task){return checked(await client().from('tasks').update(payload(task)).eq('id',id).select('id').single());}
export async function deleteTask(id){return checked(await client().from('tasks').delete().eq('id',id).select('id').single());}
export async function replaceTasks(tasks){return checked(await client().rpc('replace_my_tasks',{p_tasks:tasks.map(payload)}));}
