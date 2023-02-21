-- 2022-02-18 사각형이랑 충돌하기 구현 중. 네 변이랑 위쪽 모서리 충돌까지만 진행함.
-- sw,sh=480,270
sw,sh=128,128
cx,cy=sw/2,sh/2
f=0
c_bg=9 -- bg color
c_sd=5 -- shadow color

-------------------------------------------------------------------------------
-- log
log_txt={}
function print_log()
	if(#log_txt<=0) return nil
	for i=#log_txt,max(1,#log_txt-15),-1 do
		print(log_txt[i],4,4+(#log_txt-i)*7,14)
	end
end
function log(s) add(log_txt,s) end
-- log (끝)
-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
-- 물리 처리

-- 원과 벽의 충돌 처리
function bouncing_wall(c,w,h)
	if(c.x<c.r) c.sx*=-1 c.x+=(c.r-c.x)*2 c.hit_c=3
	if(c.x>w-c.r) c.sx*=-1 c.x-=(c.r-(w-c.x))*2  c.hit_c=3
	if(c.y<c.r) c.sy*=-1 c.y+=(c.r-c.y)*2  c.hit_c=3
	if(c.y>h-c.r) c.sy*=-1 c.y-=(c.r-(h-c.y))*2  c.hit_c=3
end

-- 원과 점의 충돌 처리
function bouncing_point(c,px,py)
	if((px-c.x)^2+(py-c.y)^2>c.r^2) return nil

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
		local push_dist=c.r-dist_now -- 밀어내야할 거리
		a_hit=atan2(px-c.x,py-c.y)
		c.x-=cos(a_hit)*push_dist
		c.y-=sin(a_hit)*push_dist

		-- debug: 초록공이면 멈춰보자
		-- if(c.is_player) hit_count=1
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
end

-- 원과 박스의 충돌 처리
function bouncing_boxes(c)
	for b in all(boxes) do
		-- local x1,y1,x2,y2=b[1],b[2],b[3],b[4]
		local x1,y1=b[1]*8,b[2]*8
		local x2,y2=x1+b[3]*8,y1+b[4]*8
		-- 좌우 + 모서리
		if c.y+c.r>y1 and c.y-c.r<y2 then
			if c.y>y1 and c.y<y2 then -- 좌우 벽면
				if c.x<x1 and c.x+c.r>x1 then
					c.sx*=-1
					c.x-=(c.x+c.r-x1)*2
					c.hit_c=3
				elseif c.x>x2 and c.x-c.r<x2 then
					c.sx*=-1
					c.x+=(x2-c.x+c.r)*2
					c.hit_c=3
				end
			elseif c.y<=y1 then -- 상단 모서리
				if c.x<=x1 then bouncing_point(c,x1,y1) -- 좌상 
				elseif c.x>=x2 then bouncing_point(c,x2,y1) end -- 우상
			else -- 하단 모서리
				if c.x<=x1 then bouncing_point(c,x1,y2) -- 좌하
				elseif c.x>=x2 then bouncing_point(c,x2,y2) end -- 우하
			end
		end
		-- 상하
		if c.x>x1 and c.x<x2 then
			if c.y<y1 and c.y+c.r>y1 then
				c.sy*=-1
				c.y-=(c.y+c.r-y1)*2
				c.hit_c=3
			elseif c.y>y2 and c.y-c.r<y2 then
				c.sy*=-1
				c.y+=(y2-c.y+c.r)*2
				c.hit_c=3
			end
		end
	end
end

-- 두 원의 충돌 처리(질량은 동일하다고 가정)
function circ_collision(c1,c2)
	local rr=c1.r+c2.r
	if(abs(c1.x-c2.x)>rr or abs(c1.y-c2.y)>rr) return -- x, y 좌표 거리가 멀면 충돌 아님
	local dx,dy=c2.x-c1.x,c2.y-c1.y
	local dd=dx*dx+dy*dy
	if(dd>rr*rr) return -- 거리가 두 원의 반지름 합보다 짧아야 충돌(제곱근 사용하지 않고 판정부터 빠르게 처리)
	
	c1.hit_c=3
	c2.hit_c=3

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
		local push_dist=(c1.r+c2.r-dist_now)/2 -- 밀어내야할 거리
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
	local len0=t()%0.25*4*(dot1+dot2)
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

-- 정사각형 큐브 그리기
function draw_cube_7x7(x,y)
	-- local c1,c2,c3=3,6,11 -- 초록
	local c1,c2,c3=4,2,7 -- 회색
	-- local c1,c2,c3=5,13,12 -- 보라
	-- c1,c2,c3=8,14,15 -- 주황

	local x2,y2=x+6,y+6
	rectfill(x,y,x2,y2,c2)
	for i=0,2 do
		line(x+i,y+i,x2-i,y+i,c3)
		line(x+i,y2-i,x2-i,y2-i,c1)
	end
	line(x2+1,y,x2+1,y2+1,0)
	line(x,y2+1,x2+1,y2+1,0)
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

-- 기타 (끝)
-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
-- 게임

hit_count=0 -- 디버그용

function _init()
	cls(c_bg)
	copyprevframe()

	-- 구슬 색상 세트
	local colors={}
	colors[1]={3,6,11,6} -- 녹색(어두운,중간,하이라이트,이동자국)
	colors[2]={8,14,15,8} -- 주황색
	-- colors[3]={2,13,12,5} -- 포도색
	colors[3]={5,13,12,4} -- 포도색

	-- 홀 추가
	holes={}
	add(holes,{x=104,y=64,r=5,})

	-- 구슬 여럿 추가
	circles={}
	add(circles,{x=12,y=64,r=5,sx=0,sy=0,hit_c=0,c=colors[1],is_player=true}) -- 초록 구슬
	add(circles,{x=54,y=64,r=5,sx=0,sy=0,hit_c=0,c=colors[3]})
	add(circles,{x=64,y=64-6,r=5,sx=0,sy=0,hit_c=0,c=colors[3]})
	add(circles,{x=64,y=64+6,r=5,sx=0,sy=0,hit_c=0,c=colors[3]})
	add(circles,{x=74,y=64-12,r=5,sx=0,sy=0,hit_c=0,c=colors[3]})
	add(circles,{x=74,y=64,r=5,sx=0,sy=0,hit_c=0,c=colors[2]}) -- 주황 구슬
	add(circles,{x=74,y=64+12,r=5,sx=0,sy=0,hit_c=0,c=colors[3]})
	add(circles,{x=84,y=64-18,r=5,sx=0,sy=0,hit_c=0,c=colors[3]})
	add(circles,{x=84,y=64-6,r=5,sx=0,sy=0,hit_c=0,c=colors[3]})
	add(circles,{x=84,y=64+6,r=5,sx=0,sy=0,hit_c=0,c=colors[3]})
	add(circles,{x=84,y=64+18,r=5,sx=0,sy=0,hit_c=0,c=colors[3]})
	--[[ for i=1,0 do
		local c={}
		c.x=14+(i-1)%5*24
		c.y=20+flr((i-1)/5)*30
		c.r=5
		c.c=colors[min(i,3)]
		local dir,spd=rnd(),1.6+i*0.1
		c.sx=cos(dir)*spd
		c.sy=sin(dir)*spd
		c.hit_c=0
		add(circles,c)
	end ]]

	
	
	-- 박스 추가
	boxes={}
	add(boxes,{8,3,3,1})
	add(boxes,{11,4,1,1})
	add(boxes,{12,5,1,1})
	add(boxes,{12,10,1,1})
	add(boxes,{11,11,1,1})
	add(boxes,{8,12,3,1})

	-- 팔레트는 보너스 색상과 섞어서 사용
	-- https://www.lexaloffle.com/bbs/?pid=68190#p
	pal({[0]=128,129,6,131,13,133,3,7,136,5,138,139,14,141,142,15},1)
end

kick=false
kick_ready_t=0
kick_a=0
kick_a_acc=0
kick_pow_min=1
kick_pow_max=4.2
kick_pow=kick_pow_max

function _update60()
	f+=1

	-- 충돌 처리
	for i=1,#circles do
		local c=circles[i]
		bouncing_wall(c,sw,sh) -- 원과 벽 충돌
		bouncing_boxes(c) -- 원과 박스 충돌
		if i>1 then -- 원끼리 충돌
			for j=1,i-1 do
				local c2=circles[j]
				circ_collision(c,c2)
			end
		end
		c.x+=c.sx
		c.y+=c.sy
		if(c.sx!=0) c.sx=abs(c.sx)<0.05 and 0 or c.sx*0.988
		if(c.sy!=0) c.sy=abs(c.sy)<0.05 and 0 or c.sy*0.988
	end
	
	-- Z 누르면 초록공 치기
	if btn(4) then
		if not kick then
			kick=true
			kick_ready_t=0
			circles[1].sx=cos(kick_a)*kick_pow
			circles[1].sy=sin(kick_a)*kick_pow
		end
	else kick=false end

	-- 화살표 키
	if btn(0) or btn(1) or btn(2) or btn(3) then
		kick_ready_t=60
		-- 좌우 키로 각도
		if btn(0) then kick_a_acc=min(0.4,kick_a_acc+0.0015)
		elseif btn(1) then kick_a_acc=max(-0.4,kick_a_acc-0.0015) end
		-- 상하 키로 파워
		if btn(2) then kick_pow+=(kick_pow_max-kick_pow)*0.04
		elseif btn(3) then kick_pow+=(kick_pow_min-kick_pow)*0.04 end
	else
		kick_ready_t=max(0,kick_ready_t-1)
	end
	kick_a+=kick_a_acc
	kick_a_acc=abs(kick_a_acc)<0.0006 and 0 or kick_a_acc*0.80
end

function _draw()
	cls(c_bg)

	-- 이동 자국
	-- 이전 프레임의 자국을 붙여넣은 후 배경색 원, 점을 그려서 조금씩 지우는 방식
	pasteprevframe()
	for c in all(circles) do
		if(not c.is_hole) circfill(c.x,c.y,c.r*0.8,c.c[4])
	end
	for i=0,80 do
		if(i<20) circfill(rnd(sw),rnd(sh),i<8 and 2 or 1,c_bg)
		pset(rnd(sw),rnd(sh),c_bg)
	end
	copyprevframe()

	-- 배경 무늬
	-- fillp(0b1000100010000100.1) for i=1,4 do circ(sw/2,sh/2,i*20,0) end
	-- fillp(0b0100001000001001.1) for i=1,4 do circ(sw/2,sh/2,i*20-10,0) end
	-- fillp()

	-- 배경 격자 점 패턴
	-- for i=0,224 do
	-- 	local x=i%15*8+7
	-- 	local y=i\15*8+7
	-- 	pset(x,y,0)
	-- end

	-- 배경 격자 X 패턴
	-- for i=0,143 do
	-- 	local x=i%12*10+6
	-- 	local y=i\12*10+6
	-- 	line(x,y,x+4,y+4,c_sd)
	-- 	line(x+4,y,x,y+4,c_sd)
	-- end

	-- 배경 패턴
	for i=0,287 do
		local x=i%12*10+5
		local y=i\12*5+5
		if i\12%2==0 then line(x,y,x+2,y+2,c_sd)
		else x+=7 line(x,y,x-2,y+2,c_sd) end
	end

	-- 구슬 그림자
	for c in all(circles) do
		circfill(flr(c.x+2.5),flr(c.y+2.5),c.r-0.5,c_sd)
	end

	-- 박스+그림자
	for b in all(boxes) do
		-- local x1,y1,x2,y2=b[1],b[2],b[3],b[4]
		local x1,y1=b[1]*8,b[2]*8
		local x2,y2=x1+b[3]*8,y1+b[4]*8
		-- 전체 그림자
		pset(x2+1,y1+1,c_sd)
		pset(x1+1,y2+1,c_sd)
		local d=2
		for i=1,d do
			line(x2+1,y1+1+i,x2+1+i,y1+1+i,c_sd)
			line(x1+1+i,y2+1,x1+1+i,y2+1+i,c_sd)
		end
		rectfill(x1+d+2,y1+d+2,x2+d+2,y2+d+2,c_sd)

		-- 박스
		for i=0,(x2-x1)\8-1 do
			for j=0,(y2-y1)\8-1 do
				draw_cube_7x7(1+x1+i*8,1+y1+j*8)
			end
		end
		rect(x1,y1,x2,y2,0) -- outline
	end

	-- 홀 그리기
	for c in all(holes) do
		local x,y=flr(c.x+0.5),flr(c.y+0.5)
		circ(x+1,y,c.r,4)
		circ(x,y+1,c.r,4)
		circ(x,y-1,c.r,5)
		circ(x-1,y,c.r,5)
		circfill(x,y,c.r,0)
		-- circfill(x,y,c.r-2,5)
		-- circfill(x,y+1,c.r-2,5)
		-- circfill(x+1,y,c.r-2,5)
		-- circfill(x+1,y+1,c.r-2,5)
		-- circ(x,y,c.r-f%40/10,5)
	end

	-- 구슬 그리기
	for c in all(circles) do
		local x,y=flr(c.x+0.5),flr(c.y+0.5)

		-- 충돌하면 색을 밝게
		local c1,c2,c3,c4=c.c[1],c.c[2],c.c[3],0
		if c.hit_c>2 then c1,c2,c3,c4=c.c[3],c.c[3],7,c.c[2]
		elseif c.hit_c>0 then c1,c2,c3,c4=c.c[2],c.c[3],7,0 end
		
		circfill(x,y,c.r,c4) -- outline
		circfill(x,y,c.r-1,c1)
		circfill(x-1,y-1,c.r-2,c2)
		line(x-3,y-2,x-1,y-2,c3)
		line(x-2,y-3,x-2,y-1,c3)

		if(c.hit_c>0) c.hit_c-=1
	end

	-- 구슬 칠 방향 그리기
	if kick_ready_t>0 and f%2==0 then
		local c=circles[1]
		draw_dot_line(c.x,c.y,kick_a,2,10+kick_pow*13)
	end

	-- 디버그용
	-- print_log() -- debug: log
	-- draw_color_table()
	-- if(hit_count>0) stop() -- debug: 일단 멈춰보자...
end

-- 게임 (끝)
-------------------------------------------------------------------------------