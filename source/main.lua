import("CoreLibs/graphics")
import("CoreLibs/sprites")
local Util = import("util")

local gfx = playdate.graphics

local paddle
local ball

local aim = 0

BRICK = 16

-- screen

SCREEN_WIDTH = 400
SCREEN_HEIGHT = 240

local screenBorder = { top = 30, bottom = 20, left = 20, right = 20 }

-- wall

local wallSize = 10

-- ball

local ballDirection = { x = 1, y = -1 }

local ballSpeedMin = 3
local ballSpeedMax = 10
local ballSpeedIncrease = 0.3
local ballSpeedCurrent = ballSpeedMin
local ballSpeedBoost = 0
local ballBoostPaddleSpeedMin = 5
local ballSpeedBoostMax = 10
local ballSpeedBoostMin = 0
local ballSpeedBoostDecrease = 0.3

local ballPaddleAngleInfluenceFraction = 0.8
local ballPaddleSpeedInfluenceFraction = 0.3

-- paddle

local paddleInitialPosition = {
	x = SCREEN_WIDTH / 2,
	y = SCREEN_HEIGHT - screenBorder.bottom,
}

local paddleWidthBricks = 4

local paddleSpeedMin = 1
local paddleSpeedMax = 20
local paddleSpeedCurrent = paddleSpeedMin

-- UI

local score
local highscore = playdate.datastore.read("highscore") or 0
local currentLevel
local lifes

-- levels
local levels = import("levels")

local bricksLeft = 0

function createBrick(x, y, size, strength)
	local img = gfx.image.new("images/brick0" .. size)
	local brokenImg = gfx.image.new("images/brickbroken0" .. size)
	local brick = gfx.sprite.new()
	brick:setSize(size * BRICK, BRICK)
	brick:add()

	brick:setCollideRect(0, 0, size * BRICK, BRICK)
	brick:moveTo(x, y)
	brick.basePos = { x = x, y = y }
	brick.life = strength
	brick.type = "brick"
	brick.size = size
	brick.broken = false

	brick.shake = { x = 0, y = 0 }

	bricksLeft = bricksLeft + 1

	function brick:draw(x, y, w, h)
		local currentImg = self.broken and brokenImg or img
		currentImg:draw(self.shake.x, self.shake.y)
	end

	return brick
end

function createWall(x, y, w, h, type)
	local wallImg = gfx.image.new(w, h)

	gfx.pushContext(wallImg)
	gfx.fillRect(0, 0, w, h)
	gfx.popContext()

	local wall = gfx.sprite.new(wallImg)
	wall:setCollideRect(0, 0, w, h)
	wall:moveTo(x, y)
	wall:add()

	wall.type = type or "wall"

	return wall
end

function createBall()
	local img = gfx.image.new("images/ball")
	local ball = gfx.sprite.new(img)
	ball:add()

	ball:moveTo(100, 100)
	ball:setCollideRect(0, 0, BRICK, BRICK)

	ball.type = "ball"
	return ball
end

function createPaddle()
	local img = gfx.image.new("images/paddle" .. paddleWidthBricks)
	local paddle = gfx.sprite.new()

	paddle:add()
	paddle:moveTo(paddleInitialPosition.x, paddleInitialPosition.y)
	paddle:setSize(paddleWidthBricks * BRICK, BRICK)

	paddle:setCollideRect(0, 0, paddleWidthBricks * BRICK, BRICK)

	paddle.type = "paddle"
	paddle.shake = { x = 0, y = 0 }

	function paddle:draw(x, y, w, h)
		img:draw(self.shake.x, self.shake.y)
	end

	return paddle
end

function drawAim()
	local x = math.cos(aim) * 20
	local y = math.sin(aim) * 20

	local px, py = paddle:getPosition()

	gfx.drawLine(px, py, px + x, py + y)
end

-- LOAD

