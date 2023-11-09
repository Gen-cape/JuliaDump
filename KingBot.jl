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
inverse(fun::Function, args) = !(fun(args...)) # Debugging purposes
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
Base.:(==)(side::HorizonSide, ml2::MoveLog) = side == ml2.direction && ml2.steps == 1
Base.:(==)(ml1::MoveLog, side::HorizonSide) = side == ml1.direction && ml1.steps == 1
Base.:+(ml1::MoveLog, ml2::MoveLog) = sumMoveLogs(ml1, ml2)

@kwdef mutable struct KingBot
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

function KingBot(data::Union{Nothing, String}=nothing, animate::Bool=true)
    robot = isnothing(data) ? Robot(animate=animate) : Robot(data, animate=animate)
    return KingBot(robot, 0, 0, [], true, HorizonSideRobots.move!)
end

function bufferToTuple(buffer::Array{MoveLog})
    return [(dir=i.direction, steps=i.steps) for i in buffer]
end

function move!(bot::KingBot, side::HorizonSide, times=1;mark=false)
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

function move!(bot::KingBot, diagonal::Diagonal, times=1;mark=false)
    function tryDiagonal!(bot::KingBot, directions, )::Bool
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

function move!(bot::KingBot, moveLog::MoveLog)
    move!(bot, moveLog.direction, moveLog.steps)
end

function move!(bot::KingBot, moveLogBuffer::Array{MoveLog})
    # Copy is very important because move!() function can alter Array{MoveLog} and cause infinite loop
    for moveLog in copy(moveLogBuffer)
        move!(bot, moveLog)
    end
end

function move!(bot::KingBot, moves::Union{Array{HorizonSide}, Tuple{HorizonSide}})
    for dir in copy(moves)
        move!(bot, dir)
    end
end

function isborder(bot::KingBot, side::HorizonSide ; checkFunction=HorizonSideRobots.isborder)
    return checkFunction(bot.robot, side)
end

function isborder(bot::KingBot, sides, checkAll=true, checkAny=false)
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

function putmarker!(bot::KingBot ; markerFunction=HorizonSideRobots.putmarker!)
    markerFunction(bot.robot)
end

function ismarker(bot::KingBot ; markerFunction=HorizonSideRobots.ismarker)
    return markerFunction(bot.robot)
end

function markLine!(bot::KingBot,side::HorizonSide)
    while !isborder(bot,side) 
        move!(bot,side)
        putmarker!(bot)
    end
end

function markLine!(bot::KingBot,side::HorizonSide, markerEvent::Function, args)
    while !isborder(bot,side) 
        move!(bot,side)
        markerEvent(args) && putmarker!(bot)
    end
end

function perimeter!(r::KingBot, stopCondition::Function, stopConditionArgs;returnFunction=returnSafe!)
    moveToCornerInf(r, SouthWest)
    for direction in (North, East, South, West)
        markLine!(r, direction, stopCondition, stopConditionArgs)
    end
    
    returnFunction(r)
end

function clearBuffer!(bot::KingBot, traceMove=true)
    bot.movesBuffer=[]
    bot.traceMove=traceMove
end

function clearLogging!(bot::KingBot, traceMove=true)
    bot.rx = 0
    bot.ry = 0
    clearBuffer!(bot, traceMove)
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

function returnSafe!(bot::KingBot)
    bot.traceMove=false
    for moveLog in simplifyBuffer(inverseBuffer(reverse!(bot.movesBuffer)))
        move!(bot, moveLog)
    end
    clearBuffer!(bot)
end

function moveTill!(bot::KingBot, side::HorizonSide, stopCondition::Function=HorizonSideRobots.isborder, stopConditionArgs=[];mark=false)
    while !stopCondition(stopConditionArgs...)
        move!(bot, side)
        if mark putmarker!(bot) end
    end
end

function moveTill!(bot::KingBot, side::HorizonSide, stopCondition::Function, stopConditionArgs, markCondition::Function, markConditionArgs)
    while !stopCondition(stopConditionArgs...)
        if markCondition(markConditionArgs...) putmarker!(bot) end
        move!(bot, side)
    end
end

