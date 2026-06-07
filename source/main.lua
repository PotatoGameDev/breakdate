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

local ballSpeedMin = 1
local ballSpeedMax = 4
local ballSpeedCurrent = ballSpeedMin

local ballSpeedIncreaseOnHit = 0.5

-- paddle
--
local paddleInitialPosition = {
	x = SCREEN_WIDTH / 2,
	y = SCREEN_HEIGHT - screenBorder.bottom,
}

local paddleWidthBricks = 4

local paddleSpeedMin = 1
local paddleSpeedMax = 5
local paddleSpeedCurrent = paddleSpeedMin
local paddleMaxSpeedTimeMillis = 500
local paddleLastPressedTime = 0

-- UI

local score = 1
local highscore = 1
local currentLevel = 1
local lives = 3

-- levels
local levels = import("levels")

local bricksLeft = 0

function createBrick(x, y, size, strength)
	local img = gfx.image.new("images/brick0" .. size)
	local brick = gfx.sprite.new(img)
	brick:add()

	brick:setCollideRect(0, 0, size * BRICK, BRICK)
	brick:moveTo(x, y)
	brick.life = strength
	brick.type = "brick"

	bricksLeft = bricksLeft + 1
	print("Bricks: " .. bricksLeft)

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

	wall.type = "wall"

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
	local paddle = gfx.sprite.new(img)
	paddle:add()
	paddle:moveTo(paddleInitialPosition.x, paddleInitialPosition.y)

	paddle:setCollideRect(0, 0, paddleWidthBricks * BRICK, BRICK)

	paddle.type = "paddle"

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

	for y, row in ipairs(level) do
		local brickPosX = 0
		local brickSize = 0
		local brickStrength = 0

		for x = 1, #row do
			local tile = row:sub(x, x)
			if tile == "1" then
				brickSize = brickSize + 1
				brickStrength = 1
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
	gfx.drawText(lives, 150, uiLineY + 5)
	gfx.drawText(score, 250, uiLineY)
	gfx.drawText(highscore, 350, uiLineY + 5)
end

-- UPDATE

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

		if c.other.type == "paddle" then
			ballSpeedCurrent = Util.clamp(ballSpeedCurrent + ballSpeedIncreaseOnHit, ballSpeedMin, ballSpeedMax)
		elseif c.other.type == "brick" then
			hitBrick(c.other)
		end
	end
end

function hitBrick(brick)
	brick.life = brick.life - 1
	if brick.life == 0 then
		brick:remove()
		bricksLeft = bricksLeft - 1

		score = score + 1

		if score > highscore then
			highscore = score
		end

		print(bricksLeft)

		if bricksLeft == 0 then
			currentLevel = currentLevel + 1
			loadLevel()
		end
	end
end

-- DEPRECATED, based on the left/right buttons
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

function updatePaddle2()
	local crank = playdate.getCrankChange()
	local px, py = paddle:getPosition()

	paddle:moveWithCollisions(px + crank, py)
end

function playdate.update()
	updatePaddle2()

	updateBall()

	aim = aim + math.rad(playdate.getCrankChange())
	aim = Util.clamp(aim, math.pi, math.pi * 2)

	gfx.sprite.update()

	drawAim()

	drawUi()
end

createWall(0, SCREEN_HEIGHT / 2, wallSize, SCREEN_HEIGHT)
createWall(SCREEN_WIDTH, SCREEN_HEIGHT / 2, wallSize, SCREEN_HEIGHT)
createWall(SCREEN_WIDTH / 2, screenBorder.top, SCREEN_WIDTH, wallSize)
createWall(SCREEN_WIDTH / 2, SCREEN_HEIGHT, SCREEN_WIDTH, wallSize)

paddle = createPaddle()
ball = createBall()
loadLevel()
