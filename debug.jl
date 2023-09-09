using HorizonSideRobots

delta = [0,0] # X Y

function moveDelta!(r::Robot, side::HorizonSide, delta::Vector)
    move!(r, side)
    x,y = delta
    if Int(side) == 0 y += 1
    elseif Int(side) == 1 x -= 1
    elseif Int(side) == 2 y -= 1
    else x += 1 end
    return [x,y]
end

function markLine!(r::Robot,side::HorizonSide, delta::Vector)
    while !isborder(r,side) 
        delta = moveDelta!(r,side,delta)
        putmarker!(r)
    end
    return delta
end

function moveTimes!(r::Robot, side::HorizonSide, times::Integer, delta::Vector )
    for _ in range(0, times)
        delta = moveDelta!(r, side, delta)
    end
    return delta
end

function returnRobot(r::Robot, delta::Vector)
    x,y = delta
    if x > 0 delta=moveTimes!(r, HorizonSide(1), x -1, delta) end
    if x < 0 delta=moveTimes!(r, HorizonSide(3), abs(x) - 1, delta) end
    if y > 0 delta=moveTimes!(r, HorizonSide(2), y - 1, delta) end
    if y < 0 delta=moveTimes!(r, HorizonSide(0), abs(y) - 1, delta) end
    return delta
end

function cross!(r::Robot,delta::Vector)
    for i in range(0, 3)
        side = HorizonSide(i)
        delta = markLine!(r,side,delta)
        delta = returnRobot(r, delta)
    end
    putmarker!(r)
end

inverse(side::HorizonSide) = HorizonSide(mod(Int(side)+2,4))
r = Robot("default.sit",animate=true)
# r = Robot(animate=true)

cross!(r, delta)   