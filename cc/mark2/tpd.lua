-- TurtlePrint Depot
-- last edited 2022 december 4

-- USAGE:
-- tpd [image path] x z

tArgs = {...}

CHUNKHEIGHT = 8;
CHUNKWIDTH	= 8;

LANDMARKS = {
	parking = {
		x = 193, y = 57, z = -887
	},
	fuel = {
		x = 189, z = -886
	},
	["0"] = {
		x = 188, z = -885
	},
	f = {
		x = 187, z = -884
	},
	b = {
		x = 186, z = -883
	},
	ret = {
		x = 185, z = -882
	}
}

-- indexed by their id
turtles = {

}

-- list with id numbers
collisionreports = {

}

-- each task is structured like:
-- 	{
--		assigned = false,
--		color = "b",
--		completed = false,
--		index = 1,
--		items = { 					-- a list
--			{
--				x = 170, z = -860
--			},
--			{
--				x = 171, z = -860
--			}
--		}
-- 	}
tasks = {};

-- top left corner of the image being drawn
IMAGE_ORIGINX = tArgs[2]
IMAGE_ORIGINZ = tArgs[3]

function main()
	rednet.open("top");
	rednet.host("turtleprint", "tpdepot")
	
	-- image load
	image = {};
	for line in io.lines(tArgs[1]) do 
		table.insert(image, line);
	end
	width = #image[1];
	height = #image;
	print("width: " .. width .. " height: " .. height)
	
	splitImageIntoTasks(image);
	
	while true do
		local id, message, protocol	= rednet.receive();
		
		if protocol == "tp_requestpos" then
			local location = { 
				x = LANDMARKS.parking.x + message , 
				y = LANDMARKS.parking.y, 
				z = LANDMARKS.parking.z + message
			}
			rednet.send(id, location,  "tp_pos");
			rednet.send(id, LANDMARKS, "tp_landmarks");
		end
		
		-- turtle knows where it is and is ready to receive a task.
		-- turtle sends the entire status object over for us to read
		if protocol == "tp_requesttask" then
			local currstatus = message;
			turtles[id] = currstatus;
			
			local task = assignTask(currstatus)
			if (task) then
				tasks[task.index].assigned = true;
			end
			
			rednet.send(id, task,  "tp_task");
			
			-- once we start sending nil tasks to turtles ("nothing more to assign to you"),
			-- we know we are nearly at the end. check to see how many more tasks are uncompleted
			-- if all is finished, then exit the program
			if (not task) then
				local alltasksdone = true
				for i = 1, #tasks do
					if not tasks[i].completed then
						alltasksdone = false; break;
					end
				end
				
				if alltasksdone then
					print("Image completed! ending program..."); 
					rednet.close("top");
					return
				end
			end
		end
		
		-- turtle finished a task
		if protocol == "tp_taskcomplete" then
			local currstatus = message;
			turtles[id] = currstatus;
			
			tasks[currstatus.taskindex].completed = true;
		end
		
		if protocol == "tp_reportcollision" then
			local currstatus = message;
			turtles[id] = currstatus;
			
			print("Collision reported by turtle id " .. id);
			
			-- the other turtle you're colliding with, if it exists
			local othercollidingturtstatus = nil;
		
			-- look for two things while searching the collision reports...
			local idalreadyfound = false;
			
			print("Reports:\n" .. textutils.serialize( collisionreports ) )
			
			for i = 1, #collisionreports do
				-- 1. 	redundant id's of colliding turtles are not added twice
				-- 		(this is just a safety measure so theres only one when we go to remove them)
				if id == collisionreports[i] then
					idalreadyfound = true;
				
				-- 2. 	any adjacent turtles (Manhattan distance == 1) that also reported a collision
				--		** who are also facing opposite direction as the current turtle
				else
					local otherturtstatus = turtles [ collisionreports[i] ];
					local dist = distance(otherturtstatus.pos.x, otherturtstatus.pos.z, currstatus.pos.x, currstatus.pos.z);
					local oppositefacing = ( currstatus.facing - otherturtstatus.facing ) % 4 == 2
					
					print(collisionreports[i] .. ": " .. dist);
					
					-- this must be the one (i hope!)
					if (dist == 1) and oppositefacing then
						othercollidingturtstatus = otherturtstatus;
						break;
					end
				end
			end
			
			if not idalreadyfound then table.insert(collisionreports, id) end
			
			if othercollidingturtstatus then
				print("Other turtle colliding, " .. id .. " will move");
				rednet.send(id, "up",  "tp_moveup");
			else
				print("No other turtle found colliding");
			end
		end
		
		-- if a collision report still remains under this id, we remove it
		if protocol == "tp_collisionresolved" then
			local matchingindex = nil
			for i = 1, #collisionreports do
				if collisionreports[i] == id then
					matchingindex = i; break;
				end
			end
			if matchingindex then
				table.remove(collisionreports, matchingindex)
			end
			
			print("Collision resolved, says turtle id " .. id);
		end
	end
