WINDOW_WIDTH = 1000
WINDOW_HEIGHT = 500

local scrolling = true

local background = love.graphics.newImage('images/background.png')
local backgroundX = 0
local backgroundDX = 50

local ground = love.graphics.newImage('images/ground.png')
local roof = love.graphics.newImage('images/roof.png')
local groundDX = 100

local plane = love.graphics.newImage('images/plane.png')
local crashed = love.graphics.newImage('images/crashed.png')

local rockImg = love.graphics.newImage('images/rocks.png')

oneMetre = 15
gravity = 1

rockGap = 300
gapShrinkPerSecond = 2
gapPosition = WINDOW_HEIGHT / 2
gapMinimum = 120

rocksEverySeconds = 4
rocksTimer = 0

score = 0
gameState = 0
notPlayed = true

instructionsDisplayed = false
instructionsTimer = 0

loopTimeout = 1.0
loopTime = 0
loopInactive = false

planeGravityScale = 1

function love.load()
    math.randomseed(os.time())
    love.window.setMode(WINDOW_WIDTH, WINDOW_HEIGHT)
    love.physics.setMeter(oneMetre)
    world = love.physics.newWorld(0, 0)

    love.window.setTitle('Biplane')
    planeIcon = love.image.newImageData("images/plane.png")
    love.window.setIcon(planeIcon)

    explodeSound = love.audio.newSource('sounds/explode.wav', 'static')
    scoreSound = love.audio.newSource('sounds/score.wav', 'static')
    planeSound = love.audio.newSource('sounds/plane.wav', 'static')
    loopSound = love.audio.newSource('sounds/loop.wav', 'static')
    planeSound:setLooping(true)

    objects = {}

    objects.ground = {}
    objects.ground.body = love.physics.newBody(world, WINDOW_WIDTH, WINDOW_HEIGHT - ground:getHeight() / 2, "kinematic")
    objects.ground.shape = love.physics.newRectangleShape(ground:getWidth(), ground:getHeight())
    objects.ground.fixture = love.physics.newFixture(objects.ground.body, objects.ground.shape, 100)
    objects.ground.body:setLinearVelocity(-groundDX, 0)
    objects.ground.body:setGravityScale(0)
    objects.ground.fixture:setCategory(2)

    objects.roof = {}
    objects.roof.body = love.physics.newBody(world, WINDOW_WIDTH, roof:getHeight() / 2, "kinematic")
    objects.roof.shape = love.physics.newRectangleShape(roof:getWidth(), roof:getHeight())
    objects.roof.fixture = love.physics.newFixture(objects.roof.body, objects.roof.shape, 100)
    objects.roof.body:setLinearVelocity(-groundDX, 0)
    objects.roof.body:setGravityScale(0)
    objects.roof.fixture:setCategory(2)

    objects.rocks = {}
    objects.rocksUp = {}

    for _ = 1, 5 do
        addRock(objects.rocks)
        addRockUp(objects.rocksUp)
    end

    objects.plane = {}
    objects.plane.body = love.physics.newBody(world, WINDOW_WIDTH / 3, WINDOW_HEIGHT / 2, "dynamic")
    objects.plane.shape = love.physics.newRectangleShape(plane:getWidth(), plane:getHeight())
    objects.plane.fixture = love.physics.newFixture(objects.plane.body, objects.plane.shape, 1)
    objects.plane.body:setAngularDamping(0.9)

    titleFont = love.graphics.newFont('fonts/SairaStencilOne-Regular.ttf', 60, "mono")
    normalFont = love.graphics.newFont('fonts/SairaStencilOne-Regular.ttf', 40, "mono")
end


function addRock(obj)
    newRock = {}
    newRock.body = love.physics.newBody(world, WINDOW_WIDTH + rockImg:getWidth() / 2, WINDOW_HEIGHT - rockImg:getHeight() / 2, "kinematic")
    newRock.shape = love.physics.newPolygonShape(-50, 180, -7, -180, 4, -180, 49, 180, -50, 180)
    newRock.fixture = love.physics.newFixture(newRock.body, newRock.shape, 100)
    newRock.body:setGravityScale(0)
    newRock.fixture:setMask(2)
    newRock.scored = false

    table.insert(obj, newRock)
end