function loadLevel()
	if currentLevel > #levels then
		currentLevel = 1
	end
	local level = levels[currentLevel]

	paddle:moveTo(paddleInitialPosition.x, paddleInitialPosition.y)
	ball:moveTo(paddleInitialPosition.x, paddleInitialPosition.y - 2 * BRICK)

	bricksLeft = 0

	for y, row in ipairs(level) do
		local brickPosX = 0
		local brickSize = 0
		local brickStrength = 0

		for x = 1, #row do
			local tile = row:sub(x, x)
			if tile == "1" or tile == "2" then
				brickSize = brickSize + 1
				brickStrength = tonumber(tile) or 1
			elseif tile == "_" then
				if brickSize > 0 then
					createBrick(
						screenBorder.left + brickPosX * BRICK,
						screenBorder.top + y * BRICK,
						brickSize,
						brickStrength
					)
				end
				brickSize = 0
				brickPosX = x
				brickStrength = 0
			elseif tile == "." then
				if brickSize > 0 then
					createBrick(
						screenBorder.left + brickPosX * BRICK,
						screenBorder.top + y * BRICK,
						brickSize,
						brickStrength
					)
				end
				brickSize = 0
				brickPosX = x - 1
				brickStrength = 0
			end
		end
	end
end

function drawUi()
	local uiLineY = 3
	gfx.drawText(currentLevel, 50, uiLineY)
	gfx.drawText(lifes, 150, uiLineY + 5)
	gfx.drawText(score, 250, uiLineY)
	gfx.drawText(highscore, 350, uiLineY + 5)
end

-- UPDATE

function updateBall()
	local dx = ballDirection.x * (ballSpeedCurrent + ballSpeedBoost)
	local dy = ballDirection.y * (ballSpeedCurrent + ballSpeedBoost)

	local bx, by = ball:getPosition()

	local actualX, actualY, collisions = ball:moveWithCollisions(bx + dx, by + dy)

	-- cooling down the speed boost
	ballSpeedBoost = Util.lerp(ballSpeedBoost, ballSpeedBoostMin, ballSpeedBoostDecrease)

	if #collisions > 0 then
		local c = collisions[1]
		if c.other.type ~= "paddle" then
			local dot = ballDirection.x * c.normal.x + ballDirection.y * c.normal.y

			if dot ~= 0 then
				ballDirection.x = ballDirection.x - 2 * dot * c.normal.x
				ballDirection.y = ballDirection.y - 2 * dot * c.normal.y
			end
		end

		if c.other.type == "paddle" then
			local paddleSpeedAbs = math.abs(paddleSpeedCurrent)
			if paddleSpeedAbs > ballBoostPaddleSpeedMin then
				ballSpeedBoost = Util.lerp(0, ballSpeedBoostMax, paddleSpeedAbs / (paddleSpeedMax - paddleSpeedAbs))
				print("PSpeed: " .. paddleSpeedAbs .. " boost: " .. ballSpeedBoost)
			end

			-- calculating new ball angle
			px, _ = paddle:getPosition()

			-- ball position relative to the paddle
			-- We calculate where at the paddle the ball hit
			-- to establish how far left/right from the center
			-- This will be needed to influence the ball's final angle
			local offset = bx - px
			local half = (paddleWidthBricks * BRICK) / 2

			local t = offset / half
			t = Util.clamp(t, -1, 1)

			local baseX = ballDirection.x
			local baseY = ballDirection.y

			local influence = t * ballPaddleAngleInfluenceFraction

			local speedInfluence = paddleSpeedCurrent * ballPaddleSpeedInfluenceFraction

			local newX = baseX + influence + speedInfluence

			local len = math.sqrt(newX * newX + baseY * baseY)

			ballDirection.x = newX / len
			ballDirection.y = baseY / len

			-- check if the ball goes up:
			if ballDirection.y > -0.2 then
				ballDirection.y = -0.2
			end

			local len = math.sqrt(ballDirection.x ^ 2 + ballDirection.y ^ 2)
			ballDirection.x = ballDirection.x / len
			ballDirection.y = ballDirection.y / len

			-- Paddle shake

			paddle.shake = {
				x = -c.normal.x * ballSpeedCurrent,
				y = -c.normal.y * ballSpeedCurrent,
			}
		elseif c.other.type == "brick" then
			hitBrick(c.other, c.normal, ballSpeedCurrent)
		elseif c.other.type == "floor" then
			if lifes == 0 then
				unloadBricks()
				startGame()
			end
			lifes = lifes - 1
		end
	end
