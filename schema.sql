-- QUIZ PARTY | Supabase SQL Editor에 전체 실행 (새 프로젝트 전용 권장)
create extension if not exists pgcrypto;
create table if not exists public.qp_rooms (
 id uuid primary key default gen_random_uuid(),
 code text unique not null,
 host_id uuid not null,
 title text not null default '우리들의 퀴즈 파티',
 questions jsonb not null default '[]'::jsonb,
 phase text not null default 'lobby',
 idx int not null default 0,
 phase_at timestamptz not null default now(),
 duration_sec int not null default 20,
 updated_at timestamptz not null default now(),
 created_at timestamptz not null default now()
);
create table if not exists public.qp_players (
 id uuid primary key default gen_random_uuid(),
 room_id uuid not null references public.qp_rooms(id) on delete cascade,
 user_id uuid not null,
 nickname text not null,
 points int not null default 0,
 joined_at timestamptz not null default now(),
 unique(room_id,user_id), unique(room_id,nickname)
);
create index if not exists qp_players_rank on public.qp_players(room_id, points desc);
create table if not exists public.qp_answers (
 room_id uuid not null references public.qp_rooms(id) on delete cascade,
 player_id uuid not null references public.qp_players(id) on delete cascade,
 question_idx int not null,
 choice int not null,
 awarded int not null,
 answered_at timestamptz not null default now(),
 primary key(player_id, question_idx)
);
alter table public.qp_rooms enable row level security;
alter table public.qp_players enable row level security;
alter table public.qp_answers enable row level security;
revoke all on public.qp_rooms, public.qp_players, public.qp_answers from anon, authenticated;

create or replace function public.qp_create(p_title text, p_questions jsonb)
returns jsonb language plpgsql security definer set search_path = public as $$
declare v_code text; v_room public.qp_rooms; n int := 0;
begin
 if auth.uid() is null or coalesce(auth.jwt()->>'is_anonymous','false')='true' then raise exception '진행자 계정으로 로그인하세요'; end if;
 if jsonb_typeof(p_questions) <> 'array' or jsonb_array_length(p_questions) <> 8 then raise exception '문제는 정확히 8개여야 합니다'; end if;
 loop
  v_code := lpad((floor(random()*1000000))::int::text,6,'0');
  begin
   insert into public.qp_rooms(code,host_id,title,questions) values(v_code,auth.uid(),left(coalesce(nullif(trim(p_title),''),'우리들의 퀴즈 파티'),100),p_questions) returning * into v_room;
   exit;
  exception when unique_violation then n:=n+1; if n>10 then raise exception '방 코드 생성 실패'; end if;
  end;
 end loop;
 return jsonb_build_object('code',v_code,'id',v_room.id);
end $$;

create or replace function public.qp_join(p_code text,p_nickname text)
returns jsonb language plpgsql security definer set search_path = public as $$
declare r public.qp_rooms; p public.qp_players; v_name text;
begin
 if auth.uid() is null then raise exception '참가자 연결 실패. 새로고침 후 재시도하세요'; end if;
 v_name := left(trim(coalesce(p_nickname,'')),20);
 if length(v_name)<2 then raise exception '닉네임은 2자 이상 입력하세요'; end if;
 select * into r from public.qp_rooms where code=p_code for update;
 if not found then raise exception '존재하지 않는 입장 코드입니다'; end if;
 select * into p from public.qp_players where room_id=r.id and user_id=auth.uid();
 if found then return jsonb_build_object('nickname',p.nickname,'code',r.code); end if;
 if r.phase <> 'lobby' then raise exception '이미 퀴즈가 시작되었습니다'; end if;
 if (select count(*) from public.qp_players where room_id=r.id)>=120 then raise exception '정원 120명이 모두 찼습니다'; end if;
 insert into public.qp_players(room_id,user_id,nickname) values(r.id,auth.uid(),v_name) returning * into p;
 return jsonb_build_object('nickname',p.nickname,'code',r.code);
exception when unique_violation then raise exception '이미 사용 중인 닉네임입니다. 다른 이름을 입력해 주세요';
end $$;

