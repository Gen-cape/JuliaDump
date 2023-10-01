using HorizonSideRobots

const (North, South, East) = (Nord, Sud, Ost) # West is identical in English and German
const (w, a, s, d) = (North, West, South, East) # Debugging purposes
@enum Diagonal NorthWest=0 NorthEast=1 SouthEast=2 SouthWest=3
const (NW, NE, SE, SW) = (NorthWest, NorthEast, SouthEast, SouthWest) # West is identical in English and German

function Diagonal(args...)
    if length(tuple(args...)) != 2
        throw("Diagonal requires 2 sides")
    elseif args[1] == North && args[2] == West
        return NorthWest
    elseif args[1] == North && args[2] == East
        return NorthEast
    elseif args[1] == South && args[2] == East
        return SouthEast
    elseif args[1] == South && args[2] == West
        return SouthWest
    else
        throw("the diagonal requires two adjacent sides")
    end
end

function Diagonal(diagonal::Diagonal, convert=true)
    if !convert return diagonal end
    if diagonal == NorthWest
        return (North, West)
    elseif diagonal == NorthEast
        return (North, East)
    elseif diagonal == SouthEast
        return (South, East)
    elseif diagonal == SouthWest
        return SW = (South, West)
    else
        throw("Unexpected Error")
    end
end

@kwdef mutable struct MoveLog
    # TODO extend format
    direction::Union{Nothing, HorizonSideRobots.HorizonSide, Diagonal}
    steps::Union{Nothing, Integer}
end

"""the following function changes the direction by 180 degrees"""
inverse(side::HorizonSide) = HorizonSide(mod(Int(side)+2,4))
inverse(side::Diagonal) = Diagonal(mod(Int(side)+2,4))
inverse(moveLog::MoveLog) = MoveLog(inverse(moveLog.direction), moveLog.steps)
counterClockwise(side::HorizonSide) = HorizonSide(mod(Int(side)+1,4))

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

function Cbot(data::Union{Nothing, String}=nothing, animate::Bool=true)
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

function move!(bot::Cbot, diagonal::Diagonal; moveFunction=HorizonSideRobots.move!)
    if diagonal == NorthWest
        if !isborder(bot, North)
            move!(bot, North,moveFunction=moveFunction)
            if !isborder(bot, West)
                move!(bot, West, moveFunction=moveFunction)
            else
                move!(bot, South, moveFunction=moveFunction)
            end
        elseif !isborder(bot, West)
            move!(bot, West, moveFunction=moveFunction)
            if !isborder(bot, North)
                move!Function(bot, North, moveFunction=moveFunction)
            else
                move!(bot, East, moveFunction=moveFunction)
            end
        else throw("Impossible")
        end
    elseif diagonal == NorthEast
        if !isborder(bot, North)
            move!(bot, North, moveFunction=moveFunction)
            if !isborder(bot, East)
                move!(bot, East, moveFunction=moveFunction)
            else
                move!(bot, South, moveFunction=moveFunction)
            end
        elseif !isborder(bot, East)
            move!(bot, East, moveFunction=moveFunction)
            if !isborder(bot, North)
                move!(bot, North, moveFunction=moveFunction)
            else
                move!(bot, West, moveFunction=moveFunction)
            end
        else throw("Impossible")
        end
    elseif diagonal == SouthEast
        if !isborder(bot, South)
            move!(bot, South, moveFunction=moveFunction)
            if !isborder(bot, East)
                move!(bot, East, moveFunction=moveFunction)
            else
                move!(bot, North, moveFunction=moveFunction)
            end
        elseif !isborder(bot, East)
            move!(bot, East, moveFunction=moveFunction)
            if !isborder(bot, South)
                move!(bot, South, moveFunction=moveFunction)
            else
                move!(bot, West, moveFunction=moveFunction)
            end
        else throw("Impossible")
        end
    elseif diagonal == SouthWest
        if !isborder(bot, South)
            move!(bot, South, moveFunction=moveFunction)
            if !isborder(bot, West)
                move!(bot, West, moveFunction=moveFunction)
            else
                move!(bot, North, moveFunction=moveFunction)
            end
        elseif !isborder(bot, West)
            move!(bot, West, moveFunction=moveFunction)
            if !isborder(bot, South)
                move!(bot, South, moveFunction=moveFunction)
            else
                move!(bot, East, moveFunction=moveFunction)
            end
        else throw("Impossible")
        end
    else throw("Invalid diagonal")
    end
end

function move!(bot::Cbot, moveLog::MoveLog ; moveFunction=HorizonSideRobots.move!)
    move!(bot, moveLog.direction, moveLog.steps ; moveFunction=moveFunction)
end

function move!(bot::Cbot, moveLogBuffer::Array{MoveLog} ; moveFunction=HorizonSideRobots.move!)
    # Copy is very important because move!() function can alter Array{MoveLog} and cause infinite loop
    for moveLog in copy(moveLogBuffer)
        print(moveLog)
        move!(bot, moveLog; moveFunction=moveFunction)
    end
end

function move!(bot::Cbot, moves::Union{Array{HorizonSide}, Tuple{HorizonSide}} ; moveFunction=HorizonSideRobots.move!)
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

function moveToCornerSimple(bot::Cbot, diagonal::Diagonal, times)
    side1, side2 = Diagonal(diagonal)
    for i in 1:times
        currentSide = i % 2 == 0 ? side2 : side1
        moveTill!(bot, currentSide, isborder, bot, currentSide)
    end
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

"""the following function fills the perimeter"""
function perimeter!(r::Cbot, returnFunction=returnLinear!)
    moveToCornerThreeSteps(r, SouthWest)
    for direction in (North, East, South, West)
        markLine!(r, direction)
    end
    
    returnFunction(r)
end