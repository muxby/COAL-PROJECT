TITLE Racing Car Game - COAL Final Project (RacingCar.asm)

; =====================================================================================
;  RACING CAR  -  console racing game for MASM (32-bit) + Irvine32
;
;  Screens : Start, Instructions, Name, Game, Pause, Result
;  Race    : player car + 4 computer cars, 3 laps per level, 2 levels
;            Level 1 = wide grassy track, Level 2 = narrow desert track
;  Road    : coins, barriers (obstacles), speed boosters and a bonus shield
;  Files   : the highest score and its holder are kept in highscore.dat
;
;  How the race is drawn
;    Every car has a position measured in 1/32 of a track row. The camera follows
;    the player, so the track scrolls towards the finish line. Each frame is first
;    built in a memory buffer (newChr / newAtr) and compared with the frame that is
;    already on the screen (oldChr / oldAtr). Only the cells that are different are
;    sent to the console, which keeps the picture free of flicker.
;
;  Only Irvine32 procedures are used for input, output and file handling.
;  No .IF / .ELSE / .WHILE directives are used anywhere in this file.
; =====================================================================================

INCLUDE Irvine32.inc

; ----------------------------------- screen layout -----------------------------------
VIEW_W          = 88                    ; width of the scrolling track view (columns 0..87)
VIEW_ROWS       = 27                    ; height of the track view
VIEW_TOP        = 2                     ; console row of the first view row
VIEW_CELLS      = VIEW_W * VIEW_ROWS    ; number of cells in the frame buffer
PLAYER_VROW     = 22                    ; view row that holds the back of the player car
ROAD_CENTER     = 44                    ; the road is centred on this column
PROGRESS_CELLS  = 26                    ; length of the lap progress bar

; ------------------------------------ race rules -------------------------------------
LAP_LEN         = 160                   ; track rows in one lap
TOTAL_LAPS      = 3
START_ROW       = 8                     ; track row where the cars wait for the start
LINE_ROW        = 14                    ; track row of the starting line
POS_SHIFT       = 5                     ; positions are stored in 1/32 of a row
FRAME_MS        = 40                    ; delay of one frame in milliseconds
FPS             = 25                    ; frames per second (1000 / FRAME_MS)
HUD_EVERY       = 4                     ; the HUD is refreshed every 4th frame

NUM_CARS        = 5                     ; car 0 is the player, cars 1..4 are opponents
CAR_W           = 3
CAR_H           = 3
MAX_GEAR        = 5
START_GEAR      = 3
STEER_STEP      = 2                     ; columns moved by one press of A / D

SLOW_FRAMES     = 50                    ; 2 seconds of reduced speed after a hit
BOOST_FRAMES    = 75                    ; 3 seconds of extra speed from a booster
BOOST_ADD       = 6                     ; speed added while boosted
HIT_COOLDOWN    = 25                    ; frames before another car crash can be counted
EDGE_COOLDOWN   = 12                    ; frames before another boundary hit can be counted
MSG_FRAMES      = 50                    ; how long an event message stays visible
LANE_CHANGE_ODDS = 80                   ; an opponent changes lane about once in 80 frames
LANE_CLEAR_ROWS = 6                     ; rows that must be free before a lane change

; --------------------------------------- items ---------------------------------------
MAX_ITEMS       = 24
K_COIN          = 0
K_OBST          = 1
K_BOOST         = 2
K_SHIELD        = 3
ITEM_FIRST_ROW  = 24                    ; first lap row that may hold an item
ITEM_SPACING    = 4                     ; rows between two item slots
NUM_SLOTS       = 31                    ; item slots in one lap

; -------------------------------------- scoring --------------------------------------
COIN_POINTS     = 10
LAP_POINTS      = 50
CAR_PENALTY     = 15
OBST_PENALTY    = 10
EDGE_PENALTY    = 5

; ------------------------------------- scenery ---------------------------------------
SCENE_ROWS      = 64                    ; the roadside scenery repeats every 64 rows
SCENE_MASK      = 63

; ------------------------------- colours (background*16 + text) ----------------------
ATTR_ROAD       = 80h                   ; asphalt: dark grey background
ATTR_DASH       = 8Fh                   ; white lane marks on the asphalt
ATTR_KERB_A     = 0Ch                   ; red kerb block
ATTR_KERB_B     = 0Fh                   ; white kerb block
ATTR_CHECK_A    = 0Fh                   ; white square of the finish line
ATTR_CHECK_B    = 00h                   ; black square of the finish line
ATTR_FLAME      = 8Eh                   ; yellow flame behind a boosted car
ATTR_SHIELDED   = 3Ch                   ; player car while the shield is active
ATTR_HURT       = 84h                   ; player car flashing after a hit
ATTR_HUD        = 1Fh                   ; white on blue
ATTR_HUD_VALUE  = 1Eh                   ; yellow on blue
ATTR_PANEL      = 0Bh
ATTR_TEXT       = 07h
ATTR_BRIGHT     = 0Fh
ATTR_VALUE      = 0Eh

; ------------------------------------ file record ------------------------------------
NAME_MAX        = 15                    ; longest player name
NAME_SIZE       = 16                    ; name buffer (name + zero byte)
HS_RECORD_SIZE  = 20                    ; 16 bytes of name + 4 bytes of score

.data

; ===================================== game state ====================================
level           DWORD 1
score           DWORD 0
difficulty      DWORD 1                 ; 0 = easy, 1 = normal, 2 = hard
soundOn         DWORD 1
gear            DWORD START_GEAR
raceFrames      DWORD 0                 ; frames played in this race (the race timer)
raceOver        DWORD 0                 ; 1 when the player has finished 3 laps
quitFlag        DWORD 0                 ; 1 when the player leaves the race
hudTick         DWORD 0
shieldOn        DWORD 0
hitCooldown     DWORD 0
edgeCooldown    DWORD 0
playerPos       DWORD 1                 ; live position of the player (1..5)
playerPlace     DWORD 1                 ; final position of the player
placeBonusWon   DWORD 0
newHighFlag     DWORD 0

; statistics of the current level
coinsCollected  DWORD 0
boostersTaken   DWORD 0
carCollisions   DWORD 0
obstacleHits    DWORD 0
boundaryHits    DWORD 0
totalPenalty    DWORD 0

; ============================ level settings (current level) =========================
; SetupLevel copies one record of levelTable into these seven variables, so the same
; race procedures work for both levels.
lvlTrackW       DWORD ?                 ; road width in columns
lvlPitch        DWORD ?                 ; distance between two lane marks
lvlMargin       DWORD ?                 ; free columns between kerb and first lane
lvlCoins        DWORD ?                 ; coins per lap
lvlObst         DWORD ?                 ; obstacles per lap
lvlBoost        DWORD ?                 ; speed boosters per lap
lvlLaneChange   DWORD ?                 ; 1 = opponents change lanes
roadLeft        DWORD ?                 ; first road column
roadRight       DWORD ?                 ; last road column

LEVEL_REC_SIZE  = 28
;                      width pitch margin coins obstacles boosters lane-change
levelTable      DWORD  44,   8,    2,     8,    3,        2,       0      ; level 1
                DWORD  32,   6,    1,     14,   6,        2,       1      ; level 2

; theme of the current level (copied from themeTable)
groundAttr      BYTE ?                  ; colour of the ground beside the road
sceneChars      BYTE 9 DUP(?)           ; 3 characters for each of the 3 scenery pieces
sceneAttr       BYTE 3 DUP(?)           ; colour of each scenery piece

THEME_REC_SIZE  = 13
; scenery piece 1 = top of a tree / cactus, 2 = its trunk, 3 = bush / rock
themeTable      BYTE 20h                            ; level 1: green grass
                BYTE 0DCh,0DBh,0DCh                 ; tree top
                BYTE ' ',0DBh,' '                   ; tree trunk
                BYTE 0B1h,0B1h,' '                  ; bush
                BYTE 2Ah,26h,2Ah
                BYTE 0E0h                           ; level 2: yellow sand
                BYTE 0C8h,0CEh,0BCh                 ; cactus arms
                BYTE ' ',0BAh,' '                   ; cactus stem
                BYTE 0DCh,0DCh,' '                  ; rock
                BYTE 0E2h,0E2h,0E6h

sceneKindL      BYTE SCENE_ROWS DUP(0)  ; scenery on the left of the road (0 = nothing)
sceneColL       BYTE SCENE_ROWS DUP(0)
sceneKindR      BYTE SCENE_ROWS DUP(0)  ; scenery on the right of the road
sceneColR       BYTE SCENE_ROWS DUP(0)

; ======================================= cars ========================================
; index 0 = player, 1..4 = opponents
carX            DWORD NUM_CARS DUP(0)   ; left column of the car
carPos          DWORD NUM_CARS DUP(0)   ; distance driven in 1/32 rows
carRow          DWORD NUM_CARS DUP(0)   ; track row of the back of the car
carBase         DWORD NUM_CARS DUP(0)   ; normal speed (1/32 rows per frame)
carSlow         DWORD NUM_CARS DUP(0)   ; frames of reduced speed that are left
carBoost        DWORD NUM_CARS DUP(0)   ; frames of boosted speed that are left
carLane         DWORD NUM_CARS DUP(0)   ; lane of the car (opponents)
carPrevLane     DWORD NUM_CARS DUP(0)   ; lane the car is leaving
carTargetX      DWORD NUM_CARS DUP(0)   ; column the car is sliding to
carLaps         DWORD NUM_CARS DUP(0)   ; laps completed
carDone         DWORD NUM_CARS DUP(0)   ; 1 when the car has finished the race
carRel          DWORD NUM_CARS DUP(0)   ; row of the car inside its current lap
carColor        BYTE 8Ch,89h,8Ah,8Dh,8Bh
startLane       DWORD 2,0,1,3,4         ; the player starts in the middle lane
gearSpeed       DWORD 6,8,10,12,14      ; player speed in each gear
oppSpeed        DWORD 9,10,11,12        ; normal speeds of the four opponents
placeBonus      DWORD 200,150,100,50,0  ; points for finishing 1st .. 5th
rankOrder       BYTE 0,1,2,3,4          ; cars sorted by distance (live ranking)
finishOrder     BYTE NUM_CARS DUP(0)    ; cars in the order they finished
finishCount     DWORD 0

carSprite       BYTE 0DCh,0DBh,0DCh     ; front of the car
                BYTE 0DBh,0B1h,0DBh     ; cabin
                BYTE 0DFh,0DBh,0DFh     ; back of the car

playerName      BYTE NAME_SIZE DUP(0)
oppName1        BYTE "BLUE BOLT",0
oppName2        BYTE "GREEN VIPER",0
oppName3        BYTE "PINK FURY",0
oppName4        BYTE "CYAN COMET",0
carNamePtr      DWORD OFFSET playerName, OFFSET oppName1, OFFSET oppName2
                DWORD OFFSET oppName3, OFFSET oppName4

; ====================================== items ========================================
itemKind        BYTE MAX_ITEMS DUP(0)   ; K_COIN, K_OBST, K_BOOST or K_SHIELD
itemActive      BYTE MAX_ITEMS DUP(0)   ; 1 while the item is still on the road
itemX           DWORD MAX_ITEMS DUP(0)  ; left column
itemRow         DWORD MAX_ITEMS DUP(0)  ; row inside the lap
itemCount       DWORD 0
slotUsed        BYTE NUM_SLOTS DUP(0)

;                    coin  obstacle  booster  shield
kindWidth       BYTE 2,    4,        3,       3
kindAttr        BYTE 8Eh,  0FCh,     9Fh,     0B0h
kindChars       BYTE "()",0,0
                BYTE 0B2h,0B2h,0B2h,0B2h
                BYTE "^^^",0
                BYTE "[S]",0

; =================================== frame buffers ===================================
newChr          BYTE VIEW_CELLS DUP(' ')
newAtr          BYTE VIEW_CELLS DUP(0)
oldChr          BYTE VIEW_CELLS DUP(0)
oldAtr          BYTE VIEW_CELLS DUP(0)
topWorld        DWORD 0                 ; track row shown on the first view row
rowWorld        DWORD 0                 ; track row that ComposeRow is building
lapBase         DWORD 0                 ; track row where the player's lap began
needGoto        DWORD 1
lastAttr        DWORD 0

; ================================= working variables =================================
testX           DWORD 0                 ; column tested by CarBlocked
testRow         DWORD 0                 ; row tested by CarBlocked
inputCount      DWORD 0
wantChange      DWORD 0
countStep       DWORD 0
msgPtr          DWORD OFFSET strEmpty
msgAttr         DWORD 7
msgTimer        DWORD 0

; ==================================== high score =====================================
scoreFile       BYTE "highscore.dat",0
fileHandle      DWORD 0
fileBuffer      BYTE HS_RECORD_SIZE DUP(0)
; the next two variables are saved together as one 20-byte record
highName        BYTE NAME_SIZE DUP(0)
highScore       DWORD 0
strNobody       BYTE "NOBODY YET",0
strDefaultName  BYTE "PLAYER",0
nameInput       BYTE 40 DUP(0)

