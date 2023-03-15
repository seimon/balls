
ver=0.31 -- 2022-03-15
--[[
v0.31 
- 하트, 남은 킥 수 추가하고 UI 표시

v0.3
- 간단한 게임 순환구조 완성(클리어, 게임오버)
- 로고 살짝 더 꾸미기
- 룸 1~5까지 진행 가능(5 다음에는 다시 1)
- 조작감 개선

v0.21
- 비네팅 전환 과정 더 부드럽게 + 동적인 느낌 추가
- 타이틀 화면 전환 연출 살짝
- ROOM CLEAR 화면 간단히 만드는 중

v0.20
- 비네팅 연출 보강(전환 과정 부드럽게)
- 타이틀 화면 등장퇴장 사운드 추가
- 조작 대기 상황 조건 수정(모든 공이 충분히 느려졌을 때)
- 타이틀 화면이 나올 때는 게임의 움직임과 물리 처리를 멈춤
- 플레이어 공이 사라졌을 때는 액션 대기하지 않음(게임 진행 불가 상태)
- todo: 게임오버 상태 만들어야 함

v0.19
- 비네팅 효과 추가(fillp_step() 최적화 필요)

v0.18
- 타일 좌표 설정 최적화(매번 좌표 *8 처리하던 걸 제거)
- 바닥 타일 최적화(듬성듬성 찍음)
- 타이틀 그리는 것도 조금 간소화
- 홀에 들어갔을 때 이펙트
- 조작 문제 고침(조작 관련 코드를 _update60()으로 이동)

v0.17
- 박스 충돌체크를 상하좌우 먼저, 모서리를 마지막에 몰아서 처리
- 기본 소리 적용
- 조작이 비정상 상태가 돼버림...

v0.14
- 타이틀 화면 간단히 꾸밈
- X키 눌러서 타이틀<->게임 전환하는 임시 구현
- 딤 처리 전환 연출 추가
- 구슬이 0개일 때의 처리 추가
]]

sw,sh=128,128
cx,cy=sw/2,sh/2
f=0
c_bg=9 -- bg color
c_sd=5 -- shadow color

