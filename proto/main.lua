BLOCK_AIR = 0;
BLOCK_WOOL = 35;
BLOCK_TURTLE = 1634;

function love.load()
	local WORLDSIZE = 512
	world = {};
	for x = -WORLDSIZE, WORLDSIZE do
		world[x] = {}
		for y = -WORLDSIZE, WORLDSIZE do
		
			woolblock = {
				blocktype	= BLOCK_WOOL,
				metatype 	= 11
			}
		
			world[x][y] = {}
			world[x][y][0] = woolblock;
		end
	end

end

function love.update(dt)

end

function love.draw()

end