function moveTill!(bot::KingBot, side::HorizonSide, stopCondition::Function, stopConditionArgs, markCondition::Function, markConditionArgs, controlCodnition::Function, controlCodnitionArgs)
    while !stopCondition(stopConditionArgs...)
        if markCondition(markConditionArgs...) putmarker!(bot) end
        controlCodnition(controlCodnitionArgs...)
        move!(bot, side)
    end
end

# inverse, [isborder, [bot, North]]
# inverse, isborder, bot, North

function returnLinear!(bot::KingBot)
    bot.traceMove=false
    x,y = bot.rx, bot.ry
    if x > 0 move!(bot, West, x) end
    if x < 0 move!(bot, East, abs(x)) end
    if y > 0 move!(bot, South, y) end
    if y < 0 move!(bot, North, abs(y)) end
    clearBuffer!(bot)
end

function moveToCornerSimple(bot::KingBot, diagonal::Diagonal, times)
    side1, side2 = unpackDiagonal(diagonal)
    for i in 1:times
        currentSide = i % 2 == 0 ? side2 : side1
        moveTill!(bot, currentSide, isborder, [bot, currentSide])
    end
end

function moveToCornerInf(bot::KingBot, diagonal::Diagonal)
    side1, side2 = unpackDiagonal(diagonal)
    i = 0
    while !cornered(bot, diagonal)
        i+= 1
        currentSide = i % 2 == 0 ? side2 : side1
        moveTill!(bot, currentSide, isborder, [bot, currentSide])
    end
end

function cross!(bot::KingBot)
    for i in range(0, 3)
        side = HorizonSide(i)
        markLine!(bot,side)
        returnSafe!(bot)
    end
    putmarker!(bot)
end

function fullCanvas!(bot::KingBot; returnFunction=returnLinear!)
    moveTill!(bot, South, isborder, [bot, South])
    moveTill!(bot, West, isborder, [bot, West])
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
function perimeter!(r::KingBot; returnFunction=returnLinear!)
    moveToCornerSimple(r, SouthWest, 3)
    for direction in (North, East, South, West)
        markLine!(r, direction)
    end
    
    returnFunction(r)
end

function cornered(bot::KingBot, diagonal::Diagonal)
    d1, d2 = unpackDiagonal(diagonal)
    return isborder(bot, d1) && isborder(bot, d2)
end

# Do NOT execute it not from corner, it gets context from it
function snakeFromCorner!(bot::KingBot,mark, stopCondition::Function=HorizonSideRobots.isborder, args::Array{Any}=[])
    verticalBorder = isborder(bot, North) ? North : (isborder(bot, South) ? South : nothing)
    horizontalBorder = isborder(bot, East) ? East : (isborder(bot, West) ? West : nothing)
    @assert isnothing(verticalBorder) || isnothing(horizontalBorder) == false
    vMovementDir = inverse(verticalBorder)
    hMovementDir = inverse(horizontalBorder)
    while stopCondition(args...)
        moveTill!(bot, hMovementDir, isborder, [bot, (hMovementDir, vMovementDir), false, true]; mark=mark)
        if isborder(bot, vMovementDir) break end
        !isborder(bot, vMovementDir) && move!(bot, vMovementDir)
        hMovementDir = inverse(hMovementDir)
    end
    # moveTill!(bot, hMovementDir, isborder, bot, (hMovementDir, vMovementDir), true, false; mark=mark)
end

function moveAround!(bot::KingBot, initialStickingDirection=North)
    secondaryDirection = turnClockwise(initialStickingDirection)
    # print(secondaryDirection)
    moveTill!(bot, inverse(secondaryDirection),inverse, [isborder, [bot, initialStickingDirection]])
    move!(bot, secondaryDirection)
    for _ in 1:4
        moveTill!(bot, secondaryDirection,inverse, [isborder, [bot, initialStickingDirection]]; mark=true)
        move!(bot, initialStickingDirection, mark=true)
        initialStickingDirection = turnCounterClockwise(initialStickingDirection)
        secondaryDirection = turnClockwise(initialStickingDirection)
    end
end

function twoFrames!(bot::KingBot, returnFunction=returnSafe!)
    moveToCornerSimple(bot, SW, 3)
    perimeter!(bot)
    moveToCornerSimple(bot, SW, 3)
    snakeFromCorner!(bot, false, isborder, [bot, North])
    moveAround!(bot, North)
    returnFunction(bot)