-------------------------------------------------------------------------------
-- log
log_txt={}
function print_log()
	if(#log_txt<=0) return
	for i=#log_txt,max(1,#log_txt-15),-1 do
		print(log_txt[i],4,4+(#log_txt-i)*7,14)
	end
end
function log(s) add(log_txt,s) end
-- log (끝)
-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
-- 물리 처리

-- 공과 벽의 충돌 처리
function bouncing_wall(c,w,h)
	if(c.x<c.r) c.sx*=-1 c.x+=(c.r-c.x)*2 c.hit_c=3 return 1
	if(c.x>w-c.r) c.sx*=-1 c.x-=(c.r-(w-c.x))*2  c.hit_c=3 return 1
	if(c.y<c.r) c.sy*=-1 c.y+=(c.r-c.y)*2  c.hit_c=3 return 1
	if(c.y>h-c.r) c.sy*=-1 c.y-=(c.r-(h-c.y))*2  c.hit_c=3 return 1
	return 0
end

-- 공과 점의 충돌 처리
function bouncing_point(c,px,py)
	if((px-c.x)^2+(py-c.y)^2>c.r^2) return 0

	-- [정확히 충돌한 시점으로 되돌리기]
	-- 현재 좌표의 거리, 1프레임 전 좌표간 거리, 거리를 활용해서 실제 충돌 지점을 산출한다.
	-- 원을 그 지점으로 옮긴 후 현재 프레임에 실제로 있어야 할 위치로 옮긴다.
	local dist_now=sqrt((c.x-px)^2+(c.y-py)^2)
	local dist_old=sqrt(((c.x-c.sx)-px)^2+((c.y-c.sy)-py)^2)

	-- 정확한 충돌 시점 상황으로 돌아간다
	local a_hit=nil -- 원과 점의 충돌 방향
	local r_to_hit=0
	if dist_old>dist_now and dist_old>c.r then -- 이전 프레임에 충돌 거리보다 멀다면?
		local t1=c.r-dist_old
		local t2=dist_now-dist_old
		r_to_hit=1-t1/t2 -- 현재 프레임에서 충돌 시점까지의 시간 비율(0.2라면 [현재 프레임-0.2프레임]에 충돌한 것)

		-- 원을 충돌 시점 좌표로 옮겨준다
		c.x-=c.sx*r_to_hit
		c.y-=c.sy*r_to_hit
	else
		-- 이전 프레임도 충돌 거리보다 가깝다면?
		-- 강제로 멀리 밀어준다(정석은 아니지만 대충 퉁치자)
		local push_dist=c.r-dist_now+0.1 -- 밀어내야할 거리
		a_hit=atan2(px-c.x,py-c.y)
		c.x-=cos(a_hit)*push_dist
		c.y-=sin(a_hit)*push_dist
	end

	local spd=sqrt(c.sx^2+c.sy^2)
	local a_spd=atan2(c.sx,c.sy)
	a_hit=a_hit or atan2(px-c.x,py-c.y)
	local next_a=a_hit+(a_hit-a_spd)+0.5
	c.sx=cos(next_a)*spd
	c.sy=sin(next_a)*spd
	c.hit_c=3

	-- 충돌 시점 상황까지 돌아간 시간만큼 교환한 속도를 즉시 적용
	if r_to_hit>0 then
		c.x+=c.sx*r_to_hit
		c.y+=c.sy*r_to_hit
	end

	return 1
end

-- 공과 박스의 충돌 처리
function bouncing_boxes(c)
	local hit_count=0

	-- 상하좌우 충돌부터 먼저 처리(박스들이 붙어있을 때 모서리 충돌하는 문제 때문)
	for b in all(boxes) do
		local x1,y1,x2,y2=get_box_coords(b)
		-- 좌우 + 모서리
		if c.y+c.r>y1 and c.y-c.r<y2 then
			if c.y>y1 and c.y<y2 then -- 좌우 벽면
				if c.x<x1 and c.x+c.r>x1 then
					c.sx*=-1
					c.x-=(c.x+c.r-x1)*2
					c.hit_c=3
					hit_count+=1
				elseif c.x>x2 and c.x-c.r<x2 then
					c.sx*=-1
					c.x+=(x2-c.x+c.r)*2
					c.hit_c=3
					hit_count+=1
				end
			end
		end
		-- 상하
		if c.x>x1 and c.x<x2 then
			if c.y<y1 and c.y+c.r>y1 then
				c.sy*=-1
				c.y-=(c.y+c.r-y1)*2
				c.hit_c=3
				hit_count+=1
			elseif c.y>y2 and c.y-c.r<y2 then
				c.sy*=-1
				c.y+=(y2-c.y+c.r)*2
				c.hit_c=3
				hit_count+=1
			end
		end
	end

	if(hit_count>0) return hit_count

	-- 모서리 충돌
	for b in all(boxes) do
		local x1,y1,x2,y2=get_box_coords(b)
		if c.y+c.r>y1 and c.y-c.r<y2 then
			if c.y<=y1 then -- 상단 모서리
				if c.x<=x1 then hit_count+=bouncing_point(c,x1,y1) -- 좌상 
				elseif c.x>=x2 then hit_count+=bouncing_point(c,x2,y1) end -- 우상
			else -- 하단 모서리
				if c.x<=x1 then hit_count+=bouncing_point(c,x1,y2) -- 좌하
				elseif c.x>=x2 then hit_count+=bouncing_point(c,x2,y2) end -- 우하
			end
		end
	end

	return hit_count
end

-- 공과 홀의 충돌 처리
function collision_hole(c,h)
	local rr=c.r+1 -- 홀의 반지름은 1로 처리(거의 중심에 닿아야 들어가는 것)
	if(abs(c.x-h.x)>rr or abs(c.y-h.y)>rr) return -- x, y 좌표 거리가 멀면 충돌 아님
	local dx,dy=c.x-h.x,c.y-h.y
	local dd=dx*dx+dy*dy
	if(dd>rr*rr) return -- 거리가 원과 홀의 반지름 합보다 짧아야 충돌(제곱근 사용하지 않고 판정부터 빠르게)
	return true,h.x+1,h.y+1
end

-- 공과 심연의 충돌 처리
function collision_abysses(c)
	-- 공의 중심이 심연에 닿아야 빠지는 것
	for b in all(abysses) do
		local x1,y1,x2,y2=get_box_coords(b)
		if c.x>=x1 and c.x<=x2 then
			if c.y>=y1 and c.y<=y2 then
				-- 공이 떨어져갈 좌표 설정(공이 심연 안쪽으로 확실히 들어가도록)
				local dx1,dx2=abs(x1-c.x),abs(x2-c.x)
				local dy1,dy2=abs(y1-c.y),abs(y2-c.y)
				local tx,ty=c.x+c.sx*5,c.y+c.sy*5
				if dx1<=c.r then tx=x1+c.r
				elseif dx2<=c.r then tx=x2-c.r end
				if dy1<=c.r then ty=y1+c.r
				elseif dy2<=c.r then ty=y2-c.r end
				return true,tx,ty
			end
		end
	end
	return false,c.tx,c.ty
end

-- 두 공의 충돌 처리(질량은 동일하다고 가정)
function ball_collision(c1,c2)
	local rr=c1.r+c2.r
	if(abs(c1.x-c2.x)>rr or abs(c1.y-c2.y)>rr) return 0 -- x, y 좌표 거리가 멀면 충돌 아님
	local dx,dy=c2.x-c1.x,c2.y-c1.y
	local dd=dx*dx+dy*dy
	if(dd>rr*rr) return 0 -- 거리가 두 원의 반지름 합보다 짧아야 충돌(제곱근 사용하지 않고 판정부터 빠르게)
	
	-- 여기부터는 충돌 후 처리
	
	-- [정확히 충돌한 시점으로 되돌리기]
	-- 현재 좌표의 거리, 1프레임 전 좌표간 거리, 반지름의 합을 활용해서 실제 충돌 지점을 산출한다.
	-- 두 원을 그 지점으로 옮긴 후 교환된 속도값을 일부 더해서 현재 프레임에 실제로 있어야 할 위치로 옮긴다.
	local dist_now=sqrt(dd)
	local old_dx=(c2.x-c2.sx)-(c1.x-c1.sx)
	local old_dy=(c2.y-c2.sy)-(c1.y-c1.sy)
	local dist_old=sqrt(old_dx*old_dx+old_dy*old_dy)

	-- 정확한 충돌 시점 상황으로 돌아간다
	local a_hit=nil -- 두 원의 충돌 방향
	local r_to_hit=0
	if dist_old>dist_now and dist_old>c1.r+c2.r then
		local t1=c1.r+c2.r-dist_old
		local t2=dist_now-dist_old
		r_to_hit=1-t1/t2 -- 현재 프레임에서 충돌 시점까지의 시간 비율(0.2라면 [현재 프레임-0.2프레임]에 충돌한 것)

		-- 두 원을 충돌 시점 좌표로 옮겨준다
		c1.x-=c1.sx*r_to_hit
		c1.y-=c1.sy*r_to_hit
		c2.x-=c2.sx*r_to_hit
		c2.y-=c2.sy*r_to_hit
		dx,dy=c2.x-c1.x,c2.y-c1.y -- 거리 재계산(저 아래에서 다시 사용)
	else
		-- 이전 프레임의 거리가 반지름 합보다 가깝거나,
		-- 이전 프레임의 거리가 현재 프레임의 거리보다 더 짧다??? (반사되면서 충돌하면 이런 경우가 있음)
		-- 이러면... 충돌 방향만 가지고 서로 밀어낸다(정석은 아니지만... 나중에 좋은 방법 생각나면 바꾸는 걸로)
		local push_dist=(c1.r+c2.r-dist_now)/2+0.1 -- 밀어내야할 거리
		a_hit=atan2(dx,dy)
		c1.x-=cos(a_hit)*push_dist
		c1.y-=sin(a_hit)*push_dist
		c2.x+=cos(a_hit)*push_dist
		c2.y+=sin(a_hit)*push_dist
	end

	-- 충돌 후 나아갈 방향 계산(충돌 전의 각 벡터와 충돌 벡터로 산출)
	a_hit=a_hit or atan2(dx,dy)
	local spd_c1=sqrt(c1.sx*c1.sx+c1.sy*c1.sy)
	local spd_c2=sqrt(c2.sx*c2.sx+c2.sy*c2.sy)
	local a_c1=atan2(c1.sx,c1.sy)
	local a_c2=atan2(c2.sx,c2.sy)
	
	-- 질량 비율
	-- local m_ratio=c1.m/c2.m
	
	-- c1에서 c2로 보낼 힘, 남은 힘(충돌 방향)
	local spd_c1_to_c2=cos(a_c1-a_hit)*spd_c1
	local spd_c1_remain=sin(a_c1-a_hit)*spd_c1
	local sx_to_c2=cos(a_hit)*spd_c1_to_c2
	local sy_to_c2=sin(a_hit)*spd_c1_to_c2
	local sx_remain_c1=cos(a_hit-0.25)*spd_c1_remain
	local sy_remain_c1=sin(a_hit-0.25)*spd_c1_remain

	-- c2에서 c1으로 보낼 힘, 남은 힘(충돌 반대 방향)
	local spd_c2_to_c1=cos(a_hit+0.5-a_c2)*spd_c2
	local spd_c2_remain=sin(a_hit+0.5-a_c2)*spd_c2
	local sx_to_c1=cos(a_hit+0.5)*spd_c2_to_c1
	local sy_to_c1=sin(a_hit+0.5)*spd_c2_to_c1
	local sx_remain_c2=cos(a_hit-0.25)*spd_c2_remain
	local sy_remain_c2=sin(a_hit-0.25)*spd_c2_remain

	-- 주고받을 힘(속도)을 교환
	c1.sx=sx_remain_c1+sx_to_c1
	c1.sy=sy_remain_c1+sy_to_c1
	c2.sx=sx_remain_c2+sx_to_c2
	c2.sy=sy_remain_c2+sy_to_c2

	-- 충돌 시점 상황까지 돌아간 시간만큼 교환한 속도를 즉시 적용
	if r_to_hit>0 then
		c1.x+=c1.sx*r_to_hit
		c1.y+=c1.sy*r_to_hit
		c2.x+=c1.sx*r_to_hit
		c2.y+=c1.sy*r_to_hit
	end

	-- 충돌 강도에 따라 이펙트, 반짝임 추가
	local pow=max(abs(spd_c1_to_c2),abs(spd_c2_to_c1))
	if(pow>0.1) c1.hit_c=3 c2.hit_c=3 -- 구슬 반짝임
	if(pow>0.6) add_hit_eff((c1.x+c2.x)/2,(c1.y+c2.y)/2,a_hit+0.25,{c1.c[3],c2.c[3],7},pow)

	return 1
end

-- 물리 처리 (끝)
-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
-- 기타

-- 점선 그리기
function draw_dot_line(x,y,angle,min,max)
	local dx=cos(angle)
	local dy=sin(angle)
	local dot1,dot2=0,4
	local len0=t()%0.2*5*(dot1+dot2)
	local max2=max-len0
	local x1,y1
	for i=0,(max2-min)/(dot1+dot2) do
		local len1=min+(dot1+dot2)*i+len0
		local len2=len1+dot1
		x1,y1=x+dx*len1,y+dy*len1
		pset(x1+1.5,y1+1.5,0)
		pset(x1,y1,10)
	end
	-- 꽁다리 원
	x1,y1=x+dx*(max+2),y+dy*(max+2)
	circfill(x1+1.5,y1+1.5,2,0)
	circfill(x1,y1,2,10)
end

-- 화면 복붙(이동자국 표현용)
frame_chunk_0=0x1000
frame_chunk_1=0x4300
function copyprevframe()
	memcpy(frame_chunk_0,0x6000,0x1000)
	memcpy(frame_chunk_1,0x7000,0x1000)
end
function pasteprevframe()
	memcpy(0x6000,frame_chunk_0,0x1000)
	memcpy(0x7000,frame_chunk_1,0x1000)
end

-- 팔레트 그리기
function draw_color_table()
	local size=12
	for i=0,15 do
		local x=i%8*size
		local y=i\8*size
		rectfill(x,y,x+size,y+size,i)
		print(i,x+2,y+2,i==0 and 1 or 0)
	end
end

-- 구슬 그리기
function draw_ball(c,deep)
	local x,y,r=flr(c.x+0.5),flr(c.y+0.5),c.r
	local c1,c2,c3,c4=c.c[1],c.c[2],c.c[3],0

	-- 어디 빠질 때는 어둡게 + 작게, 충돌하면 색을 밝게
	if deep then
		if(deep==1) r-=1
		if(deep>=2) c1,c2,c3,c4=c.c[1],c.c[2],c.c[2],0 r-=2
	elseif c.hit_c>2 then c1,c2,c3,c4=c.c[3],c.c[3],7,c.c[2]
	elseif c.hit_c>0 then c1,c2,c3,c4=c.c[2],c.c[3],7,0 end

	circfill(x,y,r,c4) -- outline
	circfill(x,y,r-1,c1)
	circfill(x-1,y-1,r-2,c2)

	-- highlight
	if deep then pset(x-2,y-2,c3)
	else line(x-3,y-2,x-1,y-2,c3) line(x-2,y-3,x-2,y-1,c3) end

	if(c.hit_c>0) c.hit_c-=1
end

-- 이펙트 그리기
-- todo: 레이어 구분 필요(지금은 공 이펙트가 벽에 가려지지 않음)
function draw_eff()
	for e in all(eff) do
		if e.type=="ball_ssok" or e.type=="ball_dive" then
			local r=e.eff_timer/30
			if r<0.15 then fillp(0b1110111110111111.1)
			elseif r<0.25 then fillp(0b1010110110100111.1)
			elseif r<0.5 then fillp(0b1010010110100101.1) end
			draw_ball(e,r<0.8 and 2 or 1)
			fillp()
			if e.type=="ball_ssok" then
				e.sx*=0.3
				e.sy*=0.3
				e.x+=e.sx+(e.tx-e.x)*0.25
				e.y+=e.sy+(e.ty-e.y)*0.25
			else
				e.sx*=0.8
				e.sy*=0.8
				e.x+=e.sx+(e.tx-e.x)*0.2
				e.y+=e.sy+(e.ty-e.y)*0.2
			end
		elseif e.type=="ssok" then
			local r=(e.eff_timer/30)^2
			if(f%2==0) circ(e.x+2,e.y+2,5+(1-r)*12,c_sd)
			circ(e.x,e.y,5+(1-r)*12,e.c)
		elseif e.type=="hit" then
			pset(e.x,e.y,e.c)
			e.x+=e.sx
			e.y+=e.sy
			e.sx*=0.94
			e.sy*=0.94
		end

		e.eff_timer-=1
		if(e.eff_timer<=0) del(eff,e)
	end
end

-- 충돌 이펙트
function add_hit_eff(x,y,angle,colors,pow)
	for i=1,5+flr(pow*2) do
		local a=angle+(rnd()<0.5 and 0 or 0.5)+rnd(0.1)-0.05
		local spd=1+rnd(1+pow)
		local sx=cos(a)*spd
		local sy=sin(a)*spd
		add(eff,
		{
			type="hit",
			x=x+rnd(4)-2,
			y=y+rnd(4)-2,
			sx=sx,
			sy=sy,
			c=rnd(colors),
			eff_timer=5+flr(rnd(8))
		})
	end
end

-- 박스 데이타 4개 좌표 뽑기
function get_box_coords(b)
	return b[1],b[2],b[3],b[4]
end

-- 로고 그리기
function draw_title_test(dy)

	local dx,dy=cos(t()*0.5)*4,sin(t()*0.5)*3+dy
	local x,y=40+dx,40+dy
	-- local s="\^w\^td\-fu\-fn\-fg\-fe\-fo\-fn\n \|h&\-fp\-fo\-fo\-fl" -- 자간 좁힘
	-- local s="\^w\^td\-f\|fu\-f\|fn\-f\|fg\-f\|fe\-f\|fo\-f\|fn\n\n    \|h\|c&\-f\|fp\-f\|fo\-f\|fo\-f\|fl" -- 자간 좁힘
	local s0="\^w\^t,d\-f,u\-f,n\-f,g\-f,e\-f,o\-f,n\n \|h&\-f,p\-f,o\-f,o\-f,l"
	s0=split(s0)
	local s=s0[1]
	local diff={"e","f","g","h","i"}
	for i=2,#s0 do
		s..="\|"..(diff[flr((f/8+i)%5+1)])..s0[i]
	end


	-- 그림자
	do
		local d=5
		print(s,x+d-1,y+d,0)
		print(s,x+d,y+d,0)
	end

	-- 글자
	do
		-- 외곽선
		print(s,x+1,y,0)
		print(s,x-1,y-2,0)
		print(s,x+1,y-2,0)
		print(s,x-1,y+2,0)
		print(s,x+1,y+2,0)

		-- 글자 본체
		print(s,x,y+1,3)
		print(s,x,y-1,14)
		print(s,x,y,8)
		
		-- &
		print("\^w\^t&",x+8,y+12,2)
		print("\^w\^t&",x+8,y+13,4)

		-- highlight
		--[[ local p_s="0,-1,7,-1,11,-1,14,-1,21,1,23,-1,28,-1,35,1,37,-1,42,-1,15,12,22,14,24,12,29,14,31,12,36,12" -- 자간 좁힘
		local p=split(p_s)
		for i=1,#p,2 do
			pset(x+p[i],y+p[i+1],15)
		end
		pset(x+8,y+12,7)
		pset(x+8,y+18,7) ]]
	end
end
function draw_title(dy)

	local dx,dy=cos(t()*0.5)*4,sin(t()*0.5)*3+dy
	local x,y=40+dx,40+dy
	local s="\^w\^td\-f\|fu\-f\|hn\-f\|fg\-f\|he\-f\|fo\-f\|hn\n \|h\|f&\-f\|hp\-f\|fo\-f\|ho\-f\|fl" -- 자간 좁힘

	-- 그림자
	do
		local d=5
		print(s,x+d-1,y+d,0)
		print(s,x+d,y+d,0)
	end

	-- 글자
	do
		-- 외곽선
		print(s,x+1,y,0)
		print(s,x-1,y-2,0)
		print(s,x+1,y-2,0)
		print(s,x-1,y+2,0)
		print(s,x+1,y+2,0)

		-- 글자 본체
		print(s,x,y+1,3)
		print(s,x,y-1,14)
		print(s,x,y,8)
		
		-- &
		print("\^w\^t&",x+8,y+11,2)
		print("\^w\^t&",x+8,y+12,4)

		-- highlight
		local p_s="0,-1,7,-2,11,-2,14,-1,21,0,23,-2,28,-1,35,0,37,-2,42,-1,15,12,22,13,24,11,29,14,31,12,36,11"
		local p=split(p_s)
		for i=1,#p,2 do
			pset(x+p[i],y+p[i+1],15)
		end
		pset(x+8,y+11,7)
		pset(x+8,y+17,7)
	end
end
-- 글자 + 외곽선 + 그림자
function printos(s,x,y,c,c_out,c_shadow)
	print(s,x+3,y+3,c_shadow)
	print(s,x-1,y,c_out)
	print(s,x+1,y,c_out)
	print(s,x,y-1,c_out)
	print(s,x,y+1,c_out)
	print(s,x,y,c)
end
-- 글자 + 그림자
function prints(s,x,y,c,c_out,c_shadow)
	print(s,x+3,y+3,c_shadow)
	print(s,x,y,c)
end

-- fillp()의 진하기를 1~15단계로 설정(15단계가 가장 진함, 0 이하는 투명, 16 이상은 완전히 채움)
fill_steps={0xffff.8,0xfffd.8,0xf7fd.8,0xf7f5.8,0xf5f5.8,0xf5e5.8,0xb5e5.8,0xb5a5.8,0xa5a5.8,0xa5a4.8,0xa1a4.8,0xa1a0.8,0xa0a0.8,0xa020.8,0x8020.8,0x8000.8,0x0000.8}
function fillp_step(s) fillp(fill_steps[min(17,max(1,s+1))]) end

-- 게임 상태 변경(title,play,gamever,clear)
-- todo: 간소화하자
function set_gamestate(to)
	if to=="title" then
		gg.is_title=true
		gg.is_playing=false
		gg.is_gameover=false
		gg.is_clear=false
		gg.use_dim=true
		gg.dim_pow=max(1,gg.dim_pow)
	elseif to=="gameover" then
		gg.is_title=false
		gg.is_playing=false
		gg.is_gameover=true
		gg.is_clear=false
		gg.use_dim=true
		gg.dim_pow=max(1,gg.dim_pow)
	elseif to=="clear" then
		gg.is_title=false
		gg.is_playing=false
		gg.is_gameover=false
		gg.is_clear=true
		gg.use_dim=true
		gg.dim_pow=max(1,gg.dim_pow)
	elseif to=="play" then
		gg.is_title=false
		gg.is_playing=true
		gg.is_gameover=false
		gg.is_clear=false
		gg.use_dim=false
	end
end

-- 기타 (끝)
-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
-- 게임

hit_count=0 -- 디버그용
eff={} -- 출력할 이펙트들

-- 비네팅 강도 16x16으로 설정
vntt=split("16,16,15,13,11,10,9,9,9,9,10,11,13,15,16,16,16,15,12,10,8,7,6,5,5,6,7,8,10,12,15,16,15,12,10,7,5,3,2,1,1,2,3,5,7,10,12,15,13,10,7,4,2,0,0,0,0,0,0,2,4,7,10,13,11,8,5,2,0,0,0,0,0,0,0,0,2,5,8,11,10,7,3,0,0,0,0,0,0,0,0,0,0,3,7,10,9,6,2,0,0,0,0,0,0,0,0,0,0,2,6,9,9,5,1,0,0,0,0,0,0,0,0,0,0,1,5,9,9,5,1,0,0,0,0,0,0,0,0,0,0,1,5,9,9,6,2,0,0,0,0,0,0,0,0,0,0,2,6,9,10,7,3,0,0,0,0,0,0,0,0,0,0,3,7,10,11,8,5,2,0,0,0,0,0,0,0,0,2,5,8,11,13,10,7,4,2,0,0,0,0,0,0,2,4,7,10,13,15,12,10,7,5,3,2,1,1,2,3,5,7,10,12,15,16,15,12,10,8,7,6,5,5,6,7,8,10,12,15,16,16,16,15,13,11,10,9,9,9,9,10,11,13,15,16,16")

function gg_reset()
	gg={
		-- 게임 상태
		is_title=true,
		is_playing=false,
		is_gameover=false,
		is_clear=false,

		-- 진행 룸
		room_no=1,
		room_no_max=5,
		
		-- 플레이어 공
		player_ball=nil,

		-- 플레이 상태
		remain_heart=5,
		remain_heart_max=5,
		remain_kick=12,
		remain_kick_max=12,

		-- 딤처리
		use_dim=true,
		dim_pow=16, -- 1~16
	}
end
gg_reset()

-- 룸 셋팅
-- todo: 세팅 간소화
function set_room(n)
	holes={}
	balls={}
	abysses={}
	boxes={}

	-- 구슬 색상 세트
	local colors={}
	colors[1]={3,6,11,6} -- 녹색(어두운,중간,하이라이트,이동자국)
	colors[2]={8,14,15,8} -- 주황색
	colors[3]={5,13,12,4} -- 포도색

	if n==1 then
		-- 홀 추가
		add(holes,{x=110,y=64,r=5})

		-- 구슬 여럿 추가
		-- gg.player_ball={x=20,y=64,r=5,sx=0,sy=0,hit_c=0,c=colors[1],is_player=true,wait_action=true}
		gg.player_ball={x=20,y=52,r=5,sx=0,sy=0,hit_c=0,c=colors[1],is_player=true,wait_action=true}
		add(balls,gg.player_ball) -- 초록 구슬
		add(balls,{x=64,y=64,r=5,sx=0,sy=0,hit_c=0,c=colors[2],is_boss=true}) -- 주황 구슬
		add(balls,{x=74,y=64-6,r=5,sx=0,sy=0,hit_c=0,c=colors[3]})
		add(balls,{x=74,y=64+6,r=5,sx=0,sy=0,hit_c=0,c=colors[3]})

		-- 심연 추가
		add(abysses,{0,0,5,4})
		add(abysses,{12,0,5,4})
		add(abysses,{-2,10,4,6})
		add(abysses,{9,12,8,4})

		-- 박스(벽) 추가
		add(boxes,{5,0,1,4})
		add(boxes,{11,0,1,4})
		add(boxes,{0,4,6,1})
		add(boxes,{7,4,1,1})
		add(boxes,{9,4,1,1})
		add(boxes,{11,4,6,1})
		add(boxes,{0,9,3,1})
		add(boxes,{4,11,1,1})
		add(boxes,{6,11,1,1})
		add(boxes,{2,10,1,7})
		add(boxes,{8,11,9,1})
		add(boxes,{8,12,1,5})

	elseif n==2 then
		-- 홀 추가
		add(holes,{x=114,y=48,r=5})

		-- 구슬 여럿 추가
		gg.player_ball={x=24,y=100,r=5,sx=0,sy=0,hit_c=0,c=colors[1],is_player=true,wait_action=true}
		add(balls,gg.player_ball) -- 초록 구슬
		add(balls,{x=74+12,y=64,r=5,sx=0,sy=0,hit_c=0,c=colors[2],is_boss=true}) -- 주황 구슬
		add(balls,{x=74-0,y=64,r=5,sx=0,sy=0,hit_c=0,c=colors[3]})
		add(balls,{x=74-12,y=64,r=5,sx=0,sy=0,hit_c=0,c=colors[3]})
		add(balls,{x=74-24,y=64,r=5,sx=0,sy=0,hit_c=0,c=colors[3]})

		-- 심연 추가
		add(abysses,{1,-2,6,7})
		add(abysses,{8,0,8,3})
		add(abysses,{7,12,9,4})

		-- 박스(벽) 추가
		add(boxes,{0,0,1,6})
		add(boxes,{1,5,6,1})
		add(boxes,{7,0,1,6})
		add(boxes,{8,3,9,1})
		add(boxes,{8,4,2,2})
		add(boxes,{0,15,6,2})
		add(boxes,{6,11,1,6})
		add(boxes,{7,11,11,1})

	elseif n==3 then
		-- 홀 추가
		add(holes,{x=76,y=36,r=5})

		-- 구슬 여럿 추가
		gg.player_ball={x=80,y=64,r=5,sx=0,sy=0,hit_c=0,c=colors[1],is_player=true,wait_action=true}
		add(balls,gg.player_ball) -- 초록 구슬
		add(balls,{x=52,y=76,r=5,sx=0,sy=0,hit_c=0,c=colors[2],is_boss=true}) -- 주황 구슬
		add(balls,{x=52,y=64,r=5,sx=0,sy=0,hit_c=0,c=colors[3]})
		add(balls,{x=40,y=64,r=5,sx=0,sy=0,hit_c=0,c=colors[3]})
		add(balls,{x=40,y=76,r=5,sx=0,sy=0,hit_c=0,c=colors[3]})

		-- 심연 추가
		add(abysses,{0,0,7,6})
		add(abysses,{-2,9,5,7})
		add(abysses,{11,12,6,5})

		-- 박스(벽) 추가
		add(boxes,{0,6,7,1})
		add(boxes,{7,0,1,7})
		add(boxes,{8,6,4,1})
		add(boxes,{10,11,7,1})
		add(boxes,{10,12,1,5})
		add(boxes,{0,7,3,2})
		add(boxes,{3,7,1,10})

	elseif n==4 then
		-- 홀 추가
		add(holes,{x=110,y=64,r=5})

		-- 구슬 여럿 추가
		gg.player_ball={x=12,y=64,r=5,sx=0,sy=0,hit_c=0,c=colors[1],is_player=true,wait_action=true}
		add(balls,gg.player_ball) -- 초록 구슬
		add(balls,{x=54,y=64,r=5,sx=0,sy=0,hit_c=0,c=colors[3]})
		add(balls,{x=64,y=64-6,r=5,sx=0,sy=0,hit_c=0,c=colors[3]})
		add(balls,{x=64,y=64+6,r=5,sx=0,sy=0,hit_c=0,c=colors[3]})
		add(balls,{x=74,y=64-12,r=5,sx=0,sy=0,hit_c=0,c=colors[3]})
		add(balls,{x=74,y=64,r=5,sx=0,sy=0,hit_c=0,c=colors[2],is_boss=true}) -- 주황 구슬
		add(balls,{x=74,y=64+12,r=5,sx=0,sy=0,hit_c=0,c=colors[3]})
		add(balls,{x=84,y=64-18,r=5,sx=0,sy=0,hit_c=0,c=colors[3]})
		add(balls,{x=84,y=64-6,r=5,sx=0,sy=0,hit_c=0,c=colors[3]})
		add(balls,{x=84,y=64+6,r=5,sx=0,sy=0,hit_c=0,c=colors[3]})
		add(balls,{x=84,y=64+18,r=5,sx=0,sy=0,hit_c=0,c=colors[3]})

		-- 심연 추가
		add(abysses,{14,0,2,4})
		add(abysses,{-2,12,7,4})
		add(abysses,{11,12,6,4})
		
		-- 박스(벽) 추가
		add(boxes,{0,0,5,2})
		add(boxes,{13,0,1,5})
		add(boxes,{14,4,3,1})
		add(boxes,{0,11,5,1})
		add(boxes,{4,5,1,1})
		add(boxes,{4,7,1,1})
		add(boxes,{4,9,1,1})
		add(boxes,{11,11,6,1})
		add(boxes,{5,15,6,2})

	elseif n==5 then
		-- 홀 추가
		add(holes,{x=114,y=54,r=5})

		-- 구슬 여럿 추가
		gg.player_ball={x=16,y=80,r=5,sx=0,sy=0,hit_c=0,c=colors[1],is_player=true,wait_action=true}
		add(balls,gg.player_ball) -- 초록 구슬
		add(balls,{x=16,y=96,r=5,sx=0,sy=0,hit_c=0,c=colors[3]})
		add(balls,{x=16,y=112,r=5,sx=0,sy=0,hit_c=0,c=colors[3]})
		add(balls,{x=32,y=112,r=5,sx=0,sy=0,hit_c=0,c=colors[2],is_boss=true}) -- 주황 구슬
		add(balls,{x=48,y=112,r=5,sx=0,sy=0,hit_c=0,c=colors[3]})

		-- 심연 추가
		add(abysses,{5,5,6,6})
		add(abysses,{12,0,8,4})

		-- 박스(벽) 추가
		add(boxes,{0,4,1,1})
		add(boxes,{2,4,1,1})
		add(boxes,{11,0,1,4})
		add(boxes,{4,4,13,1})
		add(boxes,{4,5,1,7})
		add(boxes,{6,11,1,1})
		add(boxes,{9,11,1,1})
		add(boxes,{11,5,1,7})

	end

	-- 심연, 박스는 16x16 타일로 배치하는 걸로 가정하고 좌표를 적었음
	-- 그 좌표를 실제 좌표로 미리 바꿔둔다(실시간으로 하니까 꽤 무거워서)
	for i=1,#abysses do
		local b=abysses[i]
		local x1,y1=b[1]*8,b[2]*8
		local x2,y2=x1+b[3]*8,y1+b[4]*8
		abysses[i]={x1,y1,x2,y2}
	end
	for i=1,#boxes do
		local b=boxes[i]
		local x1,y1=b[1]*8,b[2]*8
		local x2,y2=x1+b[3]*8,y1+b[4]*8
		boxes[i]={x1,y1,x2,y2}
	end
end

function _init()
	-- 팔레트는 보너스 색상과 섞어서 사용
	-- https://www.lexaloffle.com/bbs/?pid=68190#p
	pal({[0]=128,130,6,131,13,133,3,7,136,5,138,139,14,141,142,15},1)

	cls(c_bg)
	copyprevframe()
	set_room(gg.room_no)
end

-- todo: 정리해야하는디...
kick=false
kick_a=0
kick_a_acc=0
kick_pow_min=0.6
kick_pow_max=3.2
kick_pow=kick_pow_max
kick_pow_to=kick_pow_max

function _update60()
	f+=1

	-- 플레이 중에만 물리 처리
	if gg.is_playing then

		-- 공과 공, 공과 벽이 충돌한 횟수(소리 출력용)
		local hit_times_b2b=0
		local hit_times_b2w=0

		-- 가장 느린 공의 속도 기록용
		local slowest_spd=0

		-- 충돌 처리 + 이동 + 감속
		for i=1,#balls do
			local c=balls[i]
			hit_times_b2w+=bouncing_wall(c,sw,sh) -- 공과 벽 충돌
			hit_times_b2w+=bouncing_boxes(c) -- 공과 박스 충돌
			if i>1 then -- 공끼리 충돌
				for j=1,i-1 do
					local c2=balls[j]
					hit_times_b2b+=ball_collision(c,c2)
				end
			end

			-- 충돌했으면 효과음 출력
			if(hit_times_b2b>0) sfx(0) -- 공끼리 충돌음
			if(hit_times_b2w>0) sfx(1) -- 벽 충돌음

			-- 홀에 들어갔는지?
			-- todo: 홀 1번만 체크하고 있음
			c.is_ssok,c.tx,c.ty=collision_hole(c,holes[1])

			-- 심연에 빠졌는지?
			c.is_dive,c.tx,c.ty=collision_abysses(c)
			
			-- 공 이동
			c.x+=c.sx
			c.y+=c.sy

			-- 공의 속도가 충분히 느리면 0으로 만들기 + 감속
			if(c.sx!=0) c.sx=abs(c.sx)<0.05 and 0 or c.sx*0.988
			if(c.sy!=0) c.sy=abs(c.sy)<0.05 and 0 or c.sy*0.988

			-- 가장 느린 공의 속도 기록
			slowest_spd=max(max(slowest_spd,abs(c.sx)),abs(c.sy))
		end

		-- 모든 공이 충분히 느려지면 액션 대기 상태로...
		-- 단, 남은 킥 수가 없으면 게임오버
		if slowest_spd<=0 and gg.player_ball then
			if gg.remain_kick<=0 then set_gamestate("gameover") sfx(4)
			else gg.player_ball.wait_action=true end
		end

		-- 홀/심연에 들어간 공은 지운다 + 소리/이펙트 추가
		for c in all(balls) do
			if c.is_ssok then
				c.type,c.eff_timer="ball_ssok",30

				-- todo: 보스 공이 들어갔을 때 소리를 더 요란하게~
				if c.is_boss then set_gamestate("clear") sfx(3) -- 보스 공이 들어가면 클리어
				elseif c.is_player then gg.player_ball=nil set_gamestate("gameover") sfx(4) -- 플레이어 공이 들어가면 게임오버
				else sfx(3) end

				add(eff,{type="ssok",eff_timer=30,x=holes[1].x,y=holes[1].y,c=c.c[3]}) -- todo: 1번 홀만 처리하는 중
				add(eff,c) del(balls,c)

			elseif c.is_dive then
				c.type,c.eff_timer="ball_dive",30

				-- 보스나 플레이어 공이 떨어지면 게임오버
				if(c.is_boss or c.is_player) set_gamestate("gameover") 
				if(c.is_player) gg.player_ball=nil

				add(eff,c) del(balls,c)
				sfx(4)
			end
		end
	end

	-- 플레이 중의 조작
	if gg.is_playing and gg.player_ball and gg.player_ball.wait_action then
		-- Z 누르면 초록공 치기
		if btn(4) then
			if not kick and #balls>0 then
				kick=true
				balls[1].sx=cos(kick_a)*kick_pow
				balls[1].sy=sin(kick_a)*kick_pow
				gg.player_ball.wait_action=false
				gg.remain_kick-=1
				sfx(2)
			end
		else kick=false end

		-- 좌우 키로 각도(각가속도 사용)
		if btn(0) then kick_a_acc=min(0.012,kick_a_acc+0.0004)
		elseif btn(1) then kick_a_acc=max(-0.012,kick_a_acc-0.0004)
		else kick_a_acc=abs(kick_a_acc)<0.0006 and 0 or kick_a_acc*0.7 end
		kick_a+=kick_a_acc

		-- 상하 키로 파워
		if btn(2) then kick_pow_to=min(kick_pow_to+0.15,kick_pow_max)
		elseif btn(3) then kick_pow_to=max(kick_pow_to-0.15,kick_pow_min) end
		kick_pow+=(kick_pow_to-kick_pow)*0.2
	end

	-- 타이틀 화면이라면? x키 눌러서 게임 시작
	-- 게임 중이라면 x키 눌러서 타이틀로...
	if gg.is_title then
		if gg.dim_pow>=16 and btnp(5) then
			set_gamestate("play")
			sfx(8)
		end
		
	elseif gg.is_gameover then
		if gg.dim_pow>=16 and btnp(5) then
			-- 죽으면? 하트 남은 게 있으면 다시, 없으면 타이틀로...
			if gg.remain_heart>1 then
				gg.remain_heart-=1
				gg.remain_kick=gg.remain_kick_max
				set_room(gg.room_no)
				set_gamestate("play")
				sfx(8)
			else
				gg.remain_heart=gg.remain_heart_max
				gg.remain_kick=gg.remain_kick_max
				gg.room_no=1
				set_room(1)
				set_gamestate("title")
				gg.dim_pow=max(1,gg.dim_pow)
				sfx(7)
			end
		end

	elseif gg.is_clear then
		if gg.dim_pow>=16 and btnp(5) then
			-- 클리어했으면 계속 다음 룸으로...(막판이면 1로 돌아감)
			gg.room_no=(gg.room_no<gg.room_no_max) and gg.room_no+1 or 1
			gg.remain_kick=gg.remain_kick_max
			set_room(gg.room_no)
			set_gamestate("play")
			sfx(8)
		end

	elseif gg.dim_pow<=0 then -- 게임 중에는 x키 눌러서 타이틀로(임시 처리)
		if btnp(5) then
			set_gamestate("title")
			gg.dim_pow=max(1,gg.dim_pow)
			sfx(7)
		end
	end

end

function _draw()

	-- cls(c_bg)

	-- 딤 처리(화면 단색화)
	if gg.dim_pow>0 then
		if gg.use_dim then gg.dim_pow=min(gg.dim_pow+1,16)
		else gg.dim_pow=max(gg.dim_pow-1,0) end

		local s="1,9,5,9,5,5,9,5,9,9,9,9,5,5,9,1"
		s=sub(s,1,1+gg.dim_pow*2) -- 딤을 순차적으로 적용
		pal(split(s),0)
	end

	-- 이동 자국
	-- 이전 프레임의 자국을 붙여넣은 후 배경색 원, 점을 그려서 조금씩 지우는 방식
	pasteprevframe()
	for c in all(balls) do
		if(not c.is_hole) circfill(c.x,c.y,c.r*0.8,c.c[4])
	end
	for i=0,80 do
		if(i<20) circfill(rnd(sw),rnd(sh),i<8 and 2 or 1,c_bg)
		pset(rnd(sw),rnd(sh),c_bg)
	end
	copyprevframe()

	-- 배경 벽돌 무늬(cpu 0.1 먹음)
	-- todo: 좀 더 불규칙적인 느낌으로 배치하기
	for i=0,63 do
		if i%5<2 then
			local x,y=i%8*16,i\8*16
			sspr(i%2==0 and 0 or 16,16,16,16,x,y)
		end
	end

	-- 바깥벽 그림자
	palt(0,false) palt(8,true)
	for i=0,15 do
		local d=flr(i*1.3%2)*2 -- 불규칙적인 높이로
		local xy=i*8
		sspr(16,0,16,16,-8-d,xy-d)
		sspr(16,0,16,16,xy-d,-8-d)
	end
	palt()

	-- 구슬 그림자
	for c in all(balls) do
		circfill(c.x+3,c.y+3,c.r-0.5,c_sd)
	end

	-- 박스 그림자
	palt(0,false) palt(8,true)
	for b in all(boxes) do
		local x1,y1,x2,y2=get_box_coords(b)
		for i=0,(x2-x1)\8-1 do
			for j=0,(y2-y1)\8-1 do
				-- 그림자는 높이를 불규칙적으로...
				local d=flr((i+j*1.3)%2)
				sspr(16,0,16,16,x1+i*8-d+1,y1+j*8-d+1)
			end
		end
	end
	palt()

	-- 심연
	for b in all(abysses) do
		local x1,y1,x2,y2=get_box_coords(b)
		rectfill(x1,y1,x2,y2,0)
		for i=1,10 do
			local x,y=x1+i,y1+i
			if i>8 then fillp_step(2)
			elseif i>4 then fillp_step(4)
			elseif i>2 then fillp_step(8) end
			line(x+1,y,x2-1,y,5) -- 아랫면
			line(x,y+1,x,y2-1,i<=3 and 13 or 5) -- 옆면
			if(i>5 and i<11) line(x-3,y-4+1,x-3,y2-1,13) -- 옆면(더 밝은 부분)
		end
		fillp()
	end

	-- 박스(벽)
	palt(0,false) palt(8,true)
	for b in all(boxes) do
		local x1,y1,x2,y2=get_box_coords(b)
		-- 박스(sspr)
		for i=0,(x2-x1)\8-1 do
			for j=0,(y2-y1)\8-1 do
				-- 벽은 측면 하단만 보이기 때문에 높이를 조금 낮게 그림
				sspr(0,0,11,11,x1-2+i*8,y1-2+j*8)
			end
		end
	end
	palt()

	-- 홀 그리기
	palt(0,false) palt(11,true)
	for c in all(holes) do
		local x,y=flr(c.x+0.5),flr(c.y+0.5)
		sspr(32,0,13,13,x-6,y-6)
	end
	palt()

	-- 구슬 그리기
	for c in all(balls) do draw_ball(c) end

	-- 이펙트
	draw_eff()

	-- 박스 다시 그리기(구슬 앞을 가림)
	palt(0,false) palt(8,true)
	for b in all(boxes) do
		local x1,y1,x2,y2=get_box_coords(b)
		for i=0,(x2-x1)\8-1 do
			for j=0,(y2-y1)\8-1 do
				-- 높이를 불규칙적으로...
				local d=flr((i+j*1.3)%2)
				sspr(0,0,12-d,13-d,x1-4+i*8+d,y1-4+j*8+d)
			end
		end
	end
	palt()

	-- 구슬 치기 가이드
	if gg.is_playing and gg.player_ball and gg.player_ball.wait_action and f%2==0 then
		local x,y=flr(gg.player_ball.x+0.5),flr(gg.player_ball.y+0.5)
		local r=6
		circ(x,y,r,10)
		draw_dot_line(x,y,kick_a,2,12+kick_pow*12)
	end

	-- 비네팅(cpu 0.09 먹음 / 동적으로 바꾸면 0.11 먹음)
	if gg.dim_pow>0 then
		local offset=abs(t()*5%6-3)
		local ratio=((16-gg.dim_pow)/16)^3
		for i=0,15 do
			for j=0,15 do
				local d=vntt[i*16+j+1]
				if d>0 then
					-- fillp_step(flr(d-ratio*16)) -- 정적인 딤
					fillp_step(flr(d+(gg.dim_pow-16)+offset)) -- 동적인 딤
					local x,y=j*8,i*8
					rectfill(x,y,x+7,y+7,1)
				end
			end
		end
		fillp()
	end

	-- ui 그리기
	if true then
		palt(0,false) palt(2,true)
		for i=1,gg.remain_heart_max do
			local ix=2+(i-1)*8
			sspr(0,32,10,10,ix,2)
			if(i>gg.remain_heart) spr(67,ix,2)
		end

		local x,y=45,1
		local w=#tostr(gg.remain_kick)*4
		sspr(10,32,3,12,x,y)
		sspr(13,32,1,12,x+3,y,w,12)
		sspr(14,32,5,12,x+3+w,y)
		print(gg.remain_kick,x+3,y+3,0)
		
		palt()
	end


	-- (딤 처리를 했었다면) 팔레트 복원
	pal({1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,0},0)

	-- 게임오버/클리어/타이틀 화면이라면?
	if gg.is_gameover or gg.is_clear then

		local ratio=((16-gg.dim_pow)/16)^3 -- 1->0

		if gg.is_gameover then
			local d1,d2=cos(t()*0.6)*2,sin(t()*0.6)*2

			-- 남은 하트가 없으면 진짜 게임오버, 있으면 룸 재시작 가능

			local s=gg.remain_heart>1 and "\^i f a i l e d " or "\^i g a m e  o v e r "
 			s=sub(s,1,(1-ratio)*#s)
			local x,y=63-#s*2+5-d1,52-d2+ratio*10
			printos(s,x,y,8,0,0)

			s=gg.remain_heart>1 and "press ❎ to restart" or "press ❎ to title"
			-- x,y=26-d2,68+d1-ratio*10
			x,y=63-#s*2-d2,68+d1-ratio*10
			printos(s,x,y,7,0,0)
			print("❎",x+24,y,10)

		else
			local d1,d2=cos(t()*0.6)*2,sin(t()*0.6)*2
			local s="\^i room #"..gg.room_no.." clear! "
			s=sub(s,1,(1-ratio)*#s)
			local x,y=63-#s*2+5-d1,52-d2+ratio*10
			printos(s,x,y,10,0,0)

			x,y=23-d2,68+d1-ratio*10
			printos("press ❎ to next room",x,y,7,0,0)
			print("❎",x+24,y,10)
		end

	elseif gg.is_title then
		
		local ratio=((16-gg.dim_pow)/16)^3 -- 1->0
		draw_title(ratio*20)

		-- 글자
		if true then
			local d1,d2,d3=cos(t()*0.6)*2,sin(t()*0.6)*2,cos(t()*0.7)*2
			local x,y=32-d1,75-d2-ratio*10
			printos("press ❎ to play",x,y,7,0,0)
			print("❎",x+24,y,10)
		end
		
		-- 기타
		local v="v"..ver
		print(v,127-#v*4,121,9)
	
	end

	-- 디버그용
	print_log() -- debug: log
	-- draw_color_table()
	-- if(hit_count>0) stop() -- debug: 일단 멈춰보자...
end

-- 게임 (끝)
-------------------------------------------------------------------------------