import("CoreLibs/graphics")
import("CoreLibs/sprites")
local Util = import("util")

local gfx = playdate.graphics

local paddle
local ball

local aim = 0

BRICK = 16

-- ball

local ballDirection = { x = 1, y = -1 }

local ballSpeedMin = 1
local ballSpeedMax = 4
local ballSpeedCurrent = ballSpeedMin

local ballSpeedIncreaseOnHit = 0.5

-- paddle

local paddleWidthBricks = 4

local paddleSpeedMin = 1
local paddleSpeedMax = 5
local paddleSpeedCurrent = paddleSpeedMin
local paddleMaxSpeedTimeMillis = 500
local paddleLastPressedTime = 0

function createBrick(x, y, w, h)
	local img = gfx.image.new("images/brick01")
	local brick = gfx.sprite.new(img)
	brick:add()

	brick:setCollideRect(0, 0, w, h)
	brick:moveTo(x, y)

	return brick
end

function createWall(x, y, w, h)
	local wallImg = gfx.image.new(w, h)

	gfx.pushContext(wallImg)
	gfx.fillRect(0, 0, w, h)
	gfx.popContext()

	local wall = gfx.sprite.new(wallImg)
	wall:setCollideRect(0, 0, w, h)
	wall:moveTo(x, y)
	wall:add()
end

function createBall()
	local img = gfx.image.new("images/ball")
	local ball = gfx.sprite.new(img)
	ball:add()

	ball:moveTo(100, 100)
	ball:setCollideRect(0, 0, 16, 16)

	return ball
end

function createPaddle(x, y)
	local img = gfx.image.new("images/paddle" .. paddleWidthBricks)
	local paddle = gfx.sprite.new(img)
	paddle:add()
	paddle:moveTo(x, y)

	paddle:setCollideRect(0, 0, paddleWidthBricks * BRICK, BRICK)
	return paddle
end

function drawAim()
	local x = math.cos(aim) * 20
	local y = math.sin(aim) * 20

	local px, py = paddle:getPosition()

	gfx.drawLine(px, py, px + x, py + y)
end

function updateBall()
	local dx = ballDirection.x * ballSpeedCurrent
	local dy = ballDirection.y * ballSpeedCurrent

	local bx, by = ball:getPosition()

	local actualX, actualY, collisions = ball:moveWithCollisions(bx + dx, by + dy)

	if #collisions > 0 then
		local c = collisions[1]
		if c.normal.x ~= 0 then
			ballDirection.x = c.normal.x
		end
		if c.normal.y ~= 0 then
			ballDirection.y = c.normal.y
		end

		if c.other == paddle then
			ballSpeedCurrent = Util.clamp(ballSpeedCurrent + ballSpeedIncreaseOnHit, ballSpeedMin, ballSpeedMax)
		end
	end
end

function updatePaddle()
	local pressed = false
	local px, py = paddle:getPosition()
	if playdate.buttonIsPressed(playdate.kButtonLeft) then
		paddle:moveWithCollisions(px - paddleSpeedCurrent, py)
		pressed = true
	elseif playdate.buttonIsPressed(playdate.kButtonRight) then
		paddle:moveWithCollisions(px + paddleSpeedCurrent, py)
		pressed = true
	else
		paddleLastPressedTime = 0
	end

	if pressed then
		if paddleLastPressedTime == 0 then
			paddleLastPressedTime = playdate.getCurrentTimeMilliseconds()
		else
			local paddleTime = playdate.getCurrentTimeMilliseconds() - paddleLastPressedTime
			paddleSpeedCurrent = Util.lerp(paddleSpeedMin, paddleSpeedMax, paddleTime / paddleMaxSpeedTimeMillis)
		end
	else
		paddleSpeedCurrent = paddleSpeedMin
	end
end

function playdate.update()
	updatePaddle()

	updateBall()

	aim = aim + math.rad(playdate.getCrankChange())
	aim = Util.clamp(aim, math.pi, math.pi * 2)

	gfx.sprite.update()

	drawAim()
end

local wallLeft = createWall(0, 120, 10, 240)
local wallRight = createWall(400, 120, 10, 240)
local wallTop = createWall(200, 0, 400, 10)
local wallBottom = createWall(200, 240, 400, 10)

local brick = createBrick(10, 30, BRICK, BRICK)

paddle = createPaddle(150, 220)
ball = createBall()