; ===================================== big font ======================================
; 5 x 5 letters; every set bit is drawn as two block characters
bigFont         BYTE 11110b,10001b,11110b,10010b,10001b     ; 0  R
                BYTE 01110b,10001b,11111b,10001b,10001b     ; 1  A
                BYTE 01111b,10000b,10000b,10000b,01111b     ; 2  C
                BYTE 11111b,00100b,00100b,00100b,11111b     ; 3  I
                BYTE 10001b,11001b,10101b,10011b,10001b     ; 4  N
                BYTE 01111b,10000b,10011b,10001b,01111b     ; 5  G
                BYTE 11110b,00001b,01110b,00001b,11110b     ; 6  3
                BYTE 11110b,00001b,01110b,10000b,11111b     ; 7  2
                BYTE 00100b,01100b,00100b,00100b,01110b     ; 8  1
                BYTE 01110b,10001b,10001b,10001b,01110b     ; 9  O
titleGlyphs     BYTE 0,1,2,3,4,5,0FEh,2,1,0,0FFh            ; "RACING CAR"
countAttr       BYTE 4Fh,6Fh,2Fh                            ; box colour for 3, 2, 1

; ====================================== strings ======================================
strEmpty        BYTE 0
strPad3         BYTE "   ",0
ordStrings      BYTE "1st",0,"2nd",0,"3rd",0,"4th",0,"5th",0
strOf5          BYTE " of 5",0

; event messages (shown in the side panel, at most 26 characters)
msgCoin         BYTE "COIN  +10",0
msgLap          BYTE "LAP COMPLETE  +50",0
msgCarHit       BYTE "CAR CRASH  -15",0
msgObstHit      BYTE "BARRIER HIT  -10",0
msgEdgeHit      BYTE "TRACK EDGE  -5",0
msgBoost        BYTE "SPEED BOOST!",0
msgRivalBoost   BYTE "A RIVAL TOOK A BOOSTER",0
msgShieldOn     BYTE "SHIELD READY",0
msgShieldUsed   BYTE "SHIELD ABSORBED THE HIT",0
msgGo           BYTE "GO  GO  GO !",0

strStNormal     BYTE "NORMAL",0
strStBoost      BYTE "BOOSTED",0
strStSlow       BYTE "SLOWED",0
strStShield     BYTE "SHIELD ON",0

strEasy         BYTE "EASY",0
strNormal       BYTE "NORMAL",0
strHard         BYTE "HARD",0
diffNamePtr     DWORD OFFSET strEasy, OFFSET strNormal, OFFSET strHard
strOn           BYTE "ON",0
strOff          BYTE "OFF",0

; ----------------------------------- start screen ------------------------------------
strMenuTitle    BYTE "[ MAIN MENU ]",0
strMenu1        BYTE "[1]   START RACE",0
strMenu2        BYTE "[2]   INSTRUCTIONS",0
strMenu3        BYTE "[3]   QUIT",0
strMenu4        BYTE "[4]   DIFFICULTY :",0
strMenu5        BYTE "[5]   SOUND      :",0
strFameTitle    BYTE "[ HALL OF FAME ]",0
strFame1        BYTE "HIGHEST SCORE :",0
strFame2        BYTE "HELD BY       :",0
strFameLine     BYTE "------------------------------------",0
strRule1        BYTE "COIN +10    LAP +50    WIN +200",0
strRule2        BYTE "2ND +150    3RD +100   4TH +50",0
strRule3        BYTE "CAR CRASH -15     BARRIER -10",0
strRule4        BYTE "TRACK EDGE -5   (never below 0)",0
strMenuHint     BYTE "Press 1, 2 or 3 to choose   -   4 and 5 change the options",0
strCredits      BYTE "COAL Final Project  -  Fall 2026",0
strSubTitle     BYTE "T H E   C O N S O L E   G R A N D   P R I X",0
strBye          BYTE "Thanks for racing. Goodbye!",0

; every table entry is: column, row, colour, offset of the string  (0FFh ends a table)
startTable      BYTE 38,8,0Bh
                DWORD OFFSET strSubTitle
                BYTE 27,10,0Eh
                DWORD OFFSET strMenuTitle
                BYTE 16,12,0Fh
                DWORD OFFSET strMenu1
                BYTE 16,14,0Fh
                DWORD OFFSET strMenu2
                BYTE 16,16,0Fh
                DWORD OFFSET strMenu3
                BYTE 16,18,07h
                DWORD OFFSET strMenu4
                BYTE 16,20,07h
                DWORD OFFSET strMenu5
                BYTE 77,10,0Eh
                DWORD OFFSET strFameTitle
                BYTE 68,12,0Fh
                DWORD OFFSET strFame1
                BYTE 68,14,0Fh
                DWORD OFFSET strFame2
                BYTE 68,16,08h
                DWORD OFFSET strFameLine
                BYTE 68,17,0Ah
                DWORD OFFSET strRule1
                BYTE 68,18,0Ah
                DWORD OFFSET strRule2
                BYTE 68,19,0Ch
                DWORD OFFSET strRule3
                BYTE 68,20,0Ch
                DWORD OFFSET strRule4
                BYTE 31,25,0Bh
                DWORD OFFSET strMenuHint
                BYTE 44,27,08h
                DWORD OFFSET strCredits
                BYTE 0FFh

; -------------------------------- instructions screen --------------------------------
strInsTitle     BYTE " HOW TO PLAY ",0
strInsGoal      BYTE "GOAL",0
strIns1         BYTE "Race 3 laps against four computer cars and cross the checkered line first.",0
strIns2         BYTE "Level 1 is a wide grassy track. Level 2 is a narrow desert track with more traffic.",0
strInsCtl       BYTE "CONTROLS",0
strIns3         BYTE "A / D  or  Left / Right arrows ...... steer the car",0
strIns4         BYTE "W / S  or  Up / Down arrows ......... shift one gear up / down (5 gears)",0
strIns5         BYTE "P ................................... pause the race, P again to resume",0
strIns6         BYTE "X ................................... quit the race and go back to the Start screen",0
strInsRoad      BYTE "ON THE ROAD",0
strSmpCoin      BYTE "()",0
strSmpObst      BYTE 0B2h,0B2h,0B2h,0B2h,0
strSmpBoost     BYTE "^^^",0
strSmpShield    BYTE "[S]",0
strIns7         BYTE "Coin: +10 points. Level 2 has more coins on the road.",0
strIns8         BYTE "Barrier: -10 points and the car is slowed down for 2 seconds.",0
strIns9         BYTE "Speed booster: 3 seconds of extra speed. A rival can take it before you!",0
strIns10        BYTE "Shield (bonus item): absorbs your next crash with a car or a barrier.",0
strInsScore     BYTE "SCORING",0
strIns11        BYTE "Coin +10  |  Lap completed +50  |  Finish 1st +200, 2nd +150, 3rd +100, 4th +50, 5th +0",0
strIns12        BYTE "Hitting a rival car -15  |  Barrier -10  |  Track edge -5  |  The score never drops below 0",0
strInsTips      BYTE "TIPS",0
strIns13        BYTE "Rivals are slowed by barriers and track edges too, so a clean lap can win you places.",0
strIns14        BYTE "A higher gear is faster but leaves less time to react. Hitting a rival also slows you.",0
strInsKey       BYTE "Press any key to return to the Start screen",0

instrTable      BYTE 53,1,0Eh
                DWORD OFFSET strInsTitle
                BYTE 8,3,0Eh
                DWORD OFFSET strInsGoal
                BYTE 8,4,0Fh
                DWORD OFFSET strIns1
                BYTE 8,5,0Fh
                DWORD OFFSET strIns2
                BYTE 8,7,0Eh
                DWORD OFFSET strInsCtl
                BYTE 8,8,0Fh
                DWORD OFFSET strIns3
                BYTE 8,9,0Fh
                DWORD OFFSET strIns4
                BYTE 8,10,0Fh
                DWORD OFFSET strIns5
                BYTE 8,11,0Fh
                DWORD OFFSET strIns6
                BYTE 8,13,0Eh
                DWORD OFFSET strInsRoad
                BYTE 8,14,8Eh
                DWORD OFFSET strSmpCoin
                BYTE 16,14,0Fh
                DWORD OFFSET strIns7
                BYTE 8,15,0FCh
                DWORD OFFSET strSmpObst
                BYTE 16,15,0Fh
                DWORD OFFSET strIns8
                BYTE 8,16,9Fh
                DWORD OFFSET strSmpBoost
                BYTE 16,16,0Fh
                DWORD OFFSET strIns9
                BYTE 8,17,0B0h
                DWORD OFFSET strSmpShield
                BYTE 16,17,0Fh
                DWORD OFFSET strIns10
                BYTE 8,19,0Eh
                DWORD OFFSET strInsScore
                BYTE 8,20,0Fh
                DWORD OFFSET strIns11
                BYTE 8,21,0Fh
                DWORD OFFSET strIns12
                BYTE 8,23,0Eh
                DWORD OFFSET strInsTips
                BYTE 8,24,0Fh
                DWORD OFFSET strIns13
                BYTE 8,25,0Fh
                DWORD OFFSET strIns14
                BYTE 38,27,0Ah
                DWORD OFFSET strInsKey
                BYTE 0FFh

; ------------------------------------ name screen ------------------------------------
strNameTitle    BYTE " DRIVER LICENCE ",0
strNameAsk      BYTE "Type your name (max 15 letters), then press ENTER",0
strNamePrompt   BYTE "NAME > ",0
strNameHint     BYTE "Leave it empty to race as PLAYER",0

nameTable       BYTE 52,9,0Eh
                DWORD OFFSET strNameTitle
                BYTE 36,12,0Fh
                DWORD OFFSET strNameAsk
                BYTE 36,17,08h
                DWORD OFFSET strNameHint
                BYTE 36,14,0Eh
                DWORD OFFSET strNamePrompt
                BYTE 0FFh

; ------------------------------------ race screen ------------------------------------
strHudPlayer    BYTE "PLAYER:",0
strHudLevel     BYTE "LEVEL:",0
strHudLap       BYTE "LAP:",0
strHudOf3       BYTE " / 3",0
strHudScore     BYTE "SCORE:",0
strHudTime      BYTE "TIME:",0
strHudBest      BYTE "BEST:",0
strHudPos       BYTE "POS:",0
strHudOf5       BYTE " / 5",0
strHelpLine     BYTE "A / D : steer    W / S : gear up / down    P : pause    X : quit the race",0

hudTable        BYTE 1,0,ATTR_HUD
                DWORD OFFSET strHudPlayer
                BYTE 27,0,ATTR_HUD
                DWORD OFFSET strHudLevel
                BYTE 38,0,ATTR_HUD
                DWORD OFFSET strHudLap
                BYTE 44,0,ATTR_HUD
                DWORD OFFSET strHudOf3
                BYTE 52,0,ATTR_HUD
                DWORD OFFSET strHudScore
                BYTE 70,0,ATTR_HUD
                DWORD OFFSET strHudTime
                BYTE 84,0,ATTR_HUD
                DWORD OFFSET strHudBest
                BYTE 100,0,ATTR_HUD
                DWORD OFFSET strHudPos
                BYTE 106,0,ATTR_HUD
                DWORD OFFSET strHudOf5
                BYTE 8,29,08h
                DWORD OFFSET strHelpLine
                BYTE 0FFh

strPanTitle     BYTE " RACE  INFO ",0
strPanPos       BYTE "POSITION :",0
strPanGear      BYTE "GEAR     :",0
strPanStatus    BYTE "STATUS   :",0
strPanCoins     BYTE "COINS    :",0
strPanCrash     BYTE "CRASHES  :",0
strPanLap       BYTE "LAP PROGRESS",0
strPanStand     BYTE "STANDINGS",0
strPanLegend    BYTE "LEGEND",0
strLegCoin      BYTE "Coin        +10",0
strLegObst      BYTE "Barrier     -10",0
strLegBoost     BYTE "Booster   speed",0
strLegShield    BYTE "Shield    1 hit",0

panelTable      BYTE 98,2,0Eh
                DWORD OFFSET strPanTitle
                BYTE 91,4,07h
                DWORD OFFSET strPanPos
                BYTE 105,4,07h
                DWORD OFFSET strOf5
                BYTE 91,5,07h
                DWORD OFFSET strPanGear
                BYTE 91,6,07h
                DWORD OFFSET strPanStatus
                BYTE 91,7,07h
                DWORD OFFSET strPanCoins
                BYTE 91,8,07h
                DWORD OFFSET strPanCrash
                BYTE 91,10,0Bh
                DWORD OFFSET strPanLap
                BYTE 91,13,0Bh
                DWORD OFFSET strPanStand
                BYTE 91,20,0Bh
                DWORD OFFSET strPanLegend
                BYTE 91,21,8Eh
                DWORD OFFSET strSmpCoin
                BYTE 97,21,07h
                DWORD OFFSET strLegCoin
                BYTE 91,22,0FCh
                DWORD OFFSET strSmpObst
                BYTE 97,22,07h
                DWORD OFFSET strLegObst
                BYTE 91,23,9Fh
                DWORD OFFSET strSmpBoost
                BYTE 97,23,07h
                DWORD OFFSET strLegBoost
                BYTE 91,24,0B0h
                DWORD OFFSET strSmpShield
                BYTE 97,24,07h
                DWORD OFFSET strLegShield
                BYTE 0FFh

