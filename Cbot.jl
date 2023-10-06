using HorizonSideRobots

const (North, South, East) = (Nord, Sud, Ost) # West is identical in English and German
const (w, a, s, d) = (North, West, South, East) # Debugging purposes
@enum Diagonal NorthWest=0 NorthEast=1 SouthEast=2 SouthWest=3
const (NW, NE, SE, SW) = (NorthWest, NorthEast, SouthEast, SouthWest)

function packDiagonal(args...)
    if length(tuple(args...)) != 2
            error("Diagonal requires 2 sides")
        elseif args[1] == North && args[2] == West
            return NorthWest
        elseif args[1] == North && args[2] == East
            return NorthEast
        elseif args[1] == South && args[2] == East
            return SouthEast
        elseif args[1] == South && args[2] == West
            return SouthWest
        else
            error("the diagonal requires two adjacent sides")
    end
end

function unpackDiagonal(diagonal::Diagonal, convert=true)
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
        error("Unexpected Error")
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
inverse(fun::Function, args...) = !(fun(args...))
turnCounterClockwise(side::HorizonSide) = HorizonSide(mod(Int(side)+1,4))
turnClockwise(side::HorizonSide) = HorizonSide(mod(Int(side)-1,4))

function sumMoveLogs(moveLog1::MoveLog, moveLog2::MoveLog)
    ml1, ml2 = moveLog1.steps > moveLog2.steps ? (moveLog1, moveLog2) : (moveLog2, moveLog1)
    if ml1.direction == ml2.direction return MoveLog(ml1.direction, ml1.steps + ml2.steps)
    elseif ml1.direction == inverse(ml2.direction) return MoveLog(ml1.direction, ml1.steps-ml2.steps)
    else error("Invalid options")
    end
end

Base.:(==)(ml1::MoveLog, ml2::MoveLog) = ml1.direction == ml2.direction && ml1.steps == ml2.steps
Base.:+(ml1::MoveLog, ml2::MoveLog) = sumMoveLogs(ml1, ml2)

@kwdef mutable struct Cbot
    robot::HorizonSideRobots.Robot
    rx::Integer
    ry::Integer
    movesBuffer::Array{MoveLog}
    traceMove::Bool
    moveFunction::Function
    # Implementing NamedTuple here isnt the best idea in that particular case,It's recommended to use a struct instead
    # of a @NamedTuple for the movesBuffer type because structs provide better type safety,improved readability
    # and extensibility because of struct optimization. Heres an example of how it'd look in NamedTuple format:
    # movesBuffer::Array{NamedTuple{(:dir, :steps),Tuple{Union{Nothing, HorizonSideRobots.HorizonSide}, Union{Nothing, Integer}}}}
    
end

function Cbot(data::Union{Nothing, String}=nothing, animate::Bool=true)
    robot = isnothing(data) ? Robot(animate=animate) : Robot(data, animate=animate)
    return Cbot(robot, 0, 0, [], true, HorizonSideRobots.move!)
end

function bufferToTuple(buffer::Array{MoveLog})
    return [(dir=i.direction, steps=i.steps) for i in buffer]
end

function move!(bot::Cbot, side::HorizonSide, times=1;mark=false)
    for _ in 1:times
        bot.moveFunction(bot.robot, side)
        mark && putmarker!(bot)
        if side == North || side == South
            bot.ry += (side == North ? 1 : -1)
        else
            bot.rx += (side == East ? 1 : -1)
        end
    end
    bot.traceMove && push!(bot.movesBuffer, MoveLog(side, times))
end

function move!(bot::Cbot, diagonal::Diagonal, times=1;mark=false)
    function tryDiagonal!(bot::Cbot, directions, )::Bool
        mainDirection, secondaryDirection = directions
        if !isborder(bot, mainDirection)
            move!(bot, mainDirection;mark=mark)
            if !isborder(bot, secondaryDirection)
                move!(bot, secondaryDirection;mark=mark)
                return 0
            else
                move!(bot, inverse(mainDirection);mark=mark)
                return 1
            end
        elseif !isborder(bot, secondaryDirection)
            move!(bot, secondaryDirection;mark=mark)
            if !isborder(bot, mainDirection)
                move!(bot, mainDirection;mark=mark)
                return 0
            else
                move!(bot, inverse(mainDirection))
                return 1
            end
        else
            return 1
        end
    end
    dir1, dir2 = unpackDiagonal(diagonal)
    for _ in 1:times
        if tryDiagonal!(bot, (dir1, dir2)) && tryDiagonal!(bot, (dir2, dir1))
            error("Impossible move")
        end
    end
end

function move!(bot::Cbot, moveLog::MoveLog)
    move!(bot, moveLog.direction, moveLog.steps)
end

