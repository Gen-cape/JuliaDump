using HorizonSideRobots

const (North, South, East) = (Nord, Sud, Ost) # West is identical in English and German
const (w, a, s, d) = (North, West, South, East) # Debugging purposes

@kwdef mutable struct MoveLog
    # TODO extend format
    direction::Union{Nothing, HorizonSideRobots.HorizonSide}
    steps::Union{Nothing, Integer}
end

"""the following function changes the direction by 180 degrees"""
inverse(side::HorizonSide) = HorizonSide(mod(Int(side)+2,4))
inverse(moveLog::MoveLog) = MoveLog(inverse(moveLog.direction), moveLog.steps)

function sumMoveLogs(moveLog1::MoveLog, moveLog2::MoveLog)
    ml1, ml2 = moveLog1.steps > moveLog2.steps ? (moveLog1, moveLog2) : (moveLog2, moveLog1)
    if ml1.direction == ml2.direction return MoveLog(ml1.direction, ml1.steps + ml2.steps)
    elseif ml1.direction == inverse(ml2.direction) return MoveLog(ml1.direction, ml1.steps-ml2.steps)
    else throw("Invalid options")
    end
end

Base.:+(ml1::MoveLog, ml2::MoveLog) = sumMoveLogs(ml1, ml2)

@kwdef mutable struct Cbot
    robot::HorizonSideRobots.Robot
    rx::Integer=0
    ry::Integer=0
    movesBuffer::Array{MoveLog}=[]
    traceMove=true

    # Implementing NamedTuple here isnt the best idea in that particular case,It's recommended to use a struct instead
    # of a @NamedTuple for the movesBuffer type because structs provide better type safety,improved readability
    # and extensibility because of struct optimization. Heres an example of how it'd look in NamedTuple format:
    # movesBuffer::Array{NamedTuple{(:dir, :steps),Tuple{Union{Nothing, HorizonSideRobots.HorizonSide}, Union{Nothing, Integer}}}}
    
end

function Cbot(data::Union{Nothing, HorizonSideRobots.SituationData}=nothing, animate::Bool=true)
    robot = isnothing(data) ? Robot(animate=animate) : Robot(data, animate=animate)
    return Cbot(robot, 0, 0, [], true)
end

function bufferToTuple(buffer::Array{MoveLog})
    return [(dir=i.direction, steps=i.steps) for i in buffer]
end

function move!(bot::Cbot, side::HorizonSide, times=1 ; moveFunction=HorizonSideRobots.move!)
    for i in 1:times
        moveFunction(bot.robot, side)
        if side == North || side == South
            bot.ry += (side == North ? 1 : -1)
        else
            bot.rx += (side == East ? 1 : -1)
        end
    end
    bot.traceMove && push!(bot.movesBuffer, MoveLog(side, times))
end

function move!(bot::Cbot, moveLog::MoveLog ; moveFunction=HorizonSideRobots.move!)
    move!(bot, moveLog.direction, moveLog.steps ; moveFunction=moveFunction)
end

function move!(bot::Cbot, moveLogBuffer::Array{MoveLog} ; moveFunction=HorizonSideRobots.move!)
    # Copy is very important because move! function can alter Array{MoveLog} and cause infinite loop
    for moveLog in copy(moveLogBuffer)
        print(moveLog)
        move!(bot, moveLog; moveFunction=moveFunction)
    end
end

function move!(bot::Cbot, moves::Array{HorizonSide} ; moveFunction=HorizonSideRobots.move!)
    for dir in copy(moves)
        move!(bot, dir; moveFunction=moveFunction)
    end
end

function isborder(bot::Cbot, side::HorizonSide ; checkFunction=HorizonSideRobots.isborder)
    return checkFunction(bot.robot, side)
end

function putmarker!(bot::Cbot ; markerFunction=HorizonSideRobots.putmarker!)
    markerFunction(bot.robot)
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

function clearBuffer!(bot::Cbot, traceMove=true)
    bot.movesBuffer=[]
    bot.traceMove=traceMove
end

function inverseBuffer(buffer::Vector{ MoveLog })
    return [MoveLog(m.direction === nothing ? nothing : inverse(m.direction), m.steps) for m in buffer]
end

function simplifyBuffer(moveLogBuffer::Array{MoveLog})
    simplifiedBuffer = [moveLogBuffer[begin]]
    for ml in moveLogBuffer[2:end]
        sb = simplifiedBuffer[end]
        if ml.direction == sb.direction || ml.direction == inverse(sb.direction)
            push!(simplifiedBuffer, pop!(simplifiedBuffer)+ml)
        else
            push!(simplifiedBuffer, ml)
        end
    end
    return simplifiedBuffer
end

function returnSafe!(bot::Cbot)
    bot.traceMove=false
    for moveLog in simplifyBuffer(inverseBuffer(reverse!(bot.movesBuffer)))
        move!(bot, moveLog)
    end
    clearBuffer!(bot)
end

function moveTill!(bot::Cbot, side::HorizonSide, event::Function=HorizonSideRobots.isborder, args...)
    while !event(args...)
        move!(bot, side)
    end
end

function returnLinear!(bot::Cbot)
    bot.traceMove=false
    x,y = bot.rx, bot.ry
    if x > 0 move!(r, West, x) end
    if x < 0 move!(r, East, abs(x)) end
    if y > 0 move!(r, South, y) end
    if y < 0 move!(r, North, abs(y)) end
    clearBuffer!(bot)
end

function cross!(bot::Cbot)
    for i in range(0, 3)
        side = HorizonSide(i)
        markLine!(bot,side)
        returnSafe!(bot)
    end
    putmarker!(bot)
end

function fullCanvas!(bot::Cbot; returnFunction=returnLinear!)
    moveTill!(bot, South, isborder, bot, South)
    moveTill!(bot, West, isborder, bot, West)
    putmarker!(bot)
    while true
        """
        moving direction is needed so that if the field has an odd number of columns,
        the program does not forget to process the last column. for a square (and not a possible rectangle),
        you can always check only the borders from the bottom and right in that particular case.
        """
        movingDirection = North
        if isborder(bot, South)
            markLine!(bot, North)
            movingDirection = North
        else
            markLine!(bot, South)
            movingDirection = South
        end

        # stopping condition
        if isborder(bot, movingDirection) && isborder(bot, East) break end
        
        move!(bot, East)
        putmarker!(bot)
    end

    returnFunction(bot)

end