strGetReady     BYTE "GET  READY",0
strPaused       BYTE "GAME  PAUSED",0
strPause1       BYTE "[P] or [1]    Resume the race",0
strPause2       BYTE "[2] or [Q]    Quit to Start screen",0
strFinish       BYTE "F I N I S H !",0
strFinishPos    BYTE "You finished ",0

; ----------------------------------- result screen -----------------------------------
strResTitle     BYTE "RACE RESULT   -   LEVEL ",0
strResDone      BYTE " COMPLETE",0
strResStats     BYTE " YOUR RACE ",0
strResOrder     BYTE " FINISHING ORDER ",0
strRes1         BYTE "DRIVER",0
strRes2         BYTE "LEVEL COMPLETED",0
strRes3         BYTE "FINAL POSITION",0
strRes4         BYTE "RACE TIME",0
strRes5         BYTE "COINS COLLECTED",0
strRes6         BYTE "SPEED BOOSTERS",0
strRes7         BYTE "CAR COLLISIONS",0
strRes8         BYTE "BARRIER HITS",0
strRes9         BYTE "BOUNDARY HITS",0
strRes10        BYTE "TOTAL PENALTIES",0
strRes11        BYTE "POSITION BONUS",0
strRes12        BYTE "FINAL SCORE",0
strRes13        BYTE "HIGHEST SCORE",0
strResBy        BYTE "  by ",0
strNewHigh      BYTE "***  NEW HIGH SCORE !  ***",0
strResOpt1      BYTE "[1]  NEXT LEVEL",0
strResOpt2      BYTE "[2]  RACE AGAIN",0
strResOpt3      BYTE "[3]  CANCEL",0
strResHint      BYTE "Press the number of your choice",0
strResYou       BYTE "  <  YOU",0

resultTable     BYTE 31,3,0Eh
                DWORD OFFSET strResStats
                BYTE 84,3,0Eh
                DWORD OFFSET strResOrder
                BYTE 10,5,07h
                DWORD OFFSET strRes1
                BYTE 10,6,07h
                DWORD OFFSET strRes2
                BYTE 10,7,07h
                DWORD OFFSET strRes3
                BYTE 10,8,07h
                DWORD OFFSET strRes4
                BYTE 10,10,07h
                DWORD OFFSET strRes5
                BYTE 10,11,07h
                DWORD OFFSET strRes6
                BYTE 10,12,07h
                DWORD OFFSET strRes7
                BYTE 10,13,07h
                DWORD OFFSET strRes8
                BYTE 10,14,07h
                DWORD OFFSET strRes9
                BYTE 10,15,07h
                DWORD OFFSET strRes10
                BYTE 10,16,07h
                DWORD OFFSET strRes11
                BYTE 10,18,0Fh
                DWORD OFFSET strRes12
                BYTE 10,20,07h
                DWORD OFFSET strRes13
                BYTE 50,25,0Fh
                DWORD OFFSET strResOpt2
                BYTE 80,25,0Fh
                DWORD OFFSET strResOpt3
                BYTE 44,27,08h
                DWORD OFFSET strResHint
                BYTE 0FFh

.code

; =====================================================================================
;  main : moves between the Start screen, the race and the Result screen
; =====================================================================================
main PROC
    call Randomize
    call LoadHighScore

mainMenu:
    call StartScreen                    ; AL = '1', '2' or '3'
    cmp al,'2'
    je mainInstructions
    cmp al,'3'
    je mainQuit
    call NameScreen

mainNewGame:                            ; a new game always starts at level 1 with 0 points
    mov level,1
    mov score,0

mainPlayLevel:
    call RunRace
    cmp quitFlag,0
    jne mainMenu                        ; X or "Quit" in the pause box
    call ResultScreen                   ; AL = '1' next level, '2' race again, '3' cancel
    cmp al,'1'
    je mainNextLevel
    cmp al,'2'
    je mainNewGame
    jmp mainMenu

mainNextLevel:
    mov level,2                         ; the score carries over to level 2
    jmp mainPlayLevel

mainInstructions:
    call InstructionScreen
    jmp mainMenu

mainQuit:
    mov eax,ATTR_TEXT
    call SetTextColor
    call Clrscr
    mov bl,46
    mov bh,13
    mov edx,OFFSET strBye
    call PrintAt
    mov dl,0
    mov dh,20
    call Gotoxy
    exit
main ENDP

; =====================================================================================
;  GENERAL OUTPUT HELPERS
; =====================================================================================

; -------------------------------------------------------------------------------------
; PrintAt : writes a string at a screen position using the current colour
; Receives: BL = column, BH = row, EDX = offset of the string
; -------------------------------------------------------------------------------------
PrintAt PROC
    push edx
    mov dl,bl
    mov dh,bh
    call Gotoxy
    pop edx
    call WriteString
    ret
PrintAt ENDP

; -------------------------------------------------------------------------------------
; PrintNumAt : writes an unsigned number at a screen position
; Receives: BL = column, BH = row, EAX = number
; -------------------------------------------------------------------------------------
PrintNumAt PROC
    push edx
    mov dl,bl
    mov dh,bh
    call Gotoxy
    call WriteDec
    pop edx
    ret
PrintNumAt ENDP

; -------------------------------------------------------------------------------------
; PrintTable : writes a list of coloured strings
; Receives: ESI = offset of a table of entries (column, row, colour, string offset)
;           The table ends with the byte 0FFh.
; -------------------------------------------------------------------------------------
PrintTable PROC
    pushad
ptNext:
    mov dl,[esi]
    cmp dl,0FFh
    je ptDone
    mov dh,[esi+1]
    call Gotoxy
    movzx eax,BYTE PTR [esi+2]
    call SetTextColor
    mov edx,[esi+3]
    call WriteString
    add esi,7
    jmp ptNext
ptDone:
    popad
    ret
PrintTable ENDP

; -------------------------------------------------------------------------------------
; RepeatChar : writes the same character several times
; Receives: AL = character, ECX = how many times (0 or less writes nothing)
; -------------------------------------------------------------------------------------
RepeatChar PROC
    push ecx
rcNext:
    cmp ecx,0
    jle rcDone
    call WriteChar
    dec ecx
    jmp rcNext
rcDone:
    pop ecx
    ret
RepeatChar ENDP

; -------------------------------------------------------------------------------------
; WritePadded : writes a string and fills the rest of a field with spaces, so that an
;               older and longer text is fully erased
; Receives: EDX = offset of the string, ECX = width of the field
; -------------------------------------------------------------------------------------
WritePadded PROC
    pushad
    mov esi,edx
wpNext:
    cmp ecx,0
    je wpDone
    mov al,[esi]
    cmp al,0
    je wpFill
    call WriteChar
    inc esi
    dec ecx
    jmp wpNext
wpFill:
    mov al,' '
    call WriteChar
    dec ecx
    jnz wpFill
wpDone:
    popad
    ret
WritePadded ENDP

; -------------------------------------------------------------------------------------
; WriteTwoDigits : writes a number below 100 with a leading zero (used by the timer)
; Receives: EAX = number
; -------------------------------------------------------------------------------------
WriteTwoDigits PROC
    push eax
    cmp eax,10
    jae wtNumber
    push eax
    mov al,'0'
    call WriteChar
    pop eax
wtNumber:
    call WriteDec
    pop eax
    ret
WriteTwoDigits ENDP

; -------------------------------------------------------------------------------------
; WriteRaceTime : writes the race time as mm:ss at the cursor
; -------------------------------------------------------------------------------------
WriteRaceTime PROC
    pushad
    mov eax,raceFrames
    mov edx,0
    mov ebx,FPS
    div ebx                             ; EAX = seconds
    mov edx,0
    mov ebx,60
    div ebx                             ; EAX = minutes, EDX = seconds
    push edx
    call WriteTwoDigits
    mov al,':'
    call WriteChar
    pop eax
    call WriteTwoDigits
    popad
    ret
WriteRaceTime ENDP

; -------------------------------------------------------------------------------------
; DrawBox : draws a double-line frame and blanks its inside with the current colour
; Receives: DL = left column, DH = top row, BL = width, BH = height (outer size)
; -------------------------------------------------------------------------------------
DrawBox PROC
    pushad
    movzx ecx,bl
    sub ecx,2                           ; ECX = columns between the two side lines
    call Gotoxy                         ; top line
    mov al,0C9h
    call WriteChar
    mov al,0CDh
    call RepeatChar
    mov al,0BBh
    call WriteChar
    movzx esi,bh
    sub esi,2                           ; ESI = rows between top and bottom line
dbMiddle:
    cmp esi,0
    jle dbBottom
    inc dh
    call Gotoxy
    mov al,0BAh
    call WriteChar
    mov al,' '
    call RepeatChar
    mov al,0BAh
    call WriteChar
    dec esi
    jmp dbMiddle
dbBottom:
    inc dh
    call Gotoxy
    mov al,0C8h
    call WriteChar
    mov al,0CDh
    call RepeatChar
    mov al,0BCh
    call WriteChar
    popad
    ret
DrawBox ENDP

; -------------------------------------------------------------------------------------
; DrawBigGlyph : draws one 5 x 5 character of the big font (10 columns, 5 rows)
; Receives: EAX = glyph number, DL = column, DH = row; uses the current colour
; -------------------------------------------------------------------------------------
DrawBigGlyph PROC
    pushad
    lea esi,[eax+eax*4]                 ; 5 bytes for every glyph
    add esi,OFFSET bigFont
    mov ecx,5                           ; rows
bgRow:
    call Gotoxy
    mov bl,[esi]
    shl bl,3                            ; bring bit 4 to the top of BL
    mov bh,5                            ; bits in a row
bgBit:
    mov al,' '
    shl bl,1                            ; next bit goes to the carry flag
    jnc bgPut
    mov al,0DBh
bgPut:
    call WriteChar
    call WriteChar
    dec bh
    jnz bgBit
    inc esi
    inc dh
    dec ecx
    jnz bgRow
    popad
    ret
DrawBigGlyph ENDP

; -------------------------------------------------------------------------------------
; DrawTitle : draws "RACING CAR" with the big font on rows 1..5
; -------------------------------------------------------------------------------------
DrawTitle PROC
    pushad
    mov eax,yellow
    call SetTextColor
    mov esi,OFFSET titleGlyphs
    mov dl,8
    mov dh,1
dtNext:
    movzx eax,BYTE PTR [esi]
    cmp eax,0FFh                        ; end of the title
    je dtDone
    cmp eax,0FEh                        ; gap between the two words
    jne dtGlyph
    add dl,6
    mov eax,lightRed                    ; the second word has another colour
    call SetTextColor
    jmp dtAdvance
dtGlyph:
    call DrawBigGlyph
    add dl,11
dtAdvance:
    inc esi
    jmp dtNext
dtDone:
    popad
    ret
DrawTitle ENDP

; -------------------------------------------------------------------------------------
; PlayBeep : short sound effect (the console bell), only when sound is switched on
; -------------------------------------------------------------------------------------
PlayBeep PROC
    cmp soundOn,0
    je pbDone
    push eax
    mov al,7
    call WriteChar
    pop eax
pbDone:
    ret
PlayBeep ENDP

; -------------------------------------------------------------------------------------
; DrainKeys : throws away key presses that are still waiting in the keyboard buffer
; -------------------------------------------------------------------------------------
DrainKeys PROC
    pushad
    mov inputCount,40
dkNext:
    call ReadKey
    jz dkDone                           ; nothing left
    dec inputCount
    jnz dkNext
dkDone:
    popad
    ret
DrainKeys ENDP

; -------------------------------------------------------------------------------------
; CopyString : copies a zero-terminated string and always terminates the copy
; Receives: ESI = source, EDI = destination, ECX = size of the destination buffer
; -------------------------------------------------------------------------------------
CopyString PROC
    pushad
csNext:
    cmp ecx,1
    jbe csEnd                           ; keep one byte for the zero
    mov al,[esi]
    cmp al,0
    je csEnd
    mov [edi],al
    inc esi
    inc edi
    dec ecx
    jmp csNext
csEnd:
    mov BYTE PTR [edi],0
    popad
    ret
CopyString ENDP

; =====================================================================================
;  FILE HANDLING  (highest score and the name of its holder)
; =====================================================================================