end

function linearSearch!(bot::KingBot,startingDirection::HorizonSide,  stopCondition::Function, stopConditionArgs...)
    currentDirection = startingDirection
    ampl = 1
    while !stopCondition(stopConditionArgs...)
        move!(bot, currentDirection, ampl)
        currentDirection = inverse(currentDirection)
        ampl += 1
    end
end

function move!(bot::KingBot, side::HorizonSide, times, stopCondition::Function, stopConditionArgs ;mark=false)
    for _ in 1:times
        if stopCondition(stopConditionArgs) break end
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

function ouroboros!(bot::KingBot, diagonal::Diagonal, stopCondition::Function, stopConditionArgs)
    currentDirection, secondaryDirection = unpackDiagonal(diagonal)
    rotatingFunction = secondaryDirection == turnClockwise(currentDirection) ? turnClockwise : turnCounterClockwise
    ampl = 0

    while stopCondition(stopConditionArgs)
        move!(bot, currentDirection, 1+div(ampl, 2), stopCondition, stopConditionArgs)
        ampl += 1
        currentDirection=rotatingFunction(currentDirection)
    end
end


function snakeFromCorner!(bot::KingBot, stopCondition::Function, stopConditionArgs, markCondition::Function, markConditionArgs)
    verticalBorder = isborder(bot, North) ? North : (isborder(bot, South) ? South : nothing)
    horizontalBorder = isborder(bot, East) ? East : (isborder(bot, West) ? West : nothing)

    @assert isnothing(verticalBorder) || isnothing(horizontalBorder) == false

    vMovementDir = inverse(verticalBorder)
    hMovementDir = inverse(horizontalBorder)

    while !stopCondition(stopConditionArgs...)
        moveTill!(bot, hMovementDir, isborder, [bot,hMovementDir], markCondition, [markConditionArgs])
        hMovementDir = inverse(hMovementDir)
        !isborder(bot, vMovementDir) && move!(bot, vMovementDir)
    end
end



function checkAllBorders(bot::KingBot)
    return [HorizonSide(side) for side in 0:3 if isborder(bot, HorizonSide(side))]
end

function checkAllUnblockedPaths(bot::KingBot)
    return [HorizonSide(side) for side in 0:3 if !isborder(bot, HorizonSide(side))]
end

function getNextPerimeterSide(bot::KingBot, dominatingSide, rotatingFunction::Function=turnClockwise) 
    # check if theres only one possible move, if so - do it
    borders = checkAllBorders(bot)
    if length(borders) == 3 return first(checkAllUnblockedPaths(bot))
    elseif length(borders) == 2
        possibleMoves = setdiff!([inverse(rotatingFunction(side)) for side in borders], borders)
        if !isempty(bot.movesBuffer)
            possibleMoves = setdiff!(possibleMoves, [inverse(last(bot.movesBuffer).direction)])
        end
        length(possibleMoves) == 1 && return first(possibleMoves)
    end
    # if we cant determine the starting move, then we'll get it from supplied side, its useful for some starting positions
    isempty(bot.movesBuffer) && return rotatingFunction(dominatingSide)
    # otherwise we can determine the next move by previous move
    commonSide = rotatingFunction(last(bot.movesBuffer).direction)
    if !isborder(bot, commonSide)
        return commonSide
    end
    return last(bot.movesBuffer).direction
end