function addRockUp(obj)
    newRock = {}
    newRock.body = love.physics.newBody(world, WINDOW_WIDTH + rockImg:getWidth() / 2, rockImg:getHeight() / 2, "kinematic")
    newRock.shape = love.physics.newPolygonShape(-50, 180, -7, -180, 4, -180, 49, 180, -50, 180)
    newRock.fixture = love.physics.newFixture(newRock.body, newRock.shape, 100)
    newRock.body:setLinearVelocity(0, 0)
    newRock.body:setGravityScale(0)
    newRock.fixture:setMask(2)
    newRock.body:setAngle(math.pi)

    table.insert(obj, newRock)
end


function love.update(dt)
    contacts = world:getContacts()
    noContacts = #contacts == 0

    if not noContacts then
        c = table.remove(contacts, 1)
        noContacts = not c:isTouching()
    end

    if noContacts then
        world:update(dt)
    end

    if scrolling then
        if noContacts then
            backgroundX = backgroundX + backgroundDX * dt
            if backgroundX > WINDOW_WIDTH then
                backgroundX = 0
            end
        end

        groundX = objects.ground.body:getX()
        if groundX < 0 then
            objects.ground.body:setX(WINDOW_WIDTH)
            objects.roof.body:setX(WINDOW_WIDTH)
        end
    end

    if love.keyboard.isDown("space") then
        gameState = 1
        planeSound:play()
        world:setGravity(0, oneMetre * gravity)
    end

    if gameState == 1 then
        angle = objects.plane.body:getAngle()
        angleRad = (360 * angle / (2 * math.pi) + 180) % 360

        if (angleRad < 80 or angleRad > 280) then
            planeGravityScale = planeGravityScale + 0.8 * dt
        else
            planeGravityScale = 1
        end

        objects.plane.body:setGravityScale(planeGravityScale)

        if loopInactive then
            loopTime = loopTime + dt
            if loopTime > loopTimeout and (angleRad > 100 and angleRad < 260) then
                loopInactive = false
            end
        end
        if (angleRad < 5 or angleRad > 355) and not loopInactive then
            score = score * 2
            loopInactive = true
            loopTime = 0
            loopSound:play()
        end

        if love.keyboard.isDown("left") then
            objects.plane.body:applyTorque(-40000)
        end
        if love.keyboard.isDown("right") then
            objects.plane.body:applyTorque(40000)
        end

        xProjection = math.sin(angle)
        objects.plane.body:applyForce(0, 2000 * xProjection)

        if rocksTimer == 0 then
            for _, rock in pairs(objects.rocks) do
                vx, vy = rock.body:getLinearVelocity()
                if vx == 0 then
                    rock.body:setLinearVelocity(-groundDX, 0)
                    rock.body:setPosition(WINDOW_WIDTH + rockImg:getWidth() / 2, rockGap / 2 + gapPosition + rockImg:getHeight() / 2)
                    break
                end
            end
            for _, rock in pairs(objects.rocksUp) do
                vx, vy = rock.body:getLinearVelocity()
                if vx == 0 then
                    rock.body:setLinearVelocity(-groundDX, 0)
                    rock.body:setPosition(WINDOW_WIDTH + rockImg:getWidth() / 2, -rockGap / 2 + gapPosition - rockImg:getHeight() / 2)
                    break
                end
            end
        end

        for _, rock in pairs(objects.rocks) do
            x = rock.body:getX()

            if not rock.scored and x < objects.plane.body:getX() then
                rock.scored = true
                score = score + 1
                scoreSound:play()
            end

            if x < -rockImg:getWidth() / 2 then
                rock.body:setPosition(WINDOW_WIDTH + rockImg:getWidth() / 2, 0)
                rock.body:setLinearVelocity(0, 0)
                rock.scored = false
            end
        end
        for _, rock in pairs(objects.rocksUp) do
            x = rock.body:getX()
            if x < -rockImg:getWidth() / 2 then
                rock.body:setPosition(WINDOW_WIDTH + rockImg:getWidth() / 2, 0)
                rock.body:setLinearVelocity(0, 0)
            end
        end

        rocksTimer = rocksTimer + dt

        if rocksTimer > rocksEverySeconds then
            rocksTimer = 0
        end

        rockGap = rockGap - gapShrinkPerSecond * dt
        if rockGap < gapMinimum then
            rockGap = gapMinimum
        end

        gapPosition = WINDOW_HEIGHT / 2 + (math.random() * 2 - 1) * (WINDOW_HEIGHT - 2 * ground:getHeight() - rockGap) / 2
    end

    if not noContacts then
        if notPlayed then
            explodeSound:play()
            notPlayed = false
        end
        gameState = 2
        planeSound:stop()
    end

    if gameState == 2 and love.keyboard.isDown("space") then
        score = 0
        gameState = 1
        loopTime = 0
        loopInactive = false
        for _, rock in pairs(objects.rocks) do
            rock.body:setLinearVelocity(0, 0)
            rock.body:setPosition(WINDOW_WIDTH + rockImg:getWidth() / 2, 0)
            rock.scored = false
        end
        for _, rock in pairs(objects.rocksUp) do
            rock.body:setLinearVelocity(0, 0)
            rock.body:setPosition(WINDOW_WIDTH + rockImg:getWidth() / 2, 0)
        end

        objects.plane.body:setPosition(WINDOW_WIDTH / 3, WINDOW_HEIGHT / 2)
        objects.plane.body:setLinearVelocity(0, 0)
        objects.plane.body:setAngle(0)
        objects.plane.body:setAngularVelocity(0)
        noContacts = true
        rocksTimer = 0
        gapPosition = WINDOW_HEIGHT / 2
        rockGap = 300
        notPlayed = true
        world:update(dt)
    end

    if gameState == 1 and not instructionsDisplayed then
        instructionsTimer = instructionsTimer + dt
        if instructionsTimer > 4 then
            instructionsDisplayed = true
        end
    end