end

-- returns a task object ready to be sent over
function assignTask( turtlestatus )
	-- first, the unassigned tasks must be separated from the assigned ones
	-- (NOTE: this is a deliberately shallow copy)
	local unassigned_tasks = {};
	for i = 1, #tasks do
		local ct = tasks[i] -- current task
		if not ct.assigned then
			table.insert(unassigned_tasks, ct)
		end
	end
	
	-- if no unassigned tasks exist, then that means all tasks have turtles working on them already,
	-- or the image is done rendering completely. so just return false
	if (#unassigned_tasks == 0) then
		return false;
	end
	
	-- if an unassigned task exists which matches the assigned color of the turtle in question
	-- then assign it and return. saves tons of time having to go back to the depot to get different wool
	for i = 1, #unassigned_tasks do
		local ct = unassigned_tasks[i]
		if (not ct.assigned) and ( ct.color == turtlestatus.assignedcolor ) then
			return ct;
		end
	end
	
	-- otherwise, no tasks match the turtle's current assigned color, so just assign a random task
	local taskindex = math.random(1, #unassigned_tasks);
	return unassigned_tasks[taskindex];
end

-- void function, clears the tasks table and fills it with new tasks
function splitImageIntoTasks(image)
	-- image is splitted into smaller (16x16) sub images called chunks
	local chunkcountx = math.ceil( width  / CHUNKWIDTH );
	local chunkcounty = math.ceil( height / CHUNKHEIGHT );
	local chunks = {};
	for cy = 0, chunkcounty - 1 do
		for cx = 0, chunkcountx - 1 do
		
			local startx = (CHUNKWIDTH  * cx) + 1;
			local starty = (CHUNKHEIGHT * cy) + 1;
			local currentchunk = {};
		
			for y = starty, starty + CHUNKHEIGHT - 1 do
				local concatline;
				if not image[y] then
					concatline = string.rep(" ", CHUNKWIDTH)
				else
					concatline = string.sub(image[y], startx, startx + CHUNKWIDTH - 1);
					local cll = #concatline
					concatline = concatline .. string.rep(" ", CHUNKWIDTH - cll);
				end
				table.insert(currentchunk, concatline);
			end
			
			table.insert(chunks, currentchunk);
		end
	end
	
	-- separating the colors of each chunk into their own tasks
	tasks = {};
	totaltaskindex = 1; -- a count of all tasks across all chunks
	
	for i = 1, #chunks do
		local currentchunk = chunks[i];
		-- only the tasks present in this chunk, which will be added to the main task list at the end
		local currentchunktasks = {};
		
		for py = 1, #currentchunk do
			local currentline = currentchunk[py];
			local chunkx = ((i - 1) % chunkcountx)
			local chunky = math.floor((i - 1) / chunkcountx)
			
			-- the order of tasks in every other line is horizontally flipped
			-- this recreates the boustrophedon (back and forth) motion that is twice as fast as raster scanning
			local startcol; local endcol; local step;
			if (py - 1) % 2 == 0 then
				startcol = 1; endcol = #currentline; step = 1;
			else
				startcol = #currentline; endcol = 1; step = -1;
			end
			
			for px = startcol, endcol, step do
				local currentchar = string.sub(currentline, px, px)
				-- transparent pixels are ignored
				if currentchar ~= " " then
				
					-- the current chunk's tasks are indexed with a key of their color name
					-- this way the pixels are sorted into their respective colors
					if not currentchunktasks[ currentchar ] then
						currentchunktasks [ currentchar ] = { color = currentchar, items = {} }
					end
				
					local newtaskitem = {
						x = IMAGE_ORIGINX + (CHUNKWIDTH  * chunkx) + (px - 1),
						z = IMAGE_ORIGINZ + (CHUNKHEIGHT * chunky) + (py - 1)
					}
					table.insert(currentchunktasks[ currentchar ].items, newtaskitem)
				end
			end
		end
		
		-- now that this chunk's tasks are written, we can add these tasks to the main tasks list
		-- here is also where I add tracking to each task
		for k, v in pairs(currentchunktasks) do
			v.assigned = false; v.completed = false; v.index = totaltaskindex;
			table.insert(tasks, v);
			totaltaskindex = totaltaskindex + 1
		end
	end
	
	local ts = textutils.serialize( tasks )
	local file = io.open("tasks", "w");
	file:write(ts)
	file:close()
	
	return
end

function getTurtleFromSpot(spot)
	
end

-- manhattan distance between two blocks at the same y level
function distance(x1,z1,x2,z2)
	return math.abs( x1 - x2 ) + math.abs( z1 - z2 );
end

main()
