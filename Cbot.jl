using HorizonSideRobots

const (North, South, East) = (Nord, Sud, Ost) # West is identical in English and German
const (w, a, s, d) = (North, West, South, East) # Debugging purposes

@kwdef mutable struct Cbot
    robot::HorizonSideRobots.Robot
    rx::Integer=0
    ry::Integer=0
    movesBuffer::Array{Union{Nothing, HorizonSideRobots.HorizonSide}}=[]
    traceMove=true
end

function Cbot(data::Union{Nothing, HorizonSideRobots.SituationData}=nothing, animate::Bool=true)
    robot = isnothing(data) ? Robot(animate=animate) : Robot(data, animate=animate)
    return Cbot(robot, 0, 0, [], true)
end

function move!(bot::Cbot, side::HorizonSide, times=1 ; moveFunction=HorizonSideRobots.move!)
    for i in 1:times
        moveFunction(bot.robot, side)
        bot.traceMove && push!(bot.movesBuffer, side)
        if side == North || side == South
            bot.ry += (side == North ? 1 : -1)
        else
            bot.rx += (side == East ? 1 : -1)
        end
    end
end

function move!(bot::Cbot, moves::Array{HorizonSide} ; moveFunction=HorizonSideRobots.move!)
    for dir in moves
        move!(bot, dir; moveFunction=moveFunction)
    end
end

function isborder(bot::Cbot, side::HorizonSide ; checkFunction=HorizonSideRobots.isborder)
    return checkFunction(bot.robot, side)
end

function putmarker!(bot::Cbot ; markerFunction=HorizonSideRobots.putmarker!)
    HorizonSideRobots.putmarker!(bot.robot, )
end

function ismarker(bot::Cbot ; markerFunction=HorizonSideRobots.ismarker)
    return markerFunction(bot.robot)
end

function markLine!(bot::Cbot,side::HorizonSide)
    while !isborder(bot,side) 
        move!(bot,side)
        putmarker!(bot)
    end
end

"""the following function changes the direction by 180 degrees"""
inverse(side::HorizonSide) = HorizonSide(mod(Int(side)+2,4))

function returnSafe!(bot::Cbot)
    bot.traceMove=false
    for dir in bot.movesBuffer
        move!(bot, inverse(dir))
    end
    bot.movesBuffer=[]
    bot.traceMove=true
end

function moveTill!(bot::Cbot, side::HorizonSide, event::Function=HorizonSideRobots.isborder, args...)
    while !event(args...)
        move!(bot, side)
    end
end


function returnLinear(bot::Cbot)
    x,y = bot.rx, bot.ry
    bot.traceMove=false
    if x > 0 move!(r, West, x - 1) end
    if x < 0 move!(r, East, abs(x) - 1) end
    if y > 0 move!(r, South, y - 1) end
    if y < 0 move!(r, North, abs(y) - 1) end
    bot.movesBuffer=[]
    bot.traceMove=true
end




"""the following function fills the cross form"""
function cross!(r::Robot,delta::Vector)
    for i in range(0, 3)
        side = HorizonSide(i)
        delta = markLine!(r,side,delta)
        delta = returnRobot!(r, delta)
    end
    putmarker!(r)
end

function cross!(r::Cbot)
    for i in range(0, 3)
        side = HorizonSide(i)
        markLine!(r,side)
        returnSafe!(r)
    end
    putmarker!(r)
end

print("Done")