using Test
include("KingBot.jl")

getTrueCoords(r::KingBot) = r.robot.situation.robot_position
getRelativeCoords(r::KingBot) = (r.rx, r.ry)

@testset "diagonalsPacking" begin
    @test packDiagonal(North, West) == NorthWest
    @test packDiagonal(North, East) == NorthEast
    @test packDiagonal(South, West) == SouthWest
    @test packDiagonal(South, East) == SouthEast
    @test unpackDiagonal(NorthWest) == (North, West)
    @test unpackDiagonal(NorthEast) == (North, East)
    @test unpackDiagonal(SouthWest) == (South, West)
    @test unpackDiagonal(SouthEast) == (South, East)
    @test unpackDiagonal(SouthEast, false) == SouthEast
    @test_throws Exception unpackDiagonal(North, South)
    @test_throws Exception unpackDiagonal(North, North)
    @test_throws Exception unpackDiagonal(West, East)
end
# sumMoveLogs(MoveLog(North, 3), MoveLog(East, 2))
@testset "basicMoveLogs" begin
    @test sumMoveLogs(MoveLog(North, 2), MoveLog(North, 2)) == MoveLog(North, 4)
    @test sumMoveLogs(MoveLog(South, 2), MoveLog(North, 2)) == MoveLog(North, 0)
    @test sumMoveLogs(MoveLog(North, 2), MoveLog(South, 2)) == MoveLog(South, 0)
    @test sumMoveLogs(MoveLog(North, 3), MoveLog(South, 2)) == MoveLog(North, 1)
    @test sumMoveLogs(MoveLog(NW, 3), MoveLog(NW, 2)) == MoveLog(NW, 5)
    @test sumMoveLogs(MoveLog(NW, 3), MoveLog(SE, 2)) == MoveLog(NW, 1)
    @test sumMoveLogs(MoveLog(SE, 3), MoveLog(NW, 3)) == MoveLog(NW, 0)
    @test inverse(MoveLog(NorthWest, 2)) == MoveLog(SouthEast, 2)
    @test_throws Exception sumMoveLogs(MoveLog(North, 3), MoveLog(West, 3))
end

@testset "basicBotCommands" begin
    bot = KingBot(nothing,false)
    putmarker!(bot)

    @test HorizonSideRobots.ismarker(bot.robot) == true

    relativeX, relativeY = getRelativeCoords(bot)
    y,x = getTrueCoords(bot)
    move!(bot, North, 2)
    y2,x2 = getTrueCoords(bot)

    @test y-y2 == bot.ry-relativeY

    y,x = getTrueCoords(bot)
    move!(bot, East, 2)
    y2,x2 = getTrueCoords(bot)

    @test x2-x == bot.rx-relativeX
end

@testset "DiagonalCoords" begin
    bot = KingBot("default.sit",false)
    relativeX, relativeY = getRelativeCoords(bot)
    y,x = getTrueCoords(bot)
    move!(bot, NW)
    y2,x2 = getTrueCoords(bot)

    @test x2-x == bot.rx-relativeX
    @test y-y2 == bot.ry-relativeY
    @test bot.rx == relativeX-1
    @test bot.ry == relativeY+1


    relativeX, relativeY = getRelativeCoords(bot)
    y,x = getTrueCoords(bot)
    move!(bot, SW)
    y2,x2 = getTrueCoords(bot)

    @test x2-x == bot.rx-relativeX
    @test y-y2 == bot.ry-relativeY
    @test bot.rx == relativeX-1
    @test bot.ry == relativeY-1

    relativeX, relativeY = getRelativeCoords(bot)
    y,x = getTrueCoords(bot)
    move!(bot, NE)
    y2,x2 = getTrueCoords(bot)

    @test x2-x == bot.rx-relativeX
    @test y-y2 == bot.ry-relativeY
    @test bot.rx == relativeX+1
    @test bot.ry == relativeY+1

    relativeX, relativeY = getRelativeCoords(bot)
    y,x = getTrueCoords(bot)
    move!(bot, SE)
    y2,x2 = getTrueCoords(bot)

    @test x2-x == bot.rx-relativeX
    @test y-y2 == bot.ry-relativeY
    @test bot.rx == relativeX+1
    @test bot.ry == relativeY-1
end
@testset "DiagonalMovement" begin
    bot = KingBot("Situations/DiagonalMovement.sit", false)
    x, y = getRelativeCoords(bot)
    move!(bot, SW, 2)
    @test bot.rx == x-2
    @test bot.ry == y-2
    returnSafe!(bot)
    @test bot.rx == 0
    @test bot.ry == 0

    x, y = getRelativeCoords(bot)
    move!(bot, NW, 2)
    @test bot.rx == x-2
    @test bot.ry == y+2
    returnLinear!(bot)
    @test bot.rx == 0
    @test bot.ry == 0

    x, y = getRelativeCoords(bot)
    move!(bot, SE)
    move!(bot, SE)
    @test bot.rx == x+2
    @test bot.ry == y-2
    move!(bot, inverse(SE))
    move!(bot, NW)
    @test bot.rx == 0
    @test bot.ry == 0

    x, y = getRelativeCoords(bot)
    move!(bot, NE, 1)
    move!(bot, NE, 1)
    @test bot.rx == x+2
    @test bot.ry == y+2
    move!(bot, inverse(NE))
    returnSafe!(bot)
    @test bot.rx == 0
    @test bot.ry == 0
end