function isInside!(bot::KingBot, side::HorizonSide, rotatingFunction::Function=turnClockwise)
    moveTill!(bot, side, isborder, [bot, side])
    clearLogging!(bot)
    
    toCheck = checkAllBorders(bot)
    up, left, down, right = false, false, false, false
    maxY, maxX, minY, minX = 0, 0, 0, 0

    # these inner functions arent supposed to be used anywhere else, they are sort of Syntactic sugar
    # updates toCheck based on the bot's last moves and the type of rotatingFunction
    function excludeSides!()
        if isempty(bot.movesBuffer)
            side = rotatedNextMove()
            setdiff!(toCheck, [side])
        else
            side = rotatingFunction(last(bot.movesBuffer).direction)
            (bot.rx == 0 && bot.ry == 0) && setdiff!(toCheck, [side])
        end

        if !isempty(bot.movesBuffer) && (bot.rx == 0 && bot.ry == 0) && length(checkAllBorders(bot)) == 3
            empty!(toCheck)
        end
    end

    # the function returns next side to move around object after rotating it 
    function rotatedNextMove()
        return rotatingFunction(getNextPerimeterSide(bot, side, rotatingFunction))
    end

    # the function returns next side to move around object without rotating it 
    function nextMove()
        return getNextPerimeterSide(bot, side,rotatingFunction)
    end

    while true
        # update toCheck
        excludeSides!()

        # update flags to determine bot's position
        if !isempty(checkAllBorders(bot)) && isborder(bot, rotatedNextMove())
            maxY = max(maxY, bot.ry)
            minY = min(minY, bot.ry)
            maxX = max(maxX, bot.rx)
            minX = min(minX, bot.rx)
            if bot.ry >= maxY up = !isborder(bot, inverse(North)) end
            if bot.ry <= minY down = !isborder(bot, inverse(South)) end
            if bot.rx >= maxX right = !isborder(bot, inverse(East)) end
            if bot.rx <= minX left = !isborder(bot, inverse(West)) end
        end

        # if the toCheck is empty, the movement around structure is completed
        if isempty(toCheck)
            return any([up, left, down, right])
        end
        
        move!(bot, nextMove())

    end
end

function calculateArea!(bot::KingBot, side::HorizonSide, rotatingFunction::Function=turnClockwise)
    moveTill!(bot, side, isborder, [bot, side])
    clearLogging!(bot)

    toCheck = checkAllBorders(bot)
    cnt = 0
    # these inner functions arent supposed to be used anywhere else, they are sort of Syntactic sugar
    # check the left side and update counter
    function checkLeft()
        if isborder(bot, West)
            # putmarker!(bot)
            # println("+ $(bot.rx) ($(bot.rx), $(bot.ry)) ")
            cnt += bot.rx
        end
    end
    # check the right side and update counter
    function checkRight()
        if isborder(bot, East)
            # println("- $(bot.rx + 1) ($(bot.rx), $(bot.ry)) ")
            # putmarker!(bot)
            # add correction
            cnt -= bot.rx + 1
        end
    end

    # handle which side to update depending on the rotatingFunction
    function checkBoth!(side::HorizonSide)
        if side in (rotatingFunction(West), East) checkRight()
        else checkLeft()
        end
    end
    
    # the function returns next side to move around object after rotating it 
    function rotatedNextMove()
        return rotatingFunction(getNextPerimeterSide(bot, side, rotatingFunction))
    end
    
    # the function returns next side to move around object without rotating it 
    function nextMove()
        return getNextPerimeterSide(bot, side,rotatingFunction)
    end

    function lastMove()
        if isempty(bot.movesBuffer)
            return nextMove()
        end
        return last(bot.movesBuffer).direction
    end

    # updates toCheck based on the bot's last moves and the type of rotatingFunction
    function excludeSides!()
        # println(toCheck)
        if isempty(bot.movesBuffer)
            side = rotatedNextMove()
            if length(toCheck) == 3
                checkLeft()
                checkRight()
            end
            setdiff!(toCheck, [side])
        else
            side = rotatingFunction(last(bot.movesBuffer).direction)
            if (bot.rx == 0 && bot.ry == 0)
                if (length(checkAllBorders(bot)) != 3)
                    checkBoth!(lastMove())
                end
                setdiff!(toCheck, [side])
            end
        end

        if !isempty(bot.movesBuffer) && (bot.rx == 0 && bot.ry == 0) && length(checkAllBorders(bot)) == 3
            empty!(toCheck)
        end
    end

    while true
        # update toCheck
        excludeSides!()
        
        # if the toCheck is empty, the movement around structure is completed
        if isempty(toCheck)
            return cnt
        end
        
        # update counter
        if isborder(bot, rotatedNextMove()) && !isempty(bot.movesBuffer) && (bot.rx != 0 || bot.ry != 0)
            checkBoth!(lastMove())
            if length(checkAllBorders(bot)) == 3
                checkBoth!(inverse(lastMove()))
            end
        end
        
        move!(bot, nextMove())
    end
end