create or replace function public.qp_state(p_code text)
returns jsonb language plpgsql security definer set search_path = public as $$
declare r public.qp_rooms; q jsonb; v_host bool; v_me public.qp_players; v_count int; v_answered int; v_top jsonb; v_own_rank int; v_total int; v_right int; v_question jsonb;
begin
 if auth.uid() is null then raise exception '먼저 로그인하거나 입장하세요'; end if;
 select * into r from public.qp_rooms where code=p_code;
 if not found then raise exception '방을 찾을 수 없습니다'; end if;
 v_host := (r.host_id=auth.uid());
 select * into v_me from public.qp_players where room_id=r.id and user_id=auth.uid();
 if not v_host and v_me.id is null then raise exception '이 방에 입장해 주세요'; end if;
 select count(*) into v_count from public.qp_players where room_id=r.id;
 select count(*) into v_answered from public.qp_answers where room_id=r.id and question_idx=r.idx;
 select coalesce(jsonb_agg(jsonb_build_object('nickname', nickname,'points',points,'rank',rank_no) order by rank_no),'[]'::jsonb) into v_top from
   (select nickname,points,row_number() over(order by points desc,joined_at asc) rank_no from public.qp_players where room_id=r.id order by points desc,joined_at asc limit case when r.phase='final' then 120 else 5 end) t;
 if v_me.id is not null then select rank_no into v_own_rank from (select user_id,row_number() over(order by points desc,joined_at asc) rank_no from public.qp_players where room_id=r.id) t where user_id=auth.uid(); end if;
 q:=r.questions->r.idx;
 if r.phase in ('question','reveal','leaderboard') and q is not null then
  v_question:=jsonb_build_object('text',q->>'text','options',q->'options','seconds',coalesce((q->>'seconds')::int,20),'image',q->>'image');
  if r.phase in ('reveal','leaderboard') or v_host then v_question:=v_question || jsonb_build_object('correct',q->'correct'); end if;
 else v_question:=null; end if;
 return jsonb_build_object('code',r.code,'title',r.title,'phase',r.phase,'idx',r.idx,'total',jsonb_array_length(r.questions),
   'phase_at',r.phase_at,'server_at',clock_timestamp(),'count',v_count,'answered',v_answered,'question',v_question,
   'top',v_top,'me',case when v_me.id is not null then jsonb_build_object('nickname',v_me.nickname,'points',v_me.points,'rank',v_own_rank,'answered',exists(select 1 from public.qp_answers where player_id=v_me.id and question_idx=r.idx),'choice',(select choice from public.qp_answers where player_id=v_me.id and question_idx=r.idx)) else null end,
   'is_host',v_host);
end $$;

create or replace function public.qp_answer(p_code text,p_choice int)
returns jsonb language plpgsql security definer set search_path = public as $$
declare r public.qp_rooms; p public.qp_players; q jsonb; v_sec int; v_elapsed numeric; v_points int;
begin
 select * into r from public.qp_rooms where code=p_code;
 if not found or r.phase<>'question' then raise exception '현재 답을 제출할 수 없습니다'; end if;
 select * into p from public.qp_players where room_id=r.id and user_id=auth.uid();
 if not found then raise exception '참가자가 아닙니다'; end if;
 q:=r.questions->r.idx; v_sec:=greatest(5,least(120,coalesce((q->>'seconds')::int,20)));
 v_elapsed:=extract(epoch from (clock_timestamp()-r.phase_at));
 if v_elapsed>v_sec+0.8 then raise exception '제한시간이 종료되었습니다'; end if;
 if p_choice<0 or p_choice>3 then raise exception '잘못된 보기입니다'; end if;
 v_points:=case when p_choice=(q->>'correct')::int then 500+floor(500*greatest(0,(v_sec-v_elapsed)/v_sec))::int else 0 end;
 insert into public.qp_answers(room_id,player_id,question_idx,choice,awarded) values(r.id,p.id,r.idx,p_choice,v_points);
 update public.qp_players set points=points+v_points where id=p.id;
 return jsonb_build_object('accepted',true,'awarded',v_points);
exception when unique_violation then raise exception '이미 답변하셨습니다';
end $$;

create or replace function public.qp_control(p_code text,p_action text)
returns jsonb language plpgsql security definer set search_path = public as $$
declare r public.qp_rooms; v_phase text; v_idx int;
begin
 select * into r from public.qp_rooms where code=p_code for update;
 if not found or r.host_id is distinct from auth.uid() then raise exception '진행자 권한이 없습니다'; end if;
 v_phase:=r.phase; v_idx:=r.idx;
 if p_action='start' and v_phase='lobby' then v_phase:='question'; v_idx:=0;
 elsif p_action='reveal' and v_phase='question' then v_phase:='reveal';
 elsif p_action='leaderboard' and v_phase='reveal' then v_phase:='leaderboard';
 elsif p_action='next' and v_phase='leaderboard' then
   if v_idx+1>=jsonb_array_length(r.questions) then v_phase:='final'; else v_phase:='question';v_idx:=v_idx+1;end if;
 elsif p_action='finish' and v_phase='leaderboard' then v_phase:='final';
 else raise exception '지금은 진행할 수 없는 단계입니다'; end if;
 update public.qp_rooms set phase=v_phase,idx=v_idx,phase_at=clock_timestamp(),updated_at=now() where id=r.id;
 return jsonb_build_object('phase',v_phase,'idx',v_idx);
end $$;

revoke all on function public.qp_create(text,jsonb),public.qp_join(text,text),public.qp_state(text),public.qp_answer(text,int),public.qp_control(text,text) from public;
grant execute on function public.qp_create(text,jsonb),public.qp_join(text,text),public.qp_state(text),public.qp_answer(text,int),public.qp_control(text,text) to authenticated;