; -------------------------------------------------------------------------------------
; LoadHighScore : reads highscore.dat; when the file is missing the score is 0
; -------------------------------------------------------------------------------------
LoadHighScore PROC
    pushad
    mov edx,OFFSET scoreFile
    call OpenInputFile
    cmp eax,INVALID_HANDLE_VALUE
    je lhDefault                        ; no file yet
    mov fileHandle,eax
    mov edx,OFFSET fileBuffer
    mov ecx,HS_RECORD_SIZE
    call ReadFromFile
    jc lhBadFile
    cmp eax,HS_RECORD_SIZE
    jne lhBadFile
    mov eax,fileHandle
    call CloseFile
    cld                                 ; copy the record: name + score
    mov esi,OFFSET fileBuffer
    mov edi,OFFSET highName
    mov ecx,HS_RECORD_SIZE
    rep movsb
    mov highName[NAME_MAX],0            ; the name must end with a zero
    jmp lhDone
lhBadFile:
    mov eax,fileHandle
    call CloseFile
lhDefault:
    mov highScore,0
    mov esi,OFFSET strNobody
    mov edi,OFFSET highName
    mov ecx,NAME_SIZE
    call CopyString
lhDone:
    popad
    ret
LoadHighScore ENDP

; -------------------------------------------------------------------------------------
; SaveHighScore : writes the name and the highest score to highscore.dat
; -------------------------------------------------------------------------------------
SaveHighScore PROC
    pushad
    mov edx,OFFSET scoreFile
    call CreateOutputFile
    cmp eax,INVALID_HANDLE_VALUE
    je shDone                           ; the file could not be created
    mov fileHandle,eax
    mov edx,OFFSET highName             ; highName and highScore form one record
    mov ecx,HS_RECORD_SIZE
    call WriteToFile
    mov eax,fileHandle
    call CloseFile
shDone:
    popad
    ret
SaveHighScore ENDP

; =====================================================================================
;  START, INSTRUCTIONS AND NAME SCREENS
; =====================================================================================

; -------------------------------------------------------------------------------------
; StartScreen : shows the menu and the highest score
; Returns: AL = '1' (start), '2' (instructions) or '3' (quit)
; -------------------------------------------------------------------------------------
StartScreen PROC
    call DrawStartScreen
ssKey:
    call ReadChar
    cmp al,'1'
    je ssDone
    cmp al,'2'
    je ssDone
    cmp al,'3'
    je ssDone
    cmp al,'4'
    je ssDifficulty
    cmp al,'5'
    je ssSound
    jmp ssKey
ssDifficulty:                           ; easy -> normal -> hard -> easy
    inc difficulty
    cmp difficulty,3
    jb ssRefresh
    mov difficulty,0
    jmp ssRefresh
ssSound:
    xor soundOn,1
    call PlayBeep
ssRefresh:
    call DrawStartValues
    jmp ssKey
ssDone:
    ret
StartScreen ENDP

; -------------------------------------------------------------------------------------
; DrawStartScreen : draws the complete Start screen
; -------------------------------------------------------------------------------------
DrawStartScreen PROC
    pushad
    mov eax,ATTR_TEXT
    call SetTextColor
    call Clrscr
    call DrawTitle
    mov eax,ATTR_BRIGHT                 ; checkered strip under the title
    call SetTextColor
    mov dl,8
    mov dh,7
    call Gotoxy
    mov ecx,52
dsStrip:
    mov al,0DBh
    call WriteChar
    mov al,' '
    call WriteChar
    dec ecx
    jnz dsStrip
    mov eax,ATTR_PANEL                  ; menu box and hall of fame box
    call SetTextColor
    mov dl,10
    mov dh,10
    mov bl,48
    mov bh,13
    call DrawBox
    mov dl,62
    call DrawBox
    mov esi,OFFSET startTable
    call PrintTable
    call DrawStartValues
    popad
    ret
DrawStartScreen ENDP

; -------------------------------------------------------------------------------------
; DrawStartValues : writes the values of the Start screen that can change
; -------------------------------------------------------------------------------------
DrawStartValues PROC
    pushad
    mov eax,ATTR_VALUE
    call SetTextColor
    mov bl,84
    mov bh,12
    mov eax,highScore
    call PrintNumAt
    mov bl,84
    mov bh,14
    mov edx,OFFSET highName
    call PrintAt
    mov eax,lightGreen
    call SetTextColor
    mov dl,35
    mov dh,18
    call Gotoxy
    mov eax,difficulty
    mov edx,diffNamePtr[eax*4]
    mov ecx,8
    call WritePadded
    mov dl,35
    mov dh,20
    call Gotoxy
    mov edx,OFFSET strOn
    cmp soundOn,0
    jne dvSound
    mov edx,OFFSET strOff
dvSound:
    mov ecx,4
    call WritePadded
    mov dl,0                            ; park the cursor
    mov dh,29
    call Gotoxy
    popad
    ret
DrawStartValues ENDP

; -------------------------------------------------------------------------------------
; InstructionScreen : explains the controls, the objects and the scoring rules
; -------------------------------------------------------------------------------------
InstructionScreen PROC
    pushad
    mov eax,ATTR_TEXT
    call SetTextColor
    call Clrscr
    mov eax,ATTR_PANEL
    call SetTextColor
    mov dl,4
    mov dh,1
    mov bl,112
    mov bh,28
    call DrawBox
    mov esi,OFFSET instrTable
    call PrintTable
    mov dl,0
    mov dh,29
    call Gotoxy
    call ReadChar                       ; any key returns to the Start screen
    popad
    ret
InstructionScreen ENDP

; -------------------------------------------------------------------------------------
; NameScreen : asks for the name of the player and stores it in playerName
; -------------------------------------------------------------------------------------
NameScreen PROC
    pushad
    mov eax,ATTR_TEXT
    call SetTextColor
    call Clrscr
    call DrawTitle
    mov eax,ATTR_PANEL
    call SetTextColor
    mov dl,30
    mov dh,9
    mov bl,60
    mov bh,11
    call DrawBox
    mov esi,OFFSET nameTable
    call PrintTable
    mov dl,43                           ; the name is typed right after the prompt
    mov dh,14
    call Gotoxy
    mov eax,ATTR_BRIGHT
    call SetTextColor
    mov edx,OFFSET nameInput
    mov ecx,38                          ; read the whole line, even a long one
    call ReadString                     ; EAX = number of characters typed
    mov nameInput[NAME_MAX],0           ; keep only the first 15 characters
    mov esi,OFFSET nameInput
    cmp eax,0
    jne nsCopy
    mov esi,OFFSET strDefaultName       ; nothing typed
nsCopy:
    mov edi,OFFSET playerName
    mov ecx,NAME_SIZE
    call CopyString
    popad
    ret
NameScreen ENDP

; =====================================================================================
;  LEVEL AND RACE SET-UP
; =====================================================================================

; -------------------------------------------------------------------------------------
; SetupLevel : copies the settings and the theme of the current level into the
;              variables used by the race procedures
; -------------------------------------------------------------------------------------
SetupLevel PROC
    pushad
    cld
    mov eax,level
    dec eax
    imul eax,LEVEL_REC_SIZE
    mov esi,OFFSET levelTable
    add esi,eax
    mov edi,OFFSET lvlTrackW
    mov ecx,7
    rep movsd
    mov eax,lvlTrackW                   ; the road is centred in the view
    shr eax,1
    mov ebx,ROAD_CENTER
    sub ebx,eax
    mov roadLeft,ebx
    add ebx,lvlTrackW
    dec ebx
    mov roadRight,ebx
    mov eax,level                       ; theme: grass or desert
    dec eax
    imul eax,THEME_REC_SIZE
    mov esi,OFFSET themeTable
    add esi,eax
    mov edi,OFFSET groundAttr
    mov ecx,THEME_REC_SIZE
    rep movsb
    popad
    ret
SetupLevel ENDP

; -------------------------------------------------------------------------------------
; GetLaneX : column of a car that drives in the middle of a lane
; Receives: EAX = lane (0..4)      Returns: EAX = left column of the car
; -------------------------------------------------------------------------------------
GetLaneX PROC
    push ebx
    imul eax,lvlPitch
    add eax,roadLeft
    add eax,lvlMargin
    mov ebx,lvlPitch
    shr ebx,1
    add eax,ebx
    dec eax
    pop ebx
    ret
GetLaneX ENDP

; -------------------------------------------------------------------------------------
; InitRace : resets the cars, the statistics, the scenery and the items of a level
; -------------------------------------------------------------------------------------
InitRace PROC
    pushad
    mov eax,0
    mov raceFrames,eax
    mov raceOver,eax
    mov quitFlag,eax
    mov hudTick,eax
    mov shieldOn,eax
    mov hitCooldown,eax
    mov edgeCooldown,eax
    mov finishCount,eax
    mov msgTimer,eax
    mov newHighFlag,eax
    mov placeBonusWon,eax
    mov coinsCollected,eax
    mov boostersTaken,eax
    mov carCollisions,eax
    mov obstacleHits,eax
    mov boundaryHits,eax
    mov totalPenalty,eax
    mov playerPos,1
    mov gear,START_GEAR

    mov esi,0                           ; put the five cars side by side on the grid
irCar:
    mov eax,esi
    mov rankOrder[esi],al               ; the live ranking starts as 0,1,2,3,4
    mov eax,startLane[esi*4]
    mov carLane[esi*4],eax
    mov carPrevLane[esi*4],eax
    call GetLaneX
    mov carX[esi*4],eax
    mov carTargetX[esi*4],eax
    mov carRow[esi*4],START_ROW
    mov carPos[esi*4],START_ROW * 32
    mov carSlow[esi*4],0
    mov carBoost[esi*4],0
    mov carLaps[esi*4],0
    mov carDone[esi*4],0
    mov carRel[esi*4],0
    inc esi
    cmp esi,NUM_CARS
    jb irCar

    mov eax,gearSpeed[(START_GEAR-1)*4] ; player speed of the starting gear
    mov carBase,eax

    mov eax,4                           ; give the four speeds to the opponents in a
    call RandomRange                    ; random order, adjusted by the difficulty
    mov ebx,eax
    mov esi,1
irSpeed:
    mov eax,ebx
    and eax,3
    mov eax,oppSpeed[eax*4]
    add eax,difficulty
    dec eax                             ; easy -1, normal 0, hard +1
    mov carBase[esi*4],eax
    inc ebx
    inc esi
    cmp esi,NUM_CARS
    jb irSpeed

    call GenerateScenery
    call GenerateItems
    call InvalidateFrame
    popad
    ret
InitRace ENDP

; -------------------------------------------------------------------------------------
; GenerateScenery : fills the scenery tables of both sides of the road
; -------------------------------------------------------------------------------------
GenerateScenery PROC
    pushad
    mov esi,OFFSET sceneKindL           ; left side: columns 1 .. roadLeft-6
    mov edi,OFFSET sceneColL
    mov ebx,1
    mov ecx,roadLeft
    sub ecx,6
    call GenerateSide
    mov esi,OFFSET sceneKindR           ; right side: roadRight+3 .. VIEW_W-4
    mov edi,OFFSET sceneColR
    mov ebx,roadRight
    add ebx,3
    mov ecx,VIEW_W-3
    sub ecx,ebx
    call GenerateSide
    popad
    ret
GenerateScenery ENDP

; -------------------------------------------------------------------------------------
; GenerateSide : places trees (2 rows high) and bushes at random on one side
; Receives: ESI = kind table, EDI = column table, EBX = first column, ECX = column range
; -------------------------------------------------------------------------------------
GenerateSide PROC
    pushad
    mov edx,0
gsClear:
    mov BYTE PTR [esi+edx],0
    inc edx
    cmp edx,SCENE_ROWS
    jb gsClear
    mov edx,0
gsRow:
    cmp BYTE PTR [esi+edx],0
    jne gsNext                          ; the top of a tree is already here
    mov eax,5
    call RandomRange                    ; 0 = tree, 1 = bush, 2..4 = nothing
    cmp eax,1
    ja gsNext
    je gsBush
    cmp edx,SCENE_ROWS-1                ; a tree also needs the next row
    jae gsNext
    mov eax,ecx
    call RandomRange
    add eax,ebx
    mov BYTE PTR [esi+edx],2            ; trunk
    mov [edi+edx],al
    mov BYTE PTR [esi+edx+1],1          ; tree top one row further up the road
    mov [edi+edx+1],al
    jmp gsNext
gsBush:
    mov eax,ecx
    call RandomRange
    add eax,ebx
    mov BYTE PTR [esi+edx],3
    mov [edi+edx],al
gsNext:
    inc edx
    cmp edx,SCENE_ROWS
    jb gsRow
    popad
    ret
GenerateSide ENDP

; -------------------------------------------------------------------------------------
; GenerateItems : new random coins, obstacles, boosters and one shield for a lap
; -------------------------------------------------------------------------------------
GenerateItems PROC
    pushad
    mov ecx,0