function move!(bot::Cbot, moveLogBuffer::Array{MoveLog})
    # Copy is very important because move!() function can alter Array{MoveLog} and cause infinite loop
    for moveLog in copy(moveLogBuffer)
        print(moveLog)
        move!(bot, moveLog)
    end
end

function move!(bot::Cbot, moves::Union{Array{HorizonSide}, Tuple{HorizonSide}})
    for dir in copy(moves)
        move!(bot, dir)
    end
end

function isborder(bot::Cbot, side::HorizonSide ; checkFunction=HorizonSideRobots.isborder)
    return checkFunction(bot.robot, side)
end

function isborder(bot::Cbot, sides, checkAll=true, checkAny=false)
    res = []
    for i in sides
        if isborder(bot, i) push!(res, true)
        else push!(res, false)
        end
    end
    if checkAny return any(res) end
    if checkAll return all(res) end
    return res     
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

function markLine!(bot::Cbot,side::HorizonSide, markerEvent::Function, args...)
    while !isborder(bot,side) 
        move!(bot,side)
        markerEvent(args...) && putmarker!(bot)
    end
end

function perimeter!(r::Cbot, event::Function, args...;returnFunction=returnSafe!)
    moveToCornerInf(r, SouthWest)
    for direction in (North, East, South, West)
        markLine!(r, direction, event, args...)
    end
    
    returnFunction(r)
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

function moveTill!(bot::Cbot, side::HorizonSide, event::Function=HorizonSideRobots.isborder, args...;mark=false)
    while !event(args...)
        move!(bot, side)
        if mark putmarker!(bot) end
    end
end

function returnLinear!(bot::Cbot)
    bot.traceMove=false
    x,y = bot.rx, bot.ry
    if x > 0 move!(bot, West, x) end
    if x < 0 move!(bot, East, abs(x)) end
    if y > 0 move!(bot, South, y) end
    if y < 0 move!(bot, North, abs(y)) end
    clearBuffer!(bot)
end

function moveToCornerSimple(bot::Cbot, diagonal::Diagonal, times)
    side1, side2 = unpackDiagonal(diagonal)
    for i in 1:times
        currentSide = i % 2 == 0 ? side2 : side1
        moveTill!(bot, currentSide, isborder, bot, currentSide)
    end
end

function moveToCornerInf(bot::Cbot, diagonal::Diagonal)
    side1, side2 = unpackDiagonal(diagonal)
    i = 0
    while !cornered(bot, diagonal)
        i+= 1
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
function perimeter!(r::Cbot; returnFunction=returnLinear!)
    moveToCornerSimple(r, SouthWest, 3)
    for direction in (North, East, South, West)
        markLine!(r, direction)
    end
    
    returnFunction(r)
end

function cornered(bot::Cbot, diagonal::Diagonal)
    d1, d2 = unpackDiagonal(diagonal)
    return isborder(bot, d1) && isborder(bot, d2)
end

# Do NOT execute it not from corner, it gets context from it
function snakeFromCorner!(bot::Cbot,mark=false, event::Function=HorizonSideRobots.isborder, args...)
    verticalBorder = isborder(bot, North) ? North : (isborder(bot, South) ? South : nothing)
    horizontalBorder = isborder(bot, East) ? East : (isborder(bot, West) ? West : nothing)
    @assert isnothing(verticalBorder) || isnothing(horizontalBorder) == false
    vMovementDir = inverse(verticalBorder)
    hMovementDir = inverse(horizontalBorder)
    while !event(args...)
        moveTill!(bot, hMovementDir, isborder, bot, (hMovementDir, vMovementDir), false, true; mark=mark)
        if isborder(bot, vMovementDir) break end
        !isborder(bot, vMovementDir) && move!(bot, vMovementDir)
        hMovementDir = inverse(hMovementDir)
    end
    # moveTill!(bot, hMovementDir, isborder, bot, (hMovementDir, vMovementDir), true, false; mark=mark)
end

function twoFrames!(bot::Cbot, returnFunction=returnSafe!)
    moveToCornerSimple(bot, SW, 3)
    perimeter!(bot)
    moveToCornerSimple(bot, SW, 3)
    snakeFromCorner!(bot, false, isborder, bot, North)
    moveAround!(bot, North)
    returnFunction(bot)
end

function moveAround!(bot::Cbot, initialStickingDirection=North)
    secondaryDirection = turnClockwise(initialStickingDirection)
    # print(secondaryDirection)
    moveTill!(bot, inverse(secondaryDirection),inverse, isborder, bot, initialStickingDirection)
    move!(bot, secondaryDirection)
    for _ in 1:4
        moveTill!(bot, secondaryDirection,inverse, isborder, bot, initialStickingDirection; mark=true)
        move!(bot, initialStickingDirection, mark=true)
        initialStickingDirection = turnCounterClockwise(initialStickingDirection)
        secondaryDirection = turnClockwise(initialStickingDirection)
    end
end