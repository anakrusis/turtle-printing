-- pixel art maker, last updated 2022 November 22
-- USAGE:
-- pixelart.lua [image path]
-- pixelart.lua [image path] [x scale] [y scale]
-- pixelart.lua [image path] [x scale] [y scale] t[x][y]
-- pixelart.lua destroy [width] [height]

tArgs = {...}

x = 0; y = 0;
-- 0 is right, 1 is up, 2 left, 3 down
facing = 0

colorslots = {
	["0"] = 0, -- white is in the slot mod 0
	--b = 0, -- blue  is in the slot mod 1
	f = 1	 -- black is in the slot mod 2
}
numberofcolors = 2;

DESTROYMODE = (tArgs[1] == "destroy");
if DESTROYMODE then
	width = tArgs[2]; height = tArgs[3];
else
	SCALEX = tArgs[2] or 1; SCALEY = tArgs[3] or 1;
end

TILESIZE = 32;
TILEMODE = (tArgs[4])
-- the tile mode argument is formatted as a single word like "t12" (render the tile at 1,2)
if TILEMODE and string.sub(TILEMODE,1,1) == "t" then
	TILEX = string.sub(TILEMODE,2,2); TILEY = string.sub(TILEMODE,3,3)
	print("tx: " .. TILEX .. " ty: " .. TILEY);
	
	STARTX = (TILESIZE * TILEX) + 1;
	STARTY = (TILESIZE * TILEY) + 1;
else
	TILEMODE = false;
end

-- loads the image line by line
if not DESTROYMODE then
	image = {};
	local linecounter = 1;
	for line in io.lines(tArgs[1]) do 
		-- in tiled mode, we only load a (usually 32x32) piece of the whole image
		if TILEMODE then
			if linecounter >= STARTY and linecounter < STARTY + TILESIZE then
				local concatline = string.sub(line, STARTX, STARTX + TILESIZE - 1);
				table.insert(image, concatline);
			end
		-- otherwise we just load the whole image
		else
			table.insert(image, line);
		end
		
		linecounter = linecounter + 1;
	end
	width = #image[1];
	height = #image;
end
print("width: " .. width .. " height: " .. height)

function main()
	local sw = (width * SCALEX); local sh = (height * SCALEY)
	
	for j = 0, sh - 1 do
		for i = 0, sw - 1 do		
			-- manhattan distance to 0,0 (fuel chest)
			local mhdist = x + y;
			if (turtle.getFuelLevel() < mhdist + 20) then
				print("not enough fuel, getting items");
				goChestGetItems();
			end
			
			local sx = math.floor(x / SCALEX);
			local sy = math.floor(y / SCALEY); 
				
			local cl = image[sy + 1] -- current line
			--print("x: " .. x)
			local cc = string.sub(cl, sx + 1, sx + 1) -- current char
			
			if not DESTROYMODE then
				local slot = colorslots[cc];
				if slot then
					if not selectFirstItem(slot) then
						print("not enough wool, getting items");
						goChestGetItems();
					end
					selectFirstItem(slot)
				end
			end
			
			if DESTROYMODE then
				turtle.select(16)
				turtle.digDown();
				turtle.drop();
				
			-- space character is ignored, it's transparent
			elseif cc ~= " " then
				-- this part allows for editing on top of an existing image
				-- by removing what block was there before and replacing it only if neccessary
				local prevslot = turtle.getSelectedSlot();
				if not turtle.compareDown() then
					turtle.select(16)
					turtle.digDown();
					turtle.drop();
					turtle.select(prevslot);
				end
				turtle.placeDown();
			end
			
			if j % 2 == 0 then
				if x < sw - 1 then
					if not turtle.forward() then waitUntilCanGoForward(); end
					x = math.min(x + 1, sw - 1)
					x = math.max(x, 0);
				end
			else
				if x > 0 then
					if not turtle.forward() then waitUntilCanGoForward(); end
					x = math.min(x - 1, sw - 1)
					x = math.max(x, 0);
				end
			end
		end
		
		-- BOUSTROPHEDON: right turns on even lines, left turns on odd lines
		if y < sh - 1 then
			if j % 2 == 0 then
				turtle.turnRight()
				if not turtle.forward() then waitUntilCanGoForward(); end
				turtle.turnRight()
				facing = 2
			else
				turtle.turnLeft()
				if not turtle.forward() then waitUntilCanGoForward(); end
				turtle.turnLeft()
				facing = 0
			end
			y = y + 1
		end
	end
	
	goToOrigin();
	-- and face right at the end
	turtle.turnRight()
	turtle.turnRight()
end

function selectFirstItem(modnum)
	for i = 0, 15 do
		if (i % numberofcolors == modnum) then
			 if turtle.getItemCount( i + 1 ) > 0 then
				turtle.select( i + 1 )
				return true;
			 end
		end
	end
	return false;
end

function goChestGetItems()
	goToOrigin();
	-- the turtle should be at 0,0 now
	turtle.turnRight()
	-- should be facing up toward the fuel chest now
	-- fuel slot is the last slot
	turtle.select(16)
	
	-- we dont want to go over a stack of fuel at a time, otherwise slot 1 will get it too, messing everything up
	local fuelcount = turtle.getItemCount();
	while turtle.suckUp(64 - fuelcount) and turtle.getFuelLevel() < turtle.getFuelLimit() do
		turtle.refuel();
	end
	-- puts back any coal in the 16th slot back into the chest
	turtle.dropUp();
	turtle.turnRight()
	
	-- now it will go to each wool chest and fill it to the max
	if not DESTROYMODE then
		for i = 0, numberofcolors - 1 do
			if not turtle.forward() then waitUntilCanGoForward(); end
			
			-- we pull only a stack to each slot. otherwise it will spill over into the next slot
			-- also we stop at 15 not 16 because the 16th slot will be reserved for fueling
			for slot = i + 1, 15, numberofcolors do
				turtle.select(slot)
				local itemcount = turtle.getItemCount();
				turtle.suckUp(64 - itemcount);
			end
		end
		-- returning back to the square (0,0)
		for i = 0, numberofcolors - 1 do
			turtle.back();
		end
	end
	returnToPos();
end

function goToOrigin()
	-- first face up
	if facing == 2 then
		turtle.turnRight()
	elseif facing == 0 then
		turtle.turnLeft()
	end
	for i = 1, y do
		if not turtle.forward() then waitUntilCanGoForward() end
	end
	-- and to the left
	turtle.turnLeft()
	for i = 1, x do
		if not turtle.forward() then waitUntilCanGoForward() end
	end
end

-- have it facing to the right before you call this
function returnToPos()
	for i = 1, x do
		if not turtle.forward() then waitUntilCanGoForward() end
	end
	turtle.turnRight();
	for i = 1, y do
		if not turtle.forward() then waitUntilCanGoForward() end
	end
	-- will be facing down at the end of this, so has to be reoriented
	if facing == 2 then
		turtle.turnRight()
	elseif facing == 0 then
		turtle.turnLeft()
	end
end

function waitUntilCanGoForward()
	print("can't move forward! waiting...");
	local prevslot = turtle.getSelectedSlot();
	turtle.select(16)
	while not turtle.forward() do
		turtle.dig();
		turtle.drop();
	end
	turtle.select(prevslot);
end

local starttime = os.clock();

main();

local endtime = os.clock();
local elapsed = endtime - starttime;

print("\nFinished in " .. math.floor(elapsed / 60) .. "m " .. math.floor(elapsed % 60) .. "s");