giClear:
    mov slotUsed[ecx],0
    inc ecx
    cmp ecx,NUM_SLOTS
    jb giClear
    mov itemCount,0
    mov edx,K_COIN
    mov ecx,lvlCoins
    call AddItems
    mov edx,K_OBST
    mov ecx,lvlObst
    call AddItems
    mov edx,K_BOOST
    mov ecx,lvlBoost
    call AddItems
    mov edx,K_SHIELD
    mov ecx,1
    call AddItems
    popad
    ret
GenerateItems ENDP

; -------------------------------------------------------------------------------------
; AddItems : adds items of one kind at random free slots of the lap
; Receives: EDX = kind, ECX = how many
; -------------------------------------------------------------------------------------
AddItems PROC
    pushad
aiNext:
    cmp ecx,0
    je aiDone
    mov edi,itemCount
    cmp edi,MAX_ITEMS
    jae aiDone
    mov eax,NUM_SLOTS                   ; pick a slot, walk on until a free one is found
    call RandomRange
aiProbe:
    cmp slotUsed[eax],0
    je aiFree
    inc eax
    cmp eax,NUM_SLOTS
    jb aiProbe
    mov eax,0
    jmp aiProbe
aiFree:
    mov slotUsed[eax],1
    imul eax,ITEM_SPACING
    add eax,ITEM_FIRST_ROW
    mov itemRow[edi*4],eax
    movzx ebx,kindWidth[edx]            ; random column, one column away from the kerbs
    mov eax,lvlTrackW
    sub eax,ebx
    dec eax
    call RandomRange
    add eax,roadLeft
    inc eax
    mov itemX[edi*4],eax
    mov itemKind[edi],dl
    mov itemActive[edi],1
    inc itemCount
    dec ecx
    jmp aiNext
aiDone:
    popad
    ret
AddItems ENDP

; =====================================================================================
;  FRAME BUFFER : building a frame in memory and sending the changes to the console
; =====================================================================================

; -------------------------------------------------------------------------------------
; InvalidateFrame : forgets what is on the screen, so the next frame is drawn in full
; -------------------------------------------------------------------------------------
InvalidateFrame PROC
    pushad
    cld
    mov edi,OFFSET oldChr
    mov ecx,VIEW_CELLS
    mov al,0
    rep stosb
    popad
    ret
InvalidateFrame ENDP

; -------------------------------------------------------------------------------------
; PutCell : stores one character in the frame buffer (cells outside the view are skipped)
; Receives: EBX = column, ECX = view row, AL = character, AH = colour
; -------------------------------------------------------------------------------------
PutCell PROC
    push edi
    cmp ecx,VIEW_ROWS                   ; unsigned compare also rejects negative rows
    jae pcSkip
    cmp ebx,VIEW_W
    jae pcSkip
    mov edi,ecx
    imul edi,VIEW_W
    add edi,ebx
    mov newChr[edi],al
    mov newAtr[edi],ah
pcSkip:
    pop edi
    ret
PutCell ENDP

; -------------------------------------------------------------------------------------
; ComposeFrame : builds the whole track view in the frame buffer
; -------------------------------------------------------------------------------------
ComposeFrame PROC
    pushad
    mov eax,carRow                      ; the camera follows the player
    add eax,PLAYER_VROW
    mov topWorld,eax
    mov ecx,0
cfRow:
    mov eax,topWorld
    sub eax,ecx
    mov rowWorld,eax
    call ComposeRow
    inc ecx
    cmp ecx,VIEW_ROWS
    jb cfRow
    call ComposeItems
    call ComposeCars
    popad
    ret
ComposeFrame ENDP

; -------------------------------------------------------------------------------------
; ComposeRow : builds one row: ground, scenery, kerbs, road, lane marks, start/finish
; Receives: ECX = view row; rowWorld = track row shown on it
; -------------------------------------------------------------------------------------
ComposeRow PROC
    pushad
    mov edi,ecx
    imul edi,VIEW_W                     ; EDI = offset of the row in the buffer

    mov ebx,0                           ; 1) ground in the colour of the theme
    mov al,groundAttr
crGround:
    mov newChr[edi+ebx],' '
    mov newAtr[edi+ebx],al
    inc ebx
    cmp ebx,VIEW_W
    jb crGround

    mov esi,rowWorld                    ; 2) scenery on both sides
    and esi,SCENE_MASK
    movzx eax,sceneKindL[esi]
    movzx ebx,sceneColL[esi]
    call PutScenery
    movzx eax,sceneKindR[esi]
    movzx ebx,sceneColR[esi]
    call PutScenery

    mov dl,ATTR_KERB_A                  ; 3) red and white kerbs, 2 rows per colour
    test rowWorld,2
    jz crKerb
    mov dl,ATTR_KERB_B
crKerb:
    mov ebx,roadLeft
    dec ebx
    mov newChr[edi+ebx],0DBh
    mov newAtr[edi+ebx],dl
    mov ebx,roadRight
    inc ebx
    mov newChr[edi+ebx],0DBh
    mov newAtr[edi+ebx],dl

    mov ebx,roadLeft                    ; 4) asphalt
crRoad:
    mov newChr[edi+ebx],' '
    mov newAtr[edi+ebx],ATTR_ROAD
    inc ebx
    cmp ebx,roadRight
    jbe crRoad

    mov eax,rowWorld                    ; 5) dashed lane marks: 2 rows on, 2 rows off
    and eax,3
    cmp eax,2
    jae crLines
    mov ebx,roadLeft
    add ebx,lvlMargin
    mov ecx,4                           ; four marks separate the five lanes
crDash:
    add ebx,lvlPitch
    mov newChr[edi+ebx],0B3h
    mov newAtr[edi+ebx],ATTR_DASH
    dec ecx
    jnz crDash

crLines:
    mov eax,rowWorld                    ; 6) starting line and checkered finish lines
    sub eax,LINE_ROW
    jb crDone                           ; this row is before the starting line
    mov edx,0
    mov ebx,LAP_LEN
    div ebx                             ; EAX = lap number, EDX = row inside the lap
    cmp edx,1
    ja crDone
    cmp eax,TOTAL_LAPS
    ja crDone
    cmp eax,0
    jne crChecker
    cmp edx,0                           ; lap 0: plain white starting line
    jne crDone
    mov ebx,roadLeft
crStart:
    mov newChr[edi+ebx],0CDh
    mov newAtr[edi+ebx],ATTR_DASH
    inc ebx
    cmp ebx,roadRight
    jbe crStart
    jmp crDone
crChecker:                              ; two rows of black and white squares
    mov ebx,roadLeft
crSquare:
    mov esi,ebx
    shr esi,1
    add esi,edx
    mov al,ATTR_CHECK_A
    test esi,1
    jz crSquarePut
    mov al,ATTR_CHECK_B
crSquarePut:
    mov newChr[edi+ebx],0DBh
    mov newAtr[edi+ebx],al
    inc ebx
    cmp ebx,roadRight
    jbe crSquare
crDone:
    popad
    ret
ComposeRow ENDP

; -------------------------------------------------------------------------------------
; PutScenery : stores one scenery piece (3 characters, spaces are transparent)
; Receives: EAX = piece (0 = nothing, 1..3), EBX = left column, EDI = row offset
; -------------------------------------------------------------------------------------
PutScenery PROC
    pushad
    cmp eax,0
    je psDone
    dec eax
    mov dl,sceneAttr[eax]
    lea esi,[eax+eax*2]                 ; 3 characters for every piece
    add esi,OFFSET sceneChars
    mov ecx,3
psNext:
    mov al,[esi]
    cmp al,' '
    je psSkip
    mov newChr[edi+ebx],al
    mov newAtr[edi+ebx],dl
psSkip:
    inc esi
    inc ebx
    dec ecx
    jnz psNext
psDone:
    popad
    ret
PutScenery ENDP

; -------------------------------------------------------------------------------------
; ComposeItems : stores every item that is still on the road
; -------------------------------------------------------------------------------------
ComposeItems PROC
    pushad
    mov eax,carLaps                     ; the items belong to the lap of the player
    imul eax,LAP_LEN
    add eax,LINE_ROW
    mov lapBase,eax
    mov esi,0
ciNext:
    cmp esi,itemCount
    jae ciDone
    cmp itemActive[esi],0
    je ciSkip
    mov eax,lapBase
    add eax,itemRow[esi*4]              ; EAX = track row of the item
    mov ecx,topWorld
    sub ecx,eax                         ; ECX = view row (PutCell clips it)
    movzx edx,itemKind[esi]
    mov ebx,itemX[esi*4]
    call PutItem
ciSkip:
    inc esi
    jmp ciNext
ciDone:
    popad
    ret
ComposeItems ENDP

; -------------------------------------------------------------------------------------
; PutItem : stores the characters of one item
; Receives: EDX = kind, EBX = left column, ECX = view row
; -------------------------------------------------------------------------------------
PutItem PROC
    pushad
    mov ah,kindAttr[edx]
    movzx edi,kindWidth[edx]
    lea esi,kindChars[edx*4]
piNext:
    mov al,[esi]
    call PutCell
    inc esi
    inc ebx
    dec edi
    jnz piNext
    popad
    ret
PutItem ENDP

; -------------------------------------------------------------------------------------
; ComposeCars : stores the opponents first and the player last (always on top)
; -------------------------------------------------------------------------------------
ComposeCars PROC
    pushad
    mov esi,NUM_CARS-1
ccNext:
    call PutCar
    dec esi
    jns ccNext
    popad
    ret
ComposeCars ENDP

; -------------------------------------------------------------------------------------
; PutCar : stores the 3 x 3 sprite of one car
; Receives: ESI = car number
; -------------------------------------------------------------------------------------
PutCar PROC
    pushad
    mov ah,carColor[esi]
    cmp esi,0
    jne pkColorDone
    cmp shieldOn,0                      ; the player car shows its state
    je pkNoShield
    mov ah,ATTR_SHIELDED
pkNoShield:
    cmp carSlow,0
    je pkColorDone
    test raceFrames,4                   ; flash while slowed down
    jz pkColorDone
    mov ah,ATTR_HURT
pkColorDone:
    mov ecx,topWorld
    sub ecx,carRow[esi*4]
    sub ecx,CAR_H-1                     ; ECX = view row of the front of the car
    mov edi,OFFSET carSprite
    mov edx,CAR_H
pkRow:
    mov ebx,carX[esi*4]
    push edx
    mov edx,CAR_W
pkCol:
    mov al,[edi]
    call PutCell
    inc edi
    inc ebx
    dec edx
    jnz pkCol
    pop edx
    inc ecx
    dec edx
    jnz pkRow
    cmp carBoost[esi*4],0               ; flame behind a boosted car
    je pkDone
    mov ebx,carX[esi*4]
    inc ebx
    mov al,0B1h
    mov ah,ATTR_FLAME
    call PutCell
pkDone:
    popad
    ret
PutCar ENDP

; -------------------------------------------------------------------------------------
; FlushFrame : compares the new frame with the frame on the screen and writes only the
;              cells that changed (no flicker, no full redraw)
; -------------------------------------------------------------------------------------
FlushFrame PROC
    pushad
    mov lastAttr,0FFFFFFFFh             ; colour of the console is not known yet
    mov edi,0                           ; EDI = cell number
    mov ecx,0                           ; ECX = view row
ffRow:
    mov ebx,0                           ; EBX = column
    mov needGoto,1
ffCol:
    mov al,newChr[edi]
    mov ah,newAtr[edi]
    cmp al,oldChr[edi]
    jne ffDraw
    cmp ah,oldAtr[edi]
    jne ffDraw
    mov needGoto,1                      ; cell skipped: the cursor is not here any more
    jmp ffNext
ffDraw:
    mov oldChr[edi],al
    mov oldAtr[edi],ah
    cmp needGoto,0
    je ffColor                          ; the cursor already stands on this cell
    mov dl,bl
    mov dh,cl
    add dh,VIEW_TOP
    call Gotoxy
    mov needGoto,0
ffColor:
    movzx edx,ah
    cmp edx,lastAttr
    je ffWrite                          ; same colour as the previous cell
    mov lastAttr,edx
    push eax
    mov eax,edx
    call SetTextColor
    pop eax
ffWrite:
    call WriteChar
ffNext:
    inc edi
    inc ebx
    cmp ebx,VIEW_W
    jb ffCol
    inc ecx
    cmp ecx,VIEW_ROWS
    jb ffRow
    mov dl,0                            ; park the cursor in the bottom left corner
    mov dh,29
    call Gotoxy
    popad
    ret
FlushFrame ENDP

; =====================================================================================
;  RACE SCREEN : static parts, HUD and side panel
; =====================================================================================

