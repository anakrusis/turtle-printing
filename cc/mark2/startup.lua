-- TurtlePrint
-- last edited 2022 december 4

status = {
	-- 0 is east, 1 is north, 2 west, 3 south
	facing = 1,
	pos = { x = 193, z = -887 },
	woolcount = 0,
	assignedcolor = nil,
	taskindex = nil
}

tpdepotid = nil;

function main()

	-- cant leave the depot without a little kickstart, won't even bother connecting without that
	if turtle.getFuelLevel() < 50 then
		print("Not enough fuel to init, exiting...")
		return
	end

	-- initial connection
	rednet.open("left");
	print("Waiting for connection to server...");
	while not tpdepotid do
		tpdepotid = rednet.lookup("turtleprint","tpdepot")
		os.sleep(1);
	end
	print("Connected!")

	-- we request an absolute position given our parking spot
	print("What parking spot am I in?")
	local spot = io.read();
	spot = tonumber(spot);
	if not spot then
		print("Invalid spot number!"); return
	end
	status.spot = math.floor(spot);
	rednet.send(tpdepotid, spot, "tp_requestpos");
	
	-- immediately expects two responses: where it is and where all the important landmarks are
	local id, message, protocol = rednet.receive("tp_pos");
	status.pos = message;
	print("I am located at x: " .. status.pos.x .. " y: " .. status.pos.y .. " z: " .. status.pos.z);
	local id, message, protocol = rednet.receive("tp_landmarks");
	LANDMARKS = message;
	
	while true do
		-- turtle is ready to start receiving commands
		rednet.send(tpdepotid, status, "tp_requesttask");
		local id, message, protocol = rednet.receive("tp_task");
		local ct = message -- current task
		
		-- no task was found:
		--all tasks have turtles working on them already,
		-- or the image is done rendering completely. so just go home
		if not ct then
			status.taskindex = nil;
			goToPos(LANDMARKS.parking.x + status.spot, LANDMARKS.parking.z + status.spot);
			face(1)
			print("No more tasks! Ending program...")
			return;
		end
		
		status.taskindex = ct.index;
		print("New task index: " .. status.taskindex);
		
		-- color change indicated by task
		if ct.color ~= status.assignedcolor then
			-- if turtle has already been assigned a color, then they already have gotten wool
			-- so the leftover wool still in inventory will have to go to the return chest to be recirculated
			if status.assignedcolor ~= nil then
				goToLandmark( "ret" )
				for i = 1, 16 do
					turtle.select( i );
					turtle.dropUp();
				end
			end
			
			status.assignedcolor = ct.color;
			print("New color assigned: " .. ct.color);
			
			-- shouldn't be needed to grab the new colored wool here since the placePixelAtPos function
			-- already checks and restocks if there isnt enough wool to complete task
			
			--goToLandmark( ct.color )
			--restockWool();
		end
		
		for i = 1, #ct.items do
			local ci = ct.items[i];
			placePixelAtPos(ci.x, ci.z);
		end
		
		-- let the server know we're done so it can mark the task complete on its end
		rednet.send(tpdepotid, status, "tp_taskcomplete");
	end
end

function placePixelAtPos(x, z)
	-- TODO check wool count on a taskwide basis, not every pixel (its slow to change slots this much)
	-- finds the first item slot with stuff in it
	local itemfound = false;
	for i = 1, 15 do
		if turtle.getItemCount( i ) > 0 then
			turtle.select( i ); itemfound = true; break;
		end	
	end
	
	-- NO ITEMS?? go back to depot
	if not itemfound then
		
		print("Not enough wool-- getting wool");
		goToPos(LANDMARKS[ status.assignedcolor ].x, LANDMARKS[ status.assignedcolor ].z)
		restockWool();
	end
	
	goToPos(x,z)
	
	-- breaks block if not matching
	-- TODO have a separate turtle who scans for nonmatching blocks, picks them up
	-- and brings them back to return chest
	local prevslot = turtle.getSelectedSlot();
	if not turtle.compareDown() then
		turtle.select(16)
		turtle.digDown();
		turtle.drop();
		turtle.select(prevslot);
	end
	
	turtle.placeDown();