end


function love.draw()
    love.graphics.draw(background, -backgroundX, 0)
    love.graphics.draw(ground, objects.ground.body:getX() - ground:getWidth() / 2, objects.ground.body:getY() - ground:getHeight() / 2)
    love.graphics.draw(roof, objects.roof.body:getX() - roof:getWidth() / 2, objects.roof.body:getY() - roof:getHeight() / 2)

    if gameState == 1 and not instructionsDisplayed then
        love.graphics.setColor(0, 0, 0)
        love.graphics.setFont(normalFont)
        love.graphics.printf("Press left and right to steer", 0, WINDOW_HEIGHT / 4, WINDOW_WIDTH, "center")
        love.graphics.printf("Doing a loop will double your points!", 0, 2.25 * WINDOW_HEIGHT / 4, WINDOW_WIDTH, "center")
        love.graphics.setColor(1, 1, 1)
    end

    for _, rock in pairs(objects.rocks) do
        love.graphics.draw(rockImg, rock.body:getX() - rockImg:getWidth() / 2, rock.body:getY() - rockImg:getHeight() / 2)
    end
    for _, rock in pairs(objects.rocksUp) do
        love.graphics.draw(rockImg, rock.body:getX() + rockImg:getWidth() / 2, rock.body:getY() + rockImg:getHeight() / 2, math.pi)
    end

    planeX, planeY = objects.plane.body:getWorldPoints(objects.plane.shape:getPoints())
    angle = objects.plane.body:getAngle()

    collisionX = planeX - math.cos(angle) * (crashed:getWidth() - plane:getWidth()) / 2 + math.sin(angle) * (crashed:getHeight() - plane:getHeight()) / 2
    collisionY = planeY - math.cos(angle) * (crashed:getHeight() - plane:getHeight()) / 2 - math.sin(angle) * (crashed:getWidth() - plane:getWidth()) / 2

    if noContacts then
        love.graphics.draw(plane, planeX, planeY, angle)
    else
        love.graphics.draw(crashed, collisionX, collisionY + 14, angle)
    end

    if gameState == 1 or gameState == 2 then
        love.graphics.setColor(0, 0, 0)
        love.graphics.setFont(normalFont)
        love.graphics.printf(score, 50, 50, 200, "left")
        love.graphics.setColor(1, 1, 1)
    end
    if gameState == 0 then
        love.graphics.setColor(0, 0, 0)
        love.graphics.setFont(titleFont)
        love.graphics.printf("Biplane", 0, WINDOW_HEIGHT / 4, WINDOW_WIDTH, "center")
        love.graphics.setFont(normalFont)
        love.graphics.printf("Press space to start", 0, 2.25 * WINDOW_HEIGHT / 4, WINDOW_WIDTH, "center")
        love.graphics.setColor(1, 1, 1)
    end
    if gameState == 2 then
        love.graphics.setColor(0, 0, 0)
        love.graphics.setFont(titleFont)
        love.graphics.printf("Crashed!", 0, WINDOW_HEIGHT / 4, WINDOW_WIDTH, "center")
        love.graphics.setFont(normalFont)
        love.graphics.printf("Press space to restart", 0, 2.25 * WINDOW_HEIGHT / 4, WINDOW_WIDTH, "center")
        love.graphics.setColor(1, 1, 1)
    end

end