; -------------------------------------------------------------------------------------
; DrawRaceStatic : draws everything of the race screen that never changes
; -------------------------------------------------------------------------------------
DrawRaceStatic PROC
    pushad
    mov eax,ATTR_TEXT
    call SetTextColor
    call Clrscr
    mov eax,ATTR_HUD                    ; blue top bar
    call SetTextColor
    mov dl,0
    mov dh,0
    call Gotoxy
    mov al,' '
    mov ecx,120
    call RepeatChar
    mov eax,blue                        ; thin shadow under the bar
    call SetTextColor
    mov dl,0
    mov dh,1
    call Gotoxy
    mov al,0DFh
    mov ecx,120
    call RepeatChar
    mov eax,ATTR_PANEL                  ; frame of the side panel
    call SetTextColor
    mov dl,89
    mov dh,2
    mov bl,30
    mov bh,27
    call DrawBox
    mov esi,OFFSET hudTable
    call PrintTable
    mov esi,OFFSET panelTable
    call PrintTable
    mov eax,ATTR_HUD_VALUE              ; values that stay the same during the race
    call SetTextColor
    mov bl,9
    mov bh,0
    mov edx,OFFSET playerName
    call PrintAt
    mov bl,34
    mov bh,0
    mov eax,level
    call PrintNumAt
    mov bl,90
    mov bh,0
    mov eax,highScore
    call PrintNumAt
    popad
    ret
DrawRaceStatic ENDP

; -------------------------------------------------------------------------------------
; ComputeRanking : sorts the cars by the distance they have driven (bubble sort) and
;                  finds the live position of the player
; -------------------------------------------------------------------------------------
ComputeRanking PROC
    pushad
    mov ecx,NUM_CARS-1                  ; number of passes
rkPass:
    mov esi,0
rkCompare:
    movzx eax,rankOrder[esi]
    movzx ebx,rankOrder[esi+1]
    mov edx,carPos[eax*4]
    cmp edx,carPos[ebx*4]
    jae rkNoSwap
    mov rankOrder[esi],bl
    mov rankOrder[esi+1],al
rkNoSwap:
    inc esi
    cmp esi,NUM_CARS-1
    jb rkCompare
    dec ecx
    jnz rkPass
    mov esi,0                           ; where is car 0 (the player) in the list?
rkFind:
    cmp rankOrder[esi],0
    je rkFound
    inc esi
    cmp esi,NUM_CARS-1
    jb rkFind
rkFound:
    inc esi
    mov playerPos,esi
    popad
    ret
ComputeRanking ENDP

; -------------------------------------------------------------------------------------
; UpdateHud : refreshes the top bar and the side panel
; -------------------------------------------------------------------------------------
UpdateHud PROC
    pushad
    call ComputeRanking

    ; ---------------- top bar: lap, score, time, position ----------------
    mov eax,ATTR_HUD_VALUE
    call SetTextColor
    mov eax,carLaps                     ; lap that is being driven (1..3)
    inc eax
    cmp eax,TOTAL_LAPS
    jbe uhLap
    mov eax,TOTAL_LAPS
uhLap:
    mov bl,43
    mov bh,0
    call PrintNumAt
    mov bl,59
    mov eax,score
    call PrintNumAt
    mov edx,OFFSET strPad3
    call WriteString
    mov dl,76
    mov dh,0
    call Gotoxy
    call WriteRaceTime
    mov bl,105
    mov eax,playerPos
    call PrintNumAt

    ; ---------------- panel: position ----------------
    mov eax,ATTR_VALUE
    call SetTextColor
    mov eax,playerPos
    dec eax
    lea edx,ordStrings[eax*4]
    mov bl,102
    mov bh,4
    call PrintAt

    ; ---------------- panel: gear gauge ----------------
    mov dl,102
    mov dh,5
    call Gotoxy
    mov ecx,1
uhGear:
    mov eax,lightGreen
    cmp ecx,gear
    jbe uhGearColor
    mov eax,gray
uhGearColor:
    call SetTextColor
    mov al,0FEh
    call WriteChar
    mov al,' '
    call WriteChar
    inc ecx
    cmp ecx,MAX_GEAR
    jbe uhGear

    ; ---------------- panel: status of the player car ----------------
    mov dl,102
    mov dh,6
    call Gotoxy
    cmp carSlow,0
    jne uhSlow
    cmp carBoost,0
    jne uhBoost
    cmp shieldOn,0
    jne uhShield
    mov eax,lightGreen
    mov edx,OFFSET strStNormal
    jmp uhStatus
uhSlow:
    mov eax,lightRed
    mov edx,OFFSET strStSlow
    jmp uhStatus
uhBoost:
    mov eax,lightCyan
    mov edx,OFFSET strStBoost
    jmp uhStatus
uhShield:
    mov eax,lightCyan
    mov edx,OFFSET strStShield
uhStatus:
    call SetTextColor
    mov ecx,14
    call WritePadded

    ; ---------------- panel: coins and crashes ----------------
    mov eax,ATTR_VALUE
    call SetTextColor
    mov bl,102
    mov bh,7
    mov eax,coinsCollected
    call PrintNumAt
    mov bh,8
    mov eax,carCollisions
    add eax,obstacleHits
    add eax,boundaryHits
    call PrintNumAt

    ; ---------------- panel: lap progress bar ----------------
    mov dl,91
    mov dh,11
    call Gotoxy
    mov eax,carRel
    cmp eax,LAP_LEN
    jb uhBar
    mov eax,0                           ; still before the starting line
uhBar:
    imul eax,PROGRESS_CELLS
    mov edx,0
    mov ebx,LAP_LEN
    div ebx
    mov ebx,eax                         ; EBX = filled cells
    mov eax,lightGreen
    call SetTextColor
    mov al,0DBh
    mov ecx,ebx
    call RepeatChar
    mov eax,gray
    call SetTextColor
    mov al,0B0h
    mov ecx,PROGRESS_CELLS
    sub ecx,ebx
    call RepeatChar

    ; ---------------- panel: standings of the five cars ----------------
    mov ecx,0
uhStanding:
    mov dl,91
    mov dh,14
    add dh,cl
    call Gotoxy
    mov eax,ATTR_TEXT
    call SetTextColor
    mov al,'1'
    add al,cl
    call WriteChar
    mov al,'.'
    call WriteChar
    mov al,' '
    call WriteChar
    movzx ebx,rankOrder[ecx]
    movzx eax,carColor[ebx]
    and eax,0Fh                         ; colour of the car on the black panel
    call SetTextColor
    mov al,0DBh
    call WriteChar
    call WriteChar
    mov al,' '
    call WriteChar
    mov eax,ATTR_TEXT
    cmp ebx,0
    jne uhStandingName
    mov eax,ATTR_BRIGHT                 ; the player is highlighted
uhStandingName:
    call SetTextColor
    mov edx,carNamePtr[ebx*4]
    push ecx
    mov ecx,16
    call WritePadded
    pop ecx
    inc ecx
    cmp ecx,NUM_CARS
    jb uhStanding

    ; ---------------- panel: last event ----------------
    mov dl,91
    mov dh,26
    call Gotoxy
    mov eax,ATTR_TEXT
    mov edx,OFFSET strEmpty
    cmp msgTimer,0
    je uhMessage
    mov eax,msgAttr
    mov edx,msgPtr
uhMessage:
    call SetTextColor
    mov ecx,26
    call WritePadded

    mov dl,0                            ; park the cursor
    mov dh,29
    call Gotoxy
    popad
    ret
UpdateHud ENDP

; -------------------------------------------------------------------------------------
; SetMsg : chooses the event message shown in the side panel
; Receives: EDX = offset of the message, AL = colour
; -------------------------------------------------------------------------------------
SetMsg PROC
    push eax
    movzx eax,al
    mov msgAttr,eax
    mov msgPtr,edx
    mov msgTimer,MSG_FRAMES
    pop eax
    ret
SetMsg ENDP

; =====================================================================================
;  RACE LOGIC
; =====================================================================================

; -------------------------------------------------------------------------------------
; RunRace : plays one level. quitFlag is 1 when the player left the race, otherwise the
;           race was finished and the statistics are ready for the Result screen.
; -------------------------------------------------------------------------------------
RunRace PROC
    pushad
    call SetupLevel
    call InitRace
    call DrawRaceStatic
    call ComposeFrame
    call FlushFrame
    call UpdateHud
    call Countdown
    mov edx,OFFSET msgGo
    mov al,lightGreen
    call SetMsg

rrFrame:
    mov eax,FRAME_MS
    call Delay
    call HandleInput                    ; ReadKey: the race goes on without a key press
    cmp quitFlag,0
    jne rrEnd
    call UpdatePlayer
    call UpdateOpponents
    call CheckItems
    call CheckLaps
    call UpdateTimers
    call ComposeFrame
    call FlushFrame
    inc hudTick
    cmp hudTick,HUD_EVERY
    jb rrSkipHud
    mov hudTick,0
    call UpdateHud
rrSkipHud:
    cmp raceOver,0
    je rrFrame

    call FinishRace
rrEnd:
    popad
    ret
RunRace ENDP

; -------------------------------------------------------------------------------------
; Countdown : shows 3, 2, 1 and GO before the race starts
; -------------------------------------------------------------------------------------
Countdown PROC
    pushad
    mov countStep,0
cdNext:
    mov ebx,countStep
    movzx eax,countAttr[ebx]
    call SetTextColor
    mov dl,30
    mov dh,9
    mov bl,28
    mov bh,11
    call DrawBox
    mov bl,39
    mov bh,10
    mov edx,OFFSET strGetReady
    call PrintAt
    mov eax,6                           ; glyph 6 = "3", 7 = "2", 8 = "1"
    add eax,countStep
    mov dl,39
    mov dh,12
    call DrawBigGlyph
    call PlayBeep
    mov dl,0
    mov dh,29
    call Gotoxy
    mov eax,1000                        ; one second for every number
    call Delay
    inc countStep
    cmp countStep,3
    jb cdNext

    mov eax,1Fh                         ; GO
    call SetTextColor
    mov dl,30
    mov dh,9
    mov bl,28
    mov bh,11
    call DrawBox
    mov eax,5                           ; G
    mov dl,33
    mov dh,12
    call DrawBigGlyph
    mov eax,9                           ; O
    mov dl,45
    call DrawBigGlyph
    call PlayBeep
    mov dl,0
    mov dh,29
    call Gotoxy
    mov eax,500
    call Delay
    call InvalidateFrame                ; the box is wiped by the next frame
    call DrainKeys
    popad
    ret
Countdown ENDP

; -------------------------------------------------------------------------------------
; HandleInput : reads every waiting key without stopping the race (ReadKey)
;               A/D or arrows steer, W/S or arrows change gear, P pauses, X quits
; -------------------------------------------------------------------------------------
HandleInput PROC
    pushad
    mov inputCount,8                    ; at most 8 keys in one frame
hiNext:
    call ReadKey
    jz hiDone                           ; no key is waiting
    cmp al,0
    jne hiLetter
    cmp ah,4Bh                          ; extended keys: scan code of the arrows
    je hiLeft
    cmp ah,4Dh
    je hiRight
    cmp ah,48h
    je hiGearUp
    cmp ah,50h
    je hiGearDown
    jmp hiAgain
hiLetter:
    or al,20h                           ; accept capital letters too
    cmp al,'a'
    je hiLeft
    cmp al,'d'
    je hiRight
    cmp al,'w'
    je hiGearUp
    cmp al,'s'
    je hiGearDown
    cmp al,'p'
    je hiPause
    cmp al,'x'
    je hiQuit
    jmp hiAgain
hiLeft:
    mov eax,-STEER_STEP
    call SteerPlayer
    jmp hiAgain
hiRight:
    mov eax,STEER_STEP
    call SteerPlayer
    jmp hiAgain
hiGearUp:
    cmp gear,MAX_GEAR
    jae hiAgain
    inc gear
    jmp hiGearSet
hiGearDown:
    cmp gear,1
    jbe hiAgain
    dec gear
hiGearSet:
    mov eax,gear
    mov eax,gearSpeed[eax*4-4]
    mov carBase,eax
    jmp hiAgain
hiPause:
    call PauseScreen
    jmp hiDone
hiQuit:
    mov quitFlag,1
    jmp hiDone
hiAgain:
    dec inputCount
    jnz hiNext
hiDone:
    popad
    ret
HandleInput ENDP

; -------------------------------------------------------------------------------------
; PauseScreen : freezes the race and shows the pause box until the player resumes or
;               quits. Nothing moves while this procedure waits for a key.
; -------------------------------------------------------------------------------------
PauseScreen PROC
    pushad
    mov eax,ATTR_HUD
    call SetTextColor
    mov dl,24
    mov dh,10
    mov bl,40
    mov bh,9
    call DrawBox
    mov eax,ATTR_HUD_VALUE
    call SetTextColor
    mov bl,38
    mov bh,12
    mov edx,OFFSET strPaused
    call PrintAt
    mov eax,ATTR_HUD
    call SetTextColor
    mov bl,27
    mov bh,14
    mov edx,OFFSET strPause1
    call PrintAt
    mov bh,15
    mov edx,OFFSET strPause2
    call PrintAt
    mov dl,0
    mov dh,29
    call Gotoxy