end

function hitBrick(brick, direction, speed)
	brick.life = brick.life - 1
	if brick.life == 0 then
		brick:remove()
		bricksLeft = bricksLeft - 1

		score = score + 1

		if score > highscore then
			highscore = score
			playdate.datastore.write("highscore")
		end

		if bricksLeft == 0 then
			currentLevel = currentLevel + 1
			loadLevel()
		end

		ballSpeedCurrent = Util.clamp(ballSpeedCurrent + ballSpeedIncrease, ballSpeedMin, ballSpeedMax)
	else
		brick.broken = true
		--brick:markDirty()
		brick.shake = {
			x = -direction.x * speed,
			y = -direction.y * speed,
		}
	end
end

function unloadBricks()
	local allSprites = gfx.sprite.getAllSprites()

	for i = 1, #allSprites do
		local s = allSprites[i]

		if s.type == "brick" then
			s:remove()
		end
	end
end

function updateBricks()
	local allSprites = gfx.sprite.getAllSprites()

	for i = 1, #allSprites do
		local s = allSprites[i]

		if s.type == "brick" then
			if s.shake.x ~= 0 or s.shake.y ~= 0 then
				s:markDirty()

				s.shake.x = s.shake.x * 0.7
				s.shake.y = s.shake.y * 0.7

				if math.abs(s.shake.x) < 0.5 then
					s.shake.x = 0
				end
				if math.abs(s.shake.y) < 0.5 then
					s.shake.y = 0
				end
			end
		end
	end
end

function startGame()
	lifes = 3
	score = 1
	currentLevel = 1

	ballSpeedCurrent = ballSpeedMin
	paddleSpeedCurrent = paddleSpeedMin

	loadLevel()
end

function updatePaddle()
	local crank = playdate.getCrankChange()
	-- crank will be -x to x
	-- We want to calculate the fraction of max, min
	-- and then lerp the current speed gradually towards that value
	-- This should result in less jiggy speed changes.

	local maxCrank = 50 -- tune this

	crank = Util.clamp(crank, -maxCrank, maxCrank)

	-- signed fraction of max crank, we will use it to calc the speed we aim at
	local fraction = (math.abs(crank) / maxCrank) * Util.sign(crank)

	local targetSpeed = paddleSpeedMax * fraction

	paddleSpeedCurrent = Util.lerp(paddleSpeedCurrent, targetSpeed, 0.3)

	-- Now actually move the paddle
	local px, py = paddle:getPosition()

	paddle:moveWithCollisions(px + paddleSpeedCurrent, py)

	-- clearing shake

	paddle.shake.x = paddle.shake.x * 0.7
	paddle.shake.y = paddle.shake.y * 0.7
end

function playdate.update()
	updatePaddle()

	updateBall()

	updateBricks()

	aim = aim + math.rad(playdate.getCrankChange())
	aim = Util.clamp(aim, math.pi, math.pi * 2)

	gfx.sprite.update()

	drawAim()

	drawUi()
end

createWall(0, SCREEN_HEIGHT / 2, wallSize, SCREEN_HEIGHT)
createWall(SCREEN_WIDTH, SCREEN_HEIGHT / 2, wallSize, SCREEN_HEIGHT)
createWall(SCREEN_WIDTH / 2, screenBorder.top, SCREEN_WIDTH, wallSize)
createWall(SCREEN_WIDTH / 2, SCREEN_HEIGHT, SCREEN_WIDTH, wallSize, "floor")

paddle = createPaddle()
ball = createBall()

startGame()