end

-- This is a recursive function that calls itself for refueling and returning
function goToPos(x, z)
	if not ( x == LANDMARKS.fuel.x and z == LANDMARKS.fuel.z ) then
		-- If the distance to get to the fuel place + the target square is more than what fuel is left
		-- then go immediately to get fuel before even trying to go to the target square
		
		local targdist = distance(x,z,status.pos.x,status.pos.z);
		local targtofueldist = distance(LANDMARKS.fuel.x, LANDMARKS.fuel.z,x,z);
		-- plus 20 extra blocks just in case
		local cushion  = 20;
		if targdist + targtofueldist + cushion > turtle.getFuelLevel() then
			
			print("Not enough fuel-- getting fuel");
			goToPos( LANDMARKS.fuel.x, LANDMARKS.fuel.z );
			refuel();
		end
	end

	-- ONLY if z position differs
	if z ~= status.pos.z then
		local step;
		if z > status.pos.z then
			face(3); step = 1;
		elseif z < status.pos.z then
			face(1); step = -1;
		end
		local zdiff = math.abs(z - status.pos.z);
		for i = 1, zdiff do			
			forward();	status.pos.z = status.pos.z + step;
		end
	end
	
	-- ONLY if x position differs
	if x ~= status.pos.x then
		local step;
		if x > status.pos.x then
			face(0); step = 1;
		elseif x < status.pos.x then
			face(2); step = -1;
		end
		local xdiff = math.abs(x - status.pos.x);
		for i = 1, xdiff do	
			forward();	status.pos.x = status.pos.x + step;
		end
	end
end

function goToLandmark( landmarkname )
	goToPos( LANDMARKS[landmarkname].x, LANDMARKS[landmarkname].z );
end

function refuel()
	-- fuel slot is the last slot
	turtle.select(16)
	
	-- we dont want to go over a stack of fuel at a time, otherwise slot 1 will get it too, messing everything up
	local fuelcount = turtle.getItemCount();
	while turtle.suckUp(64 - fuelcount) and turtle.getFuelLevel() < turtle.getFuelLimit() do
		turtle.refuel();
	end
	-- excess coal in the sixteenth slot goes to the separate return chest that recirculates it back into the ME
	goToLandmark( "ret" );
	turtle.dropUp();
end

function restockWool()
	-- TODO deal with stacks when an item is in there that doesnt stack with it, in case something weird happens
	for i = 1, 15 do
		turtle.select(i)
		turtle.suckUp(64 - turtle.getItemCount());
	end
end

function forward()
	if turtle.forward() then return true end
	
	print("can't move forward! waiting...");
	rednet.send(tpdepotid, status, "tp_reportcollision");
	
	-- should immediately receive back a command to move up if needed, otherwise do nothing
	local id, message, protocol = rednet.receive("tp_moveup", 3);
	if (message) then
		print("message: " .. message)
		print("turtle moving up now")
		
		-- todo fixx this broken for loop "if turtle.up else while not ... "
		while not turtle.up() do
			os.sleep(2)
		end
		while not turtle.down() do
			os.sleep(2)
		end
	else
		print("no message")
	end	
	
	-- after having either moved up or not, it will now idle and hope that another turtle has moved out the way
	while not turtle.forward() do
		os.sleep(2)
	end
	
	rednet.send(tpdepotid, status, "tp_collisionresolved");
end

function face(targetdir)
	rightturns = ( status.facing - targetdir ) % 4
	leftturns  = ( targetdir - status.facing ) % 4
	
	if rightturns < leftturns then
		for i = 1, rightturns do
			turtle.turnRight()
		end
	else
		for i = 1, leftturns do
			turtle.turnLeft()
		end
	end
	status.facing = targetdir
end

-- manhattan distance between two blocks at the same y level
function distance(x1,z1,x2,z2)
	return math.abs( x1 - x2 ) + math.abs( z1 - z2 );
end

main()