psKey:
    call ReadChar
    cmp al,0
    je psKey
    or al,20h
    cmp al,'p'
    je psResume
    cmp al,'1'
    je psResume
    cmp al,'2'
    je psQuit
    cmp al,'q'
    je psQuit
    jmp psKey
psQuit:
    mov quitFlag,1
    jmp psEnd
psResume:
    call InvalidateFrame                ; the track is redrawn without the pause box
psEnd:
    popad
    ret
PauseScreen ENDP

; -------------------------------------------------------------------------------------
; GetSpeed : speed of a car in this frame
;            boosted = faster, slowed = half speed, both at once = normal speed
; Receives: ESI = car number      Returns: EAX = speed in 1/32 rows per frame
; -------------------------------------------------------------------------------------
GetSpeed PROC
    mov eax,carBase[esi*4]
    cmp carBoost[esi*4],0
    je gpNoBoost
    cmp carSlow[esi*4],0
    jne gpDone
    add eax,BOOST_ADD
    jmp gpDone
gpNoBoost:
    cmp carSlow[esi*4],0
    je gpDone
    shr eax,1
gpDone:
    ret
GetSpeed ENDP

; -------------------------------------------------------------------------------------
; CarBlocked : tests if a car would overlap another car at a new place
; Receives: ESI = car that wants to move, testX / testRow = the new place
; Returns : EAX = 1 when another car is in the way, otherwise 0
; -------------------------------------------------------------------------------------
CarBlocked PROC
    push edi
    mov edi,0
cbNext:
    cmp edi,esi
    je cbSkip                           ; a car never blocks itself
    mov eax,carX[edi*4]
    sub eax,testX
    jns cbColumns
    neg eax
cbColumns:
    cmp eax,CAR_W
    jge cbSkip                          ; side by side
    mov eax,carRow[edi*4]
    sub eax,testRow
    jns cbRows
    neg eax
cbRows:
    cmp eax,CAR_H
    jge cbSkip                          ; in front or behind with a gap
    mov eax,1
    jmp cbDone
cbSkip:
    inc edi
    cmp edi,NUM_CARS
    jb cbNext
    mov eax,0
cbDone:
    pop edi
    ret
CarBlocked ENDP

; -------------------------------------------------------------------------------------
; SteerPlayer : moves the player car sideways
; Receives: EAX = number of columns (negative = left)
; -------------------------------------------------------------------------------------
SteerPlayer PROC
    pushad
    mov ebx,carX
    add ebx,eax                         ; EBX = wanted column
    cmp ebx,roadLeft
    jge spRightEdge
    mov ebx,roadLeft                    ; stop at the left kerb
    cmp carX,ebx
    je spBoundary                       ; already there: the kerb is touched
    jmp spTry
spRightEdge:
    mov edx,roadRight
    sub edx,CAR_W-1
    cmp ebx,edx
    jle spTry
    mov ebx,edx                         ; stop at the right kerb
    cmp carX,ebx
    je spBoundary
spTry:
    mov testX,ebx
    mov eax,carRow
    mov testRow,eax
    mov esi,0
    call CarBlocked
    cmp eax,0
    jne spCar
    mov carX,ebx
    mov carTargetX,ebx
    jmp spDone
spBoundary:
    call HitBoundary
    jmp spDone
spCar:
    call HitCar                         ; steering into a rival
spDone:
    popad
    ret
SteerPlayer ENDP

; -------------------------------------------------------------------------------------
; UpdatePlayer : moves the player car forward
; -------------------------------------------------------------------------------------
UpdatePlayer PROC
    pushad
    mov esi,0
    call GetSpeed
    mov ebx,carPos
    add ebx,eax                         ; EBX = new position
    mov edx,ebx
    shr edx,POS_SHIFT                   ; EDX = new track row
    cmp edx,carRow
    je upStore                          ; still on the same row
    mov eax,carX
    mov testX,eax
    mov testRow,edx
    call CarBlocked
    cmp eax,0
    je upStore
    call HitCar                         ; ran into the car in front: no move
    jmp upDone
upStore:
    mov carPos,ebx
    mov carRow,edx
upDone:
    popad
    ret
UpdatePlayer ENDP

; -------------------------------------------------------------------------------------
; UpdateOpponents : moves the four computer cars
; -------------------------------------------------------------------------------------
UpdateOpponents PROC
    pushad
    mov esi,1
uoNext:
    mov wantChange,0
    call GetSpeed
    mov ebx,carPos[esi*4]
    add ebx,eax
    mov edx,ebx
    shr edx,POS_SHIFT
    cmp edx,carRow[esi*4]
    je uoStore
    mov eax,carX[esi*4]
    mov testX,eax
    mov testRow,edx
    call CarBlocked
    cmp eax,0
    je uoStore
    mov wantChange,1                    ; stuck behind another car
    jmp uoLane
uoStore:
    mov carPos[esi*4],ebx
    mov carRow[esi*4],edx
uoLane:
    cmp lvlLaneChange,0                 ; level 1: opponents keep their lane
    je uoSkip
    call OpponentLane
uoSkip:
    inc esi
    cmp esi,NUM_CARS
    jb uoNext
    popad
    ret
UpdateOpponents ENDP

; -------------------------------------------------------------------------------------
; OpponentLane : lane changes of one opponent (level 2)
;   - a car that is between two lanes slides one column per frame
;   - otherwise it sometimes decides to change to a neighbour lane
;   - it never leaves the track and never drives through another car
; Receives: ESI = car number; wantChange = 1 when the car is stuck behind another car
; -------------------------------------------------------------------------------------
OpponentLane PROC
    pushad
    mov eax,carTargetX[esi*4]
    cmp eax,carX[esi*4]
    je olDecide
    mov ebx,carX[esi*4]                 ; sliding towards the new lane
    jg olSlideRight
    dec ebx
    jmp olSlide
olSlideRight:
    inc ebx
olSlide:
    mov testX,ebx
    mov eax,carRow[esi*4]
    mov testRow,eax
    call CarBlocked
    cmp eax,0
    jne olReturn
    mov carX[esi*4],ebx
    jmp olDone
olReturn:                               ; a car is in the way: go back to the old lane
    mov eax,carPrevLane[esi*4]
    mov ebx,carLane[esi*4]
    mov carLane[esi*4],eax
    mov carPrevLane[esi*4],ebx
    call GetLaneX
    mov carTargetX[esi*4],eax
    jmp olDone

olDecide:
    cmp wantChange,0
    jne olPick                          ; stuck: try to overtake
    mov eax,LANE_CHANGE_ODDS
    call RandomRange
    cmp eax,0
    jne olDone
olPick:
    mov eax,2
    call RandomRange                    ; 0 = left, 1 = right
    mov ebx,carLane[esi*4]
    cmp eax,0
    je olLeft
    inc ebx
    jmp olCheck
olLeft:
    dec ebx
olCheck:
    cmp ebx,0
    jl olBoundary
    cmp ebx,4
    jg olBoundary
    mov eax,ebx
    call GetLaneX
    mov edx,eax                         ; EDX = column of the new lane
    call LaneIsClear
    cmp eax,0
    je olDone
    mov eax,carLane[esi*4]
    mov carPrevLane[esi*4],eax
    mov carLane[esi*4],ebx
    mov carTargetX[esi*4],edx
    jmp olDone
olBoundary:                             ; the car stays inside the track, but now and
    cmp wantChange,0                    ; then it brushes the boundary and is slowed
    jne olDone
    mov eax,3
    call RandomRange
    cmp eax,0
    jne olDone
    mov carSlow[esi*4],SLOW_FRAMES
olDone:
    popad
    ret
OpponentLane ENDP

; -------------------------------------------------------------------------------------
; LaneIsClear : tests if a lane is free next to a car
; Receives: ESI = car that wants to change, EDX = column of the wanted lane
; Returns : EAX = 1 when no other car is in that lane (or moving into it) close by
; -------------------------------------------------------------------------------------
LaneIsClear PROC
    push edi
    mov edi,0
lcNext:
    cmp edi,esi
    je lcSkip
    mov eax,carRow[edi*4]
    sub eax,carRow[esi*4]
    jns lcRows
    neg eax
lcRows:
    cmp eax,LANE_CLEAR_ROWS
    jge lcSkip                          ; far enough in front or behind
    mov eax,carX[edi*4]
    sub eax,edx
    jns lcColumns
    neg eax
lcColumns:
    cmp eax,lvlPitch
    jl lcBusy                           ; a car is in the wanted lane
    mov eax,carTargetX[edi*4]
    sub eax,edx
    jns lcTarget
    neg eax
lcTarget:
    cmp eax,lvlPitch
    jl lcBusy                           ; a car is moving into the wanted lane
lcSkip:
    inc edi
    cmp edi,NUM_CARS
    jb lcNext
    mov eax,1
    jmp lcDone
lcBusy:
    mov eax,0
lcDone:
    pop edi
    ret
LaneIsClear ENDP

; -------------------------------------------------------------------------------------
; ComputeCarRel : row of every car inside its current lap (used for the items)
; -------------------------------------------------------------------------------------
ComputeCarRel PROC
    pushad
    mov esi,0
ccrNext:
    mov eax,carRow[esi*4]
    sub eax,LINE_ROW
    jae ccrDivide
    mov edx,100000                      ; before the starting line: matches no item
    jmp ccrStore
ccrDivide:
    mov edx,0
    mov ebx,LAP_LEN
    div ebx                             ; EDX = row inside the lap
ccrStore:
    mov carRel[esi*4],edx
    inc esi
    cmp esi,NUM_CARS
    jb ccrNext
    popad
    ret
ComputeCarRel ENDP

; -------------------------------------------------------------------------------------
; CheckItems : collision detection between the cars and the items on the road.
;              The player is tested first, so the player wins a tie for a booster.
; -------------------------------------------------------------------------------------
CheckItems PROC
    pushad
    call ComputeCarRel
    mov edi,0                           ; EDI = item number
ckItem:
    cmp edi,itemCount
    jae ckDone
    cmp itemActive[edi],0
    je ckNextItem
    mov esi,0                           ; ESI = car number
ckCar:
    cmp carDone[esi*4],0
    jne ckNextCar                       ; finished cars leave the items alone
    mov eax,itemRow[edi*4]
    sub eax,carRel[esi*4]
    cmp eax,CAR_H
    jae ckNextCar                       ; the item is not on one of the car's rows
    mov eax,carX[esi*4]
    add eax,CAR_W
    cmp itemX[edi*4],eax
    jge ckNextCar                       ; the item is right of the car
    movzx ebx,itemKind[edi]
    movzx eax,kindWidth[ebx]
    add eax,itemX[edi*4]
    cmp carX[esi*4],eax
    jge ckNextCar                       ; the item is left of the car
    call CollectItem
    cmp itemActive[edi],0
    je ckNextItem                       ; the item is gone
ckNextCar:
    inc esi
    cmp esi,NUM_CARS
    jb ckCar
ckNextItem:
    inc edi
    jmp ckItem
ckDone:
    popad
    ret
CheckItems ENDP

; -------------------------------------------------------------------------------------
; CollectItem : what happens when a car drives over an item
; Receives: EDI = item number, ESI = car number, EBX = kind of the item
; -------------------------------------------------------------------------------------
CollectItem PROC
    pushad
    cmp ebx,K_COIN
    je coCoin
    cmp ebx,K_OBST
    je coObstacle
    cmp ebx,K_BOOST
    je coBooster

    cmp esi,0                           ; shield: only the player can use it
    jne coDone
    mov itemActive[edi],0
    mov shieldOn,1
    mov edx,OFFSET msgShieldOn
    mov al,lightCyan
    call SetMsg
    call PlayBeep
    jmp coDone

coCoin:                                 ; coins are for the player only
    cmp esi,0
    jne coDone
    mov itemActive[edi],0
    add score,COIN_POINTS
    inc coinsCollected
    mov edx,OFFSET msgCoin
    mov al,yellow
    call SetMsg
    call PlayBeep
    jmp coDone

coObstacle:                             ; every car is slowed down by a barrier
    mov itemActive[edi],0
    cmp esi,0
    je coObstaclePlayer
    mov carSlow[esi*4],SLOW_FRAMES
    jmp coDone
coObstaclePlayer:
    call HitObstacle
    jmp coDone

coBooster:                              ; the first car to reach a booster gets it
    mov itemActive[edi],0
    mov carBoost[esi*4],BOOST_FRAMES
    cmp esi,0
    jne coRivalBoost
    inc boostersTaken
    mov edx,OFFSET msgBoost
    mov al,lightCyan
    call SetMsg
    call PlayBeep
    jmp coDone
coRivalBoost:
    mov edx,OFFSET msgRivalBoost
    mov al,lightMagenta
    call SetMsg
coDone:
    popad
    ret
CollectItem ENDP

; -------------------------------------------------------------------------------------
; AddPenalty : takes points away from the score; the score never goes below zero
; Receives: EAX = points
; -------------------------------------------------------------------------------------
AddPenalty PROC
    add totalPenalty,eax
    cmp score,eax
    jae apSubtract
    mov score,0
    ret
apSubtract:
    sub score,eax
    ret
AddPenalty ENDP

; -------------------------------------------------------------------------------------
; HitCar : the player touched an opponent car (-15 and 2 seconds of reduced speed)
; -------------------------------------------------------------------------------------
HitCar PROC
    pushad
    cmp hitCooldown,0
    jne hcDone                          ; this crash was already counted
    mov hitCooldown,HIT_COOLDOWN
    cmp shieldOn,0
    je hcCrash
    mov shieldOn,0                      ; the shield takes the hit
    mov edx,OFFSET msgShieldUsed
    mov al,lightCyan
    call SetMsg
    jmp hcDone
hcCrash:
    inc carCollisions
    mov eax,CAR_PENALTY
    call AddPenalty
    mov carSlow,SLOW_FRAMES
    mov edx,OFFSET msgCarHit
    mov al,lightRed
    call SetMsg
    call PlayBeep
hcDone:
    popad
    ret
HitCar ENDP

; -------------------------------------------------------------------------------------
; HitObstacle : the player drove into a barrier (-10 and 2 seconds of reduced speed)
; -------------------------------------------------------------------------------------
HitObstacle PROC
    pushad
    cmp shieldOn,0
    je hoCrash
    mov shieldOn,0                      ; the shield takes the hit
    mov edx,OFFSET msgShieldUsed
    mov al,lightCyan
    call SetMsg
    jmp hoDone
hoCrash:
    inc obstacleHits
    mov eax,OBST_PENALTY
    call AddPenalty
    mov carSlow,SLOW_FRAMES
    mov edx,OFFSET msgObstHit
    mov al,lightRed
    call SetMsg
    call PlayBeep
hoDone:
    popad
    ret
HitObstacle ENDP

; -------------------------------------------------------------------------------------
; HitBoundary : the player touched the left or right boundary (-5 and reduced speed)
; -------------------------------------------------------------------------------------
HitBoundary PROC
    pushad
    cmp edgeCooldown,0
    jne hbDone                          ; holding the key is one touch, not many
    mov edgeCooldown,EDGE_COOLDOWN
    inc boundaryHits
    mov eax,EDGE_PENALTY
    call AddPenalty
    mov carSlow,SLOW_FRAMES
    mov edx,OFFSET msgEdgeHit
    mov al,lightRed
    call SetMsg
    call PlayBeep
hbDone:
    popad
    ret
HitBoundary ENDP

; -------------------------------------------------------------------------------------
; CheckLaps : counts the laps of every car, gives the lap bonus, places new items for
;             the next lap of the player and records the order in which cars finish
; -------------------------------------------------------------------------------------
CheckLaps PROC
    pushad
    mov esi,0
clNext:
    mov eax,carRow[esi*4]
    sub eax,LINE_ROW
    jb clSkip                           ; not over the starting line yet
    mov edx,0
    mov ebx,LAP_LEN
    div ebx                             ; EAX = laps completed
    cmp eax,carLaps[esi*4]
    jbe clSkip
    mov carLaps[esi*4],eax              ; the car has just crossed the line
    cmp esi,0
    jne clFinish
    add score,LAP_POINTS
    mov edx,OFFSET msgLap
    mov al,lightGreen
    call SetMsg
    call PlayBeep
    cmp carLaps,TOTAL_LAPS
    jae clFinish
    call GenerateItems                  ; new random items for the next lap
clFinish:
    cmp carLaps[esi*4],TOTAL_LAPS
    jb clSkip
    cmp carDone[esi*4],0
    jne clSkip
    mov carDone[esi*4],1                ; remember the finishing order
    mov edx,finishCount
    mov ebx,esi
    mov finishOrder[edx],bl
    inc finishCount
    cmp esi,0
    jne clSkip
    mov raceOver,1                      ; the player has finished the race
clSkip:
    inc esi
    cmp esi,NUM_CARS
    jb clNext
    popad
    ret
CheckLaps ENDP

; -------------------------------------------------------------------------------------
; UpdateTimers : counts down the slow / boost times of all cars and the other timers
; -------------------------------------------------------------------------------------
UpdateTimers PROC
    pushad
    mov esi,0
utNext:
    cmp carSlow[esi*4],0
    je utBoost
    dec carSlow[esi*4]
utBoost:
    cmp carBoost[esi*4],0
    je utCar
    dec carBoost[esi*4]
utCar:
    inc esi
    cmp esi,NUM_CARS
    jb utNext
    cmp hitCooldown,0
    je utEdge
    dec hitCooldown
utEdge:
    cmp edgeCooldown,0
    je utMessage
    dec edgeCooldown
utMessage:
    cmp msgTimer,0
    je utFrames
    dec msgTimer
utFrames:
    inc raceFrames
    popad
    ret
UpdateTimers ENDP

; -------------------------------------------------------------------------------------
; FinishRace : final ranking, position bonus, high score file and the finish animation
; -------------------------------------------------------------------------------------
FinishRace PROC
    pushad
    call BuildFinalOrder
    mov eax,playerPlace                 ; bonus for the finishing position
    dec eax
    mov eax,placeBonus[eax*4]
    mov placeBonusWon,eax
    add score,eax
    mov eax,score
    cmp eax,highScore
    jbe frAnimate
    mov highScore,eax                   ; new highest score: update the file
    mov esi,OFFSET playerName
    mov edi,OFFSET highName
    mov ecx,NAME_SIZE
    call CopyString
    mov newHighFlag,1
    call SaveHighScore
frAnimate:
    call UpdateHud
    call AnimateFinish
    popad
    ret
FinishRace ENDP

; -------------------------------------------------------------------------------------
; BuildFinalOrder : completes finishOrder. Cars that crossed the line are already in the
;                   list; the others follow in the order of the distance they drove.
; -------------------------------------------------------------------------------------
BuildFinalOrder PROC
    pushad
    call ComputeRanking
    mov ecx,0
boNext:
    movzx eax,rankOrder[ecx]
    cmp carDone[eax*4],0
    jne boSkip                          ; already in the list
    mov edx,finishCount
    mov finishOrder[edx],al
    inc finishCount
boSkip:
    inc ecx
    cmp ecx,NUM_CARS
    jb boNext
    mov ecx,0                           ; place of the player in the final order
boFind:
    cmp finishOrder[ecx],0
    je boFound
    inc ecx
    cmp ecx,NUM_CARS-1
    jb boFind
boFound:
    inc ecx
    mov playerPlace,ecx
    popad
    ret
BuildFinalOrder ENDP

; -------------------------------------------------------------------------------------
; AnimateFinish : flashing FINISH box with the position of the player
; -------------------------------------------------------------------------------------
AnimateFinish PROC
    pushad
    mov countStep,0
afNext:
    mov eax,4Fh                         ; the box flashes between red and blue
    test countStep,1
    jz afColor
    mov eax,1Eh
afColor:
    call SetTextColor
    mov dl,24
    mov dh,10
    mov bl,40
    mov bh,7
    call DrawBox
    mov bl,37
    mov bh,12
    mov edx,OFFSET strFinish
    call PrintAt
    mov bl,36
    mov bh,14
    mov edx,OFFSET strFinishPos
    call PrintAt
    mov eax,playerPlace
    dec eax
    lea edx,ordStrings[eax*4]
    call WriteString
    call PlayBeep
    mov dl,0
    mov dh,29
    call Gotoxy
    mov eax,300
    call Delay
    inc countStep
    cmp countStep,8
    jb afNext
    call DrainKeys
    popad
    ret
AnimateFinish ENDP

; =====================================================================================
;  RESULT SCREEN
; =====================================================================================

; -------------------------------------------------------------------------------------
; ResultScreen : shows the statistics of the level and the finishing order
; Returns: AL = '1' (next level, only after level 1), '2' (race again) or '3' (cancel)
; -------------------------------------------------------------------------------------
ResultScreen PROC
    call DrawResultScreen
rsKey:
    call ReadChar
    cmp al,'2'
    je rsDone
    cmp al,'3'
    je rsDone
    cmp al,'1'
    jne rsKey
    cmp level,1                         ; "Next Level" exists after level 1 only
    jne rsKey
rsDone:
    ret
ResultScreen ENDP

; -------------------------------------------------------------------------------------
; DrawResultScreen : draws the complete Result screen
; -------------------------------------------------------------------------------------
DrawResultScreen PROC
    pushad
    mov eax,ATTR_TEXT
    call SetTextColor
    call Clrscr

    mov eax,ATTR_HUD                    ; title bar
    call SetTextColor
    mov dl,0
    mov dh,1
    call Gotoxy
    mov al,' '
    mov ecx,120
    call RepeatChar
    mov bl,43
    mov bh,1
    mov edx,OFFSET strResTitle
    call PrintAt
    mov eax,level
    call WriteDec
    mov edx,OFFSET strResDone
    call WriteString

    mov eax,ATTR_PANEL                  ; the two boxes
    call SetTextColor
    mov dl,6
    mov dh,3
    mov bl,62
    mov bh,21
    call DrawBox
    mov dl,72
    mov bl,42
    call DrawBox
    mov esi,OFFSET resultTable
    call PrintTable

    ; ---------------- statistics of the player ----------------
    mov eax,ATTR_BRIGHT
    call SetTextColor
    mov bl,34
    mov bh,5
    mov edx,OFFSET playerName
    call PrintAt
    mov bh,6
    mov eax,level
    call PrintNumAt
    mov eax,playerPlace
    dec eax
    lea edx,ordStrings[eax*4]
    mov bh,7
    call PrintAt
    mov edx,OFFSET strOf5
    call WriteString
    mov dl,34
    mov dh,8
    call Gotoxy
    call WriteRaceTime
    mov bh,10
    mov eax,coinsCollected
    call PrintNumAt
    mov bh,11
    mov eax,boostersTaken
    call PrintNumAt
    mov bh,12
    mov eax,carCollisions
    call PrintNumAt
    mov bh,13
    mov eax,obstacleHits
    call PrintNumAt
    mov bh,14
    mov eax,boundaryHits
    call PrintNumAt

    mov eax,lightRed                    ; penalties in red with a minus sign
    call SetTextColor
    mov dl,34
    mov dh,15
    call Gotoxy
    mov al,'-'
    call WriteChar
    mov eax,totalPenalty
    call WriteDec
    mov eax,lightGreen                  ; bonus in green with a plus sign
    call SetTextColor
    mov dl,34
    mov dh,16
    call Gotoxy
    mov al,'+'
    call WriteChar
    mov eax,placeBonusWon
    call WriteDec

    mov eax,ATTR_VALUE
    call SetTextColor
    mov bl,34
    mov bh,18
    mov eax,score
    call PrintNumAt
    mov bh,20
    mov eax,highScore
    call PrintNumAt
    mov edx,OFFSET strResBy
    call WriteString
    mov edx,OFFSET highName
    call WriteString
    cmp newHighFlag,0
    je drOrder
    mov eax,lightGreen
    call SetTextColor
    mov bl,10
    mov bh,22
    mov edx,OFFSET strNewHigh
    call PrintAt

    ; ---------------- finishing order of the five cars ----------------
drOrder:
    mov ecx,0
drCar:
    mov dl,77
    mov dh,cl
    add dh,cl
    add dh,6                            ; rows 6, 8, 10, 12, 14
    call Gotoxy
    mov eax,ATTR_TEXT
    call SetTextColor
    lea edx,ordStrings[ecx*4]
    call WriteString
    mov al,' '
    call WriteChar
    call WriteChar
    movzx ebx,finishOrder[ecx]
    movzx eax,carColor[ebx]
    and eax,0Fh
    call SetTextColor
    mov al,0DBh
    call WriteChar
    call WriteChar
    mov al,' '
    call WriteChar
    call WriteChar
    mov eax,ATTR_TEXT
    cmp ebx,0
    jne drName
    mov eax,ATTR_VALUE                  ; the player is highlighted
drName:
    call SetTextColor
    mov edx,carNamePtr[ebx*4]
    call WriteString
    cmp ebx,0
    jne drNextCar
    mov edx,OFFSET strResYou
    call WriteString
drNextCar:
    inc ecx
    cmp ecx,NUM_CARS
    jb drCar

    ; ---------------- options ----------------
    cmp level,1
    jne drEnd
    mov eax,ATTR_BRIGHT
    call SetTextColor
    mov bl,20
    mov bh,25
    mov edx,OFFSET strResOpt1
    call PrintAt
drEnd:
    mov dl,0
    mov dh,29
    call Gotoxy
    call DrainKeys
    popad
    ret
DrawResultScreen ENDP

END main
