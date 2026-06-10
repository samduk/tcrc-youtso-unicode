; ============================================================
; TCRC Tibetan Unicode Keyboard for Windows
; Replicates the "Default TCRC-Tibetan Keyboard Layout"
; but outputs proper Unicode Tibetan (U+0F00-U+0FFF),
; so it works in Word, Photoshop, browsers - any modern app.
;
; Requires: AutoHotkey v2 (free, https://www.autohotkey.com)
; Usage:    double-click this file to run. Tibetan mode is ON.
;           Ctrl+Alt+T  = toggle Tibetan mode on/off
;
; Typing logic (same as TCRC):
;   space        = tsheg (a second space = real space)
;   'a' key      = "link" (halent): next consonant is subjoined
;                  e.g.  k a y  ->  kya stack
;   shad after nga inserts tsheg automatically (nga + / -> nga tsheg shad)
;   tsheg after ga is removed when space is pressed twice
; ============================================================

#Requires AutoHotkey v2.0
#SingleInstance Force
Persistent

global TibOn := true
global LinkPending := false
global PrevChar := ""
global LastChar := ""

global IconOn := A_ScriptDir "\tcrc_on.ico"
global IconOff := A_ScriptDir "\tcrc_off.ico"
if FileExist(IconOn)
    TraySetIcon(IconOn, , true)   ; true = freeze, so the icon never reverts
A_IconTip := "TCRC Tibetan Unicode (Ctrl+Alt+T)"

TrayTip "TCRC Tibetan Unicode keyboard", "Tibetan mode ON  (Ctrl+Alt+T to toggle)"

^!t:: {
    global TibOn, IconOn, IconOff
    TibOn := !TibOn
    if FileExist(TibOn ? IconOn : IconOff)
        TraySetIcon(TibOn ? IconOn : IconOff)
    TrayTip "TCRC Tibetan Unicode keyboard", "Tibetan mode " (TibOn ? "ON" : "OFF")
}

#HotIf TibOn

; ---------- helpers ----------
Out(s) {
    global PrevChar, LastChar, LinkPending
    SendText s
    PrevChar := LastChar
    LastChar := SubStr(s, -1)
    LinkPending := false
}
; consonant: sends subjoined form if "link" (a) was pressed first
Con(base, sub) {
    global LinkPending
    Out(LinkPending && sub != "" ? sub : base)
}

; ---------- the LINK / halent key ----------
$a:: {
    global LinkPending
    LinkPending := true
}

; ---------- space = tsheg ----------
$Space:: {
    global PrevChar, LastChar
    if (LastChar = Chr(0x0F0B)) {        ; second press -> real space
        if (PrevChar = Chr(0x0F42)) {    ; tsheg after GA is removed
            Send "{BS}"
            Out(" ")
        } else {
            Out(" ")
        }
    } else {
        Out(Chr(0x0F0B))                 ; tsheg
    }
}

; ---------- shad (with automatic tsheg after nga) ----------
$/:: {
    global LastChar
    if (LastChar = Chr(0x0F44))          ; nga
        Out(Chr(0x0F0B) Chr(0x0F0D))     ; tsheg + shad
    else
        Out(Chr(0x0F0D))                 ; shad
}

; ---------- consonants (base, subjoined-for-link) ----------
$q::  Con(Chr(0x0F4A), Chr(0x0F9A))   ; Ta  (retroflex)
$+q:: Con(Chr(0x0F4B), Chr(0x0F9B))   ; Tha (retroflex)
$w::  Con(Chr(0x0F5D), Chr(0x0FAD))   ; wa
$+w:: Out(Chr(0x0FAD))                ; Wasur (subjoined wa)
$r::  Con(Chr(0x0F62), Chr(0x0FB2))   ; ra
$+r:: Out(Chr(0x0F62))                ; Rago (head ra = plain ra in Unicode)
$t::  Con(Chr(0x0F4F), Chr(0x0F9F))   ; ta
$+t:: Con(Chr(0x0F50), Chr(0x0FA0))   ; tha
$y::  Con(Chr(0x0F61), Chr(0x0FB1))   ; ya
$+y:: Out("-")                        ; hyphen (per TCRC chart)
$p::  Con(Chr(0x0F54), Chr(0x0FA4))   ; pa
$+p:: Con(Chr(0x0F55), Chr(0x0FA5))   ; pha
$+a:: Con(Chr(0x0F68), Chr(0x0FB8))   ; a
$s::  Con(Chr(0x0F66), Chr(0x0FB6))   ; sa
$+s:: Con(Chr(0x0F64), Chr(0x0FB4))   ; sha
$d::  Con(Chr(0x0F51), Chr(0x0FA1))   ; da
$+d:: Con(Chr(0x0F5B), Chr(0x0FAB))   ; dza
$f::  Con(Chr(0x0F44), Chr(0x0F94))   ; nga
$+f:: Con(Chr(0x0F52), Chr(0x0FA2))   ; dha (da+ha)
$g::  Con(Chr(0x0F42), Chr(0x0F92))   ; ga
$+g:: Con(Chr(0x0F43), Chr(0x0F93))   ; gha
$h::  Con(Chr(0x0F67), Chr(0x0FB7))   ; ha
$+h:: Out(Chr(0x0FB7))                ; Link-ha (subjoined ha)
$j::  Con(Chr(0x0F47), Chr(0x0F97))   ; ja
$+j:: Con(Chr(0x0F5C), Chr(0x0FAC))   ; dzha
$k::  Con(Chr(0x0F40), Chr(0x0F90))   ; ka
$+k:: Con(Chr(0x0F41), Chr(0x0F91))   ; kha
$l::  Con(Chr(0x0F63), Chr(0x0FB3))   ; la
$+l:: Out(Chr(0x0F63))                ; Lago (head la = plain la)
$z::  Con(Chr(0x0F5F), Chr(0x0FAF))   ; za
$+z:: Con(Chr(0x0F5E), Chr(0x0FAE))   ; zha
$x::  Con(Chr(0x0F59), Chr(0x0FA9))   ; tsa
$+x:: Con(Chr(0x0F5A), Chr(0x0FAA))   ; tsha
$c::  Con(Chr(0x0F45), Chr(0x0F95))   ; ca
$+c:: Con(Chr(0x0F46), Chr(0x0F96))   ; cha
$v::  Con(Chr(0x0F4C), Chr(0x0F9C))   ; Da  (retroflex)
$+v:: Con(Chr(0x0F4E), Chr(0x0F9E))   ; Na  (retroflex)
$b::  Con(Chr(0x0F56), Chr(0x0FA6))   ; ba
$+b:: Con(Chr(0x0F57), Chr(0x0FA7))   ; bha
$n::  Con(Chr(0x0F53), Chr(0x0FA3))   ; na
$+n:: Con(Chr(0x0F49), Chr(0x0F99))   ; nya
$m::  Con(Chr(0x0F58), Chr(0x0FA8))   ; ma
$+m:: Con(Chr(0x0F65), Chr(0x0FB5))   ; Sa  (retroflex sha)
$':: Con(Chr(0x0F60), Chr(0x0FB0))    ; 'a-chung letter (b k ' = bka')
$+':: Out(Chr(0x0F71))                ; aa (a-chung vowel sign)

; ---------- vowels ----------
$e::  Out(Chr(0x0F7A))                ; e
$+e:: Out(Chr(0x0F7B))                ; ai (E)
$u::  Out(Chr(0x0F74))                ; u
$+u:: Out(Chr(0x0F75))                ; U (long u)
$i::  Out(Chr(0x0F72))                ; i
$+i:: Out(Chr(0x0F73))                ; I (long i)
$o::  Out(Chr(0x0F7C))                ; o
$+o:: Out(Chr(0x0F7D))                ; au (O)
$-::  Out(Chr(0x0F80))                ; reversed i  (ii)
$+-:: Out(Chr(0x0F81))                ; reversed long I (II)

; ---------- subjoined letters on dedicated keys ----------
$,::  Out(Chr(0x0FB1))                ; Yatag (subjoined ya)
$+,:: Out(Chr(0x0FB3))                ; latag (subjoined la)
$.::  Out(Chr(0x0FB2))                ; Ratag (subjoined ra)
$+.:: Out(Chr(0x0F62))                ; Rago (head ra)
$+/:: Out(Chr(0x0F66))                ; Sago (head sa)

; ---------- digits ----------
$1:: Out(Chr(0x0F21))
$2:: Out(Chr(0x0F22))
$3:: Out(Chr(0x0F23))
$4:: Out(Chr(0x0F24))
$5:: Out(Chr(0x0F25))
$6:: Out(Chr(0x0F26))
$7:: Out(Chr(0x0F27))
$8:: Out(Chr(0x0F28))
$9:: Out(Chr(0x0F29))
$0:: Out(Chr(0x0F20))

; ---------- numeric keypad (NumLock on) ----------
$Numpad1:: Out(Chr(0x0F21))
$Numpad2:: Out(Chr(0x0F22))
$Numpad3:: Out(Chr(0x0F23))
$Numpad4:: Out(Chr(0x0F24))
$Numpad5:: Out(Chr(0x0F25))
$Numpad6:: Out(Chr(0x0F26))
$Numpad7:: Out(Chr(0x0F27))
$Numpad8:: Out(Chr(0x0F28))
$Numpad9:: Out(Chr(0x0F29))
$Numpad0:: Out(Chr(0x0F20))
$NumpadDot:: Out(".")

; ---------- punctuation & marks ----------
$`::  Out(Chr(0x0F0C))                ; Tsheg-2 (non-breaking tsheg)
$+`:: Out(Chr(0x0F09))                ; Chengo (yig mgo sgab ma) [verify]
$+1:: Out(Chr(0x0F11))                ; Pung-shad (rin chen spungs shad)
$+2:: Out(Chr(0x0F04))                ; Yiggo
$+3:: Out(Chr(0x0F04) Chr(0x0F05))    ; Yigo full
$+4:: Out(Chr(0x0F39))                ; Tsalhag (tsa-'phru) [verify]
$+6:: Out(Chr(0x0FBE))                ; kur-tag (ku ru kha) [verify]
$+7:: Out(Chr(0x0F3A))                ; L-brace (ang khang gyon)
$+8:: Out(Chr(0x0F3B))                ; R-brace (ang khang gyas)
$=::  Out(Chr(0x0F83))                ; C-bindu (candrabindu)
$+=:: Out(Chr(0x0F7E))                ; anusvara
$\::  Out(Chr(0x0F7F))                ; Namshad (rnam bcad / visarga)
$+\:: Out(Chr(0x0F08))                ; drulshad (sbrul shad)
$;::  Out(Chr(0x0F4D))                ; Dha (retroflex) [verify]
$+;:: Out(Chr(0x0F14))                ; Namshad / gter tsheg [verify]
$[::  Out(Chr(0x2019))                ; R-quote
$+[:: Out(Chr(0x2018))                ; L-Quote
$]::  Out(",")                        ; comma

#HotIf

; ============================================================
; MODULE 2: Legacy TCRC -> Unicode document converter
;  - Word documents: detected automatically when opened;
;    you are asked, then the document is converted in place.
;  - Any other app (Photoshop, etc.): select the garbled
;    legacy text, press Ctrl+Alt+U, it is replaced by Unicode.
; ============================================================

global LegacyMap := Map()
LegacyMap[Chr(33)] := Chr(0x0F5C)
LegacyMap[Chr(34)] := Chr(0x0F5B) . Chr(0x0FB2)
LegacyMap[Chr(35)] := Chr(0x0F7E)
LegacyMap[Chr(36)] := Chr(0x0F62) . Chr(0x0FB1)
LegacyMap[Chr(37)] := Chr(0x0025)
LegacyMap[Chr(38)] := Chr(0x0F38)
LegacyMap[Chr(39)] := Chr(0x0FB7)
LegacyMap[Chr(40)] := Chr(0x0028)
LegacyMap[Chr(41)] := Chr(0x0029)
LegacyMap[Chr(42)] := Chr(0x0FBE)
LegacyMap[Chr(43)] := Chr(0x0F90)
LegacyMap[Chr(44)] := Chr(0x0F21)
LegacyMap[Chr(45)] := Chr(0x0F0B)
LegacyMap[Chr(46)] := Chr(0x0F0B)
LegacyMap[Chr(47)] := Chr(0x0F4B)
LegacyMap[Chr(48)] := Chr(0x0F20)
LegacyMap[Chr(49)] := Chr(0x0F21)
LegacyMap[Chr(50)] := Chr(0x0F22)
LegacyMap[Chr(51)] := Chr(0x0F23)
LegacyMap[Chr(52)] := Chr(0x0F24)
LegacyMap[Chr(53)] := Chr(0x0F25)
LegacyMap[Chr(54)] := Chr(0x0F26)
LegacyMap[Chr(55)] := Chr(0x0F27)
LegacyMap[Chr(56)] := Chr(0x0F28)
LegacyMap[Chr(57)] := Chr(0x0F29)
LegacyMap[Chr(58)] := Chr(0x0F08)
LegacyMap[Chr(59)] := Chr(0x0F40)
LegacyMap[Chr(60)] := Chr(0x0F83)
LegacyMap[Chr(61)] := Chr(0x0F40) . Chr(0x0FB2)
LegacyMap[Chr(62)] := Chr(0x0F40)
LegacyMap[Chr(63)] := Chr(0x0F90)
LegacyMap[Chr(64)] := Chr(0x0F62) . Chr(0x0F90)
LegacyMap[Chr(65)] := Chr(0x0F62) . Chr(0x0F90) . Chr(0x0FB1)
LegacyMap[Chr(66)] := Chr(0x0F66) . Chr(0x0F90) . Chr(0x0FB1)
LegacyMap[Chr(67)] := Chr(0x0F66) . Chr(0x0F90) . Chr(0x0FB2)
LegacyMap[Chr(68)] := Chr(0x0F41)
LegacyMap[Chr(69)] := Chr(0x0F41) . Chr(0x0FB1)
LegacyMap[Chr(70)] := Chr(0x0F41) . Chr(0x0FB2)
LegacyMap[Chr(71)] := Chr(0x0F42)
LegacyMap[Chr(72)] := Chr(0x0F42) . Chr(0x0FB1)
LegacyMap[Chr(73)] := Chr(0x0F42) . Chr(0x0FB2)
LegacyMap[Chr(74)] := Chr(0x0F42)
LegacyMap[Chr(75)] := Chr(0x0F92)
LegacyMap[Chr(76)] := Chr(0x0F62) . Chr(0x0F92)
LegacyMap[Chr(77)] := Chr(0x0F62) . Chr(0x0F92) . Chr(0x0FB1)
LegacyMap[Chr(78)] := Chr(0x0F66) . Chr(0x0F92) . Chr(0x0FB1)
LegacyMap[Chr(79)] := Chr(0x0F66) . Chr(0x0F92) . Chr(0x0FB2)
LegacyMap[Chr(80)] := Chr(0x0F44)
LegacyMap[Chr(81)] := Chr(0x0F62) . Chr(0x0F94)
LegacyMap[Chr(82)] := Chr(0x0F94)
LegacyMap[Chr(83)] := Chr(0x0F94)
LegacyMap[Chr(84)] := Chr(0x0F45)
LegacyMap[Chr(85)] := Chr(0x0F95)
LegacyMap[Chr(86)] := Chr(0x0F46)
LegacyMap[Chr(87)] := Chr(0x0F47)
LegacyMap[Chr(88)] := Chr(0x0F62) . Chr(0x0F97)
LegacyMap[Chr(89)] := Chr(0x0F97)
LegacyMap[Chr(90)] := Chr(0x0F49)
LegacyMap[Chr(91)] := Chr(0x0F3C)
LegacyMap[Chr(92)] := Chr(0x0F4C) . Chr(0x0FB2)
LegacyMap[Chr(93)] := Chr(0x0F3D)
LegacyMap[Chr(94)] := Chr(0x0F4C)
LegacyMap[Chr(95)] := Chr(0x0F9C)
LegacyMap[Chr(96)] := Chr(0x0F9C)
LegacyMap[Chr(97)] := Chr(0x0F4E)
LegacyMap[Chr(98)] := Chr(0x0F4F)
LegacyMap[Chr(99)] := Chr(0x0F4F) . Chr(0x0FB2)
LegacyMap[Chr(100)] := Chr(0x0F62) . Chr(0x0F9F)
LegacyMap[Chr(101)] := Chr(0x0F9F)
LegacyMap[Chr(102)] := Chr(0x0F50)
LegacyMap[Chr(103)] := Chr(0x0F50) . Chr(0x0FB2)
LegacyMap[Chr(104)] := Chr(0x0F51)
LegacyMap[Chr(105)] := Chr(0x0F51) . Chr(0x0FB2)
LegacyMap[Chr(106)] := Chr(0x0F51)
LegacyMap[Chr(107)] := Chr(0x0FA1)
LegacyMap[Chr(108)] := Chr(0x0F62) . Chr(0x0FA1)
LegacyMap[Chr(109)] := Chr(0x0F53)
LegacyMap[Chr(110)] := Chr(0x0F62) . Chr(0x0FA3)
LegacyMap[Chr(111)] := Chr(0x0FA3)
LegacyMap[Chr(112)] := Chr(0x0F66) . Chr(0x0FA3) . Chr(0x0FB2)
LegacyMap[Chr(113)] := Chr(0x0F54)
LegacyMap[Chr(114)] := Chr(0x0F54) . Chr(0x0FB1)
LegacyMap[Chr(115)] := Chr(0x0F54) . Chr(0x0FB2)
LegacyMap[Chr(116)] := Chr(0x0FA4)
LegacyMap[Chr(117)] := Chr(0x0F66) . Chr(0x0FA4) . Chr(0x0FB1)
LegacyMap[Chr(118)] := Chr(0x0F66) . Chr(0x0FA4) . Chr(0x0FB2)
LegacyMap[Chr(119)] := Chr(0x0F55)
LegacyMap[Chr(120)] := Chr(0x0F55) . Chr(0x0FB1)
LegacyMap[Chr(121)] := Chr(0x0F55) . Chr(0x0FB2)
LegacyMap[Chr(122)] := Chr(0x0F56)
LegacyMap[Chr(123)] := Chr(0x0F04)
LegacyMap[Chr(124)] := Chr(0x0F11)
LegacyMap[Chr(125)] := Chr(0x0F05)
LegacyMap[Chr(126)] := Chr(0x0FA6)
LegacyMap[Chr(160)] := Chr(0x0020)
LegacyMap[Chr(161)] := Chr(0x0F62) . Chr(0x0FA6)
LegacyMap[Chr(162)] := Chr(0x0F66) . Chr(0x0FA6) . Chr(0x0FB1)
LegacyMap[Chr(163)] := Chr(0x0F66) . Chr(0x0FA6) . Chr(0x0FB2)
LegacyMap[Chr(164)] := Chr(0x0F58)
LegacyMap[Chr(165)] := Chr(0x0F58) . Chr(0x0FB1)
LegacyMap[Chr(167)] := Chr(0x0F58) . Chr(0x0FB2)
LegacyMap[Chr(168)] := Chr(0x0FA8)
LegacyMap[Chr(169)] := Chr(0x0F62) . Chr(0x0FA8)
LegacyMap[Chr(170)] := Chr(0x0F62) . Chr(0x0FA8) . Chr(0x0FB1)
LegacyMap[Chr(171)] := Chr(0x0F66) . Chr(0x0FA8) . Chr(0x0FB1)
LegacyMap[Chr(172)] := Chr(0x0F66) . Chr(0x0FA8) . Chr(0x0FB2)
LegacyMap[Chr(174)] := Chr(0x0F59)
LegacyMap[Chr(175)] := Chr(0x0F62) . Chr(0x0FA9)
LegacyMap[Chr(176)] := Chr(0x0F66) . Chr(0x0FA9)
LegacyMap[Chr(177)] := Chr(0x0F5A)
LegacyMap[Chr(178)] := Chr(0x0F5B)
LegacyMap[Chr(179)] := Chr(0x0F5B)
LegacyMap[Chr(180)] := Chr(0x0FAB)
LegacyMap[Chr(181)] := Chr(0x0F62) . Chr(0x0FAB)
LegacyMap[Chr(182)] := Chr(0x0F5D)
LegacyMap[Chr(184)] := Chr(0x0F5F)
LegacyMap[Chr(185)] := Chr(0x0F5F) . Chr(0x0FB3)
LegacyMap[Chr(186)] := Chr(0x0F60)
LegacyMap[Chr(187)] := Chr(0x0F61)
LegacyMap[Chr(188)] := Chr(0x0F62)
LegacyMap[Chr(189)] := Chr(0x0F62)
LegacyMap[Chr(190)] := Chr(0x0F63)
LegacyMap[Chr(191)] := Chr(0x0F63)
LegacyMap[Chr(192)] := Chr(0x0FB3)
LegacyMap[Chr(193)] := Chr(0x0F64)
LegacyMap[Chr(194)] := Chr(0x0F64) . Chr(0x0FB2)
LegacyMap[Chr(195)] := Chr(0x0F65)
LegacyMap[Chr(196)] := Chr(0x0F65)
LegacyMap[Chr(197)] := Chr(0x0F66)
LegacyMap[Chr(198)] := Chr(0x0F66) . Chr(0x0FB2)
LegacyMap[Chr(199)] := Chr(0x0F66)
LegacyMap[Chr(200)] := Chr(0x0F67)
LegacyMap[Chr(201)] := Chr(0x0F67) . Chr(0x0FB2)
LegacyMap[Chr(203)] := Chr(0x0FB7)
LegacyMap[Chr(204)] := Chr(0x0F67)
LegacyMap[Chr(205)] := Chr(0x0F68)
LegacyMap[Chr(206)] := Chr(0x0F84)
LegacyMap[Chr(207)] := Chr(0x0F84)
LegacyMap[Chr(208)] := Chr(0x0FAD)
LegacyMap[Chr(209)] := Chr(0x0FAD)
LegacyMap[Chr(210)] := Chr(0x0FAD)
LegacyMap[Chr(211)] := Chr(0x0FAD)
LegacyMap[Chr(212)] := Chr(0x0FAD)
LegacyMap[Chr(213)] := Chr(0x0FAD)
LegacyMap[Chr(214)] := Chr(0x0FAD) . Chr(0x0F71)
LegacyMap[Chr(215)] := Chr(0x0F71)
LegacyMap[Chr(216)] := Chr(0x0F71)
LegacyMap[Chr(217)] := Chr(0x0F71)
LegacyMap[Chr(218)] := Chr(0x0F71)
LegacyMap[Chr(219)] := Chr(0x0F72)
LegacyMap[Chr(220)] := Chr(0x0F72) . Chr(0x0F7E)
LegacyMap[Chr(221)] := Chr(0x0F74)
LegacyMap[Chr(222)] := Chr(0x0F74)
LegacyMap[Chr(223)] := Chr(0x0F74)
LegacyMap[Chr(224)] := Chr(0x0F74)
LegacyMap[Chr(225)] := Chr(0x0F74)
LegacyMap[Chr(226)] := Chr(0x0F74)
LegacyMap[Chr(227)] := Chr(0x0F74)
LegacyMap[Chr(228)] := Chr(0x0F74)
LegacyMap[Chr(229)] := Chr(0x0F74)
LegacyMap[Chr(230)] := Chr(0x0F74)
LegacyMap[Chr(231)] := Chr(0x0F74)
LegacyMap[Chr(232)] := Chr(0x0F74)
LegacyMap[Chr(233)] := Chr(0x0F71) . Chr(0x0F74)
LegacyMap[Chr(234)] := Chr(0x0F75)
LegacyMap[Chr(235)] := Chr(0x0F71) . Chr(0x0F74)
LegacyMap[Chr(236)] := Chr(0x0F71) . Chr(0x0F74)
LegacyMap[Chr(237)] := Chr(0x0F80)
LegacyMap[Chr(238)] := Chr(0x0F80) . Chr(0x0F7E)
LegacyMap[Chr(239)] := Chr(0x0F7A)
LegacyMap[Chr(240)] := Chr(0x0F7A) . Chr(0x0F7E)
LegacyMap[Chr(241)] := Chr(0x0F7B)
LegacyMap[Chr(242)] := Chr(0x0F7B) . Chr(0x0F7E)
LegacyMap[Chr(243)] := Chr(0x0F7C)
LegacyMap[Chr(244)] := Chr(0x0F7C)
LegacyMap[Chr(245)] := Chr(0x0F7C) . Chr(0x0F7E)
LegacyMap[Chr(246)] := Chr(0x0F7D)
LegacyMap[Chr(247)] := Chr(0x0F7D) . Chr(0x0F7E)
LegacyMap[Chr(248)] := Chr(0x0F37)
LegacyMap[Chr(249)] := Chr(0x0F83)
LegacyMap[Chr(250)] := Chr(0x0F7F)
LegacyMap[Chr(251)] := Chr(0x0F14)
LegacyMap[Chr(252)] := Chr(0x0F0D)
LegacyMap[Chr(253)] := Chr(0x0F05)
LegacyMap[Chr(254)] := Chr(0x0FBE)
LegacyMap[Chr(255)] := Chr(0x0F5A)
LegacyMap[Chr(339)] := Chr(0x0F4C) . Chr(0x0FB2)
LegacyMap[Chr(352)] := Chr(0x0F82)
LegacyMap[Chr(353)] := Chr(0x0F9C)
LegacyMap[Chr(376)] := Chr(0x0F5E)
LegacyMap[Chr(402)] := Chr(0x0F56) . Chr(0x0FB2)
LegacyMap[Chr(710)] := Chr(0x0F40) . Chr(0x0FB1)
LegacyMap[Chr(732)] := Chr(0x0F55)
LegacyMap[Chr(8211)] := Chr(0x00D0)
LegacyMap[Chr(8212)] := Chr(0x0FB7)
LegacyMap[Chr(8216)] := Chr(0x0063)
LegacyMap[Chr(8217)] := Chr(0x0F67)
LegacyMap[Chr(8218)] := Chr(0x0F56) . Chr(0x0FB1)
LegacyMap[Chr(8222)] := Chr(0x0F56)
LegacyMap[Chr(8224)] := Chr(0x0F4F) . Chr(0x0FB1)
LegacyMap[Chr(8225)] := Chr(0x0F4A)
LegacyMap[Chr(8226)] := Chr(0x0F62) . Chr(0x0F9E)
LegacyMap[Chr(8230)] := Chr(0x0F62) . Chr(0x0FA0)
LegacyMap[Chr(8240)] := Chr(0x0F99)
LegacyMap[Chr(8249)] := Chr(0x0F74)
LegacyMap[Chr(8250)] := Chr(0x0F9C)
LegacyMap[Chr(8482)] := Chr(0x0F53)

; Word's find box mishandles some non-ASCII characters typed directly,
; but always accepts "^0" + the character's Windows-1252 code.
global LegacyFindText := Map()
LegacyFindText[Chr(160)] := "^0160"
LegacyFindText[Chr(161)] := "^0161"
LegacyFindText[Chr(162)] := "^0162"
LegacyFindText[Chr(163)] := "^0163"
LegacyFindText[Chr(164)] := "^0164"
LegacyFindText[Chr(165)] := "^0165"
LegacyFindText[Chr(167)] := "^0167"
LegacyFindText[Chr(168)] := "^0168"
LegacyFindText[Chr(169)] := "^0169"
LegacyFindText[Chr(170)] := "^0170"
LegacyFindText[Chr(171)] := "^0171"
LegacyFindText[Chr(172)] := "^0172"
LegacyFindText[Chr(174)] := "^0174"
LegacyFindText[Chr(175)] := "^0175"
LegacyFindText[Chr(176)] := "^0176"
LegacyFindText[Chr(177)] := "^0177"
LegacyFindText[Chr(178)] := "^0178"
LegacyFindText[Chr(179)] := "^0179"
LegacyFindText[Chr(180)] := "^0180"
LegacyFindText[Chr(181)] := "^0181"
LegacyFindText[Chr(182)] := "^0182"
LegacyFindText[Chr(184)] := "^0184"
LegacyFindText[Chr(185)] := "^0185"
LegacyFindText[Chr(186)] := "^0186"
LegacyFindText[Chr(187)] := "^0187"
LegacyFindText[Chr(188)] := "^0188"
LegacyFindText[Chr(189)] := "^0189"
LegacyFindText[Chr(190)] := "^0190"
LegacyFindText[Chr(191)] := "^0191"
LegacyFindText[Chr(192)] := "^0192"
LegacyFindText[Chr(193)] := "^0193"
LegacyFindText[Chr(194)] := "^0194"
LegacyFindText[Chr(195)] := "^0195"
LegacyFindText[Chr(196)] := "^0196"
LegacyFindText[Chr(197)] := "^0197"
LegacyFindText[Chr(198)] := "^0198"
LegacyFindText[Chr(199)] := "^0199"
LegacyFindText[Chr(200)] := "^0200"
LegacyFindText[Chr(201)] := "^0201"
LegacyFindText[Chr(203)] := "^0203"
LegacyFindText[Chr(204)] := "^0204"
LegacyFindText[Chr(205)] := "^0205"
LegacyFindText[Chr(206)] := "^0206"
LegacyFindText[Chr(207)] := "^0207"
LegacyFindText[Chr(208)] := "^0208"
LegacyFindText[Chr(209)] := "^0209"
LegacyFindText[Chr(210)] := "^0210"
LegacyFindText[Chr(211)] := "^0211"
LegacyFindText[Chr(212)] := "^0212"
LegacyFindText[Chr(213)] := "^0213"
LegacyFindText[Chr(214)] := "^0214"
LegacyFindText[Chr(215)] := "^0215"
LegacyFindText[Chr(216)] := "^0216"
LegacyFindText[Chr(217)] := "^0217"
LegacyFindText[Chr(218)] := "^0218"
LegacyFindText[Chr(219)] := "^0219"
LegacyFindText[Chr(220)] := "^0220"
LegacyFindText[Chr(221)] := "^0221"
LegacyFindText[Chr(222)] := "^0222"
LegacyFindText[Chr(223)] := "^0223"
LegacyFindText[Chr(224)] := "^0224"
LegacyFindText[Chr(225)] := "^0225"
LegacyFindText[Chr(226)] := "^0226"
LegacyFindText[Chr(227)] := "^0227"
LegacyFindText[Chr(228)] := "^0228"
LegacyFindText[Chr(229)] := "^0229"
LegacyFindText[Chr(230)] := "^0230"
LegacyFindText[Chr(231)] := "^0231"
LegacyFindText[Chr(232)] := "^0232"
LegacyFindText[Chr(233)] := "^0233"
LegacyFindText[Chr(234)] := "^0234"
LegacyFindText[Chr(235)] := "^0235"
LegacyFindText[Chr(236)] := "^0236"
LegacyFindText[Chr(237)] := "^0237"
LegacyFindText[Chr(238)] := "^0238"
LegacyFindText[Chr(239)] := "^0239"
LegacyFindText[Chr(240)] := "^0240"
LegacyFindText[Chr(241)] := "^0241"
LegacyFindText[Chr(242)] := "^0242"
LegacyFindText[Chr(243)] := "^0243"
LegacyFindText[Chr(244)] := "^0244"
LegacyFindText[Chr(245)] := "^0245"
LegacyFindText[Chr(246)] := "^0246"
LegacyFindText[Chr(247)] := "^0247"
LegacyFindText[Chr(248)] := "^0248"
LegacyFindText[Chr(249)] := "^0249"
LegacyFindText[Chr(250)] := "^0250"
LegacyFindText[Chr(251)] := "^0251"
LegacyFindText[Chr(252)] := "^0252"
LegacyFindText[Chr(253)] := "^0253"
LegacyFindText[Chr(254)] := "^0254"
LegacyFindText[Chr(255)] := "^0255"
LegacyFindText[Chr(339)] := "^0156"
LegacyFindText[Chr(352)] := "^0138"
LegacyFindText[Chr(353)] := "^0154"
LegacyFindText[Chr(376)] := "^0159"
LegacyFindText[Chr(402)] := "^0131"
LegacyFindText[Chr(710)] := "^0136"
LegacyFindText[Chr(732)] := "^0152"
LegacyFindText[Chr(8211)] := "^0150"
LegacyFindText[Chr(8212)] := "^0151"
LegacyFindText[Chr(8216)] := "^0145"
LegacyFindText[Chr(8217)] := "^0146"
LegacyFindText[Chr(8218)] := "^0130"
LegacyFindText[Chr(8222)] := "^0132"
LegacyFindText[Chr(8224)] := "^0134"
LegacyFindText[Chr(8225)] := "^0135"
LegacyFindText[Chr(8226)] := "^0149"
LegacyFindText[Chr(8230)] := "^0133"
LegacyFindText[Chr(8240)] := "^0137"
LegacyFindText[Chr(8249)] := "^0139"
LegacyFindText[Chr(8250)] := "^0155"
LegacyFindText[Chr(8482)] := "^0153"
global LegacyFonts := ["TCRC Bod-Yig", "TCRC Youtsoweb", "TCRC Youtso"]
global PromptedDocs := Map()

ConvertString(s) {
    global LegacyMap
    out := ""
    loop parse s
        out .= LegacyMap.Has(A_LoopField) ? LegacyMap[A_LoopField] : A_LoopField
    return out
}

; ---- universal: convert selected text (Ctrl+Alt+U) ----
^!u:: {
    saved := ClipboardAll()
    A_Clipboard := ""
    Send "^c"
    if !ClipWait(1) {
        TrayTip "TCRC Converter", "Nothing selected"
        return
    }
    A_Clipboard := ConvertString(A_Clipboard)
    Send "^v"
    Sleep 300
    A_Clipboard := saved
}

; ---- Word: watch for opened legacy documents ----
DetectLegacyText(doc) {
    global LegacyFonts, LegacyFindText
    ; 1) any text still using one of the old legacy font names?
    for f in LegacyFonts {
        try {
            rng := doc.Content.Duplicate
            rng.Find.ClearFormatting()
            rng.Find.Font.Name := f
            rng.Find.Text := ""
            rng.Find.Forward := true
            rng.Find.Wrap := 0
            rng.Find.Format := true        ; search by formatting (the font)
            if rng.Find.Execute()
                return f
        }
    }
    ; 2) legacy characters hiding inside text marked with the NEW font
    ;    (searched by ^0 character code - Word mishandles some of these
    ;     characters, like the fraction signs, as literal search text)
    for sigChar in ["ü", "Û", "ô", "Å", "¾", "º", "¼", "½", "Ç", "¿"] {
        try {
            rng := doc.Content.Duplicate
            rng.Find.ClearFormatting()
            rng.Find.Font.Name := "TCRC Youtso Unicode"
            rng.Find.Text := LegacyFindText.Has(sigChar) ? LegacyFindText[sigChar] : sigChar
            rng.Find.Forward := true
            rng.Find.Wrap := 0
            rng.Find.Format := true
            rng.Find.MatchCase := true
            if rng.Find.Execute()
                return "TCRC Youtso Unicode"
        }
    }
    return ""
}

SetTimer CheckWord, 3000
CheckWord() {
    global PromptedDocs, LegacyFonts
    if !WinActive("ahk_exe WINWORD.EXE")
        return
    try word := ComObjActive("Word.Application")
    catch
        return
    try {
        doc := word.ActiveDocument
        key := doc.FullName
        if PromptedDocs.Has(key)
            return
        found := DetectLegacyText(doc)
        PromptedDocs[key] := true
        if (found = "")
            return
        r := MsgBox("This document contains legacy '" found "' text.`n`nConvert it to Unicode now?`n(The text will display in TCRC Youtso Unicode.)", "TCRC Unicode Converter", "YesNo Iconi")
        if (r = "Yes")
            ConvertWordDoc(word, doc, found)
    }
}

; does this text still contain non-ASCII legacy characters?
HasHighLegacyChars(text) {
    global LegacyMap
    loop parse text {
        if (Ord(A_LoopField) >= 0xA0 && LegacyMap.Has(A_LoopField))
            return true
    }
    return false
}

; convert ONLY the non-ASCII legacy characters; plain ASCII is left alone
; (pass 1 already converted ASCII inside legacy-font runs, so any ASCII
;  still left is real English text that must not be touched)
ConvertHighCharsOnly(text) {
    global LegacyMap
    out := ""
    loop parse text {
        if (Ord(A_LoopField) >= 0xA0 && LegacyMap.Has(A_LoopField))
            out .= LegacyMap[A_LoopField]
        else
            out .= A_LoopField
    }
    return out
}

ConvertWordDoc(word, doc, legacyFont) {
    global LegacyMap, LegacyFindText

    ; ======== FAST MODE ========
    ; Convert the saved .docx file directly with the bundled PowerShell
    ; script - this takes seconds even for hundreds of pages. The result
    ; is saved as "name (Unicode).docx"; the original is never modified.
    fullPath := ""
    try fullPath := doc.FullName
    ps1 := A_ScriptDir "\convert-docx.ps1"
    if (fullPath != "" && FileExist(fullPath) && FileExist(ps1)
        && StrLower(SubStr(fullPath, -5)) = ".docx") {
        converted := ""
        try {
            doc.Save()
            doc.Close(0)
            RunWait('powershell.exe -NoProfile -ExecutionPolicy Bypass -File "' ps1 '" -Path "' fullPath '"', , "Hide")
            SplitPath fullPath, , &folder, , &nameOnly
            converted := folder "\" nameOnly " (Unicode).docx"
        }
        if (converted != "" && FileExist(converted)) {
            try word.Documents.Open(converted)
            MsgBox "Conversion finished (fast mode).`n`nSaved as:`n" converted "`n`nYour original file was not changed.", "TCRC Unicode Converter", "Iconi"
            return
        }
        ; fast mode failed -> reopen the original, continue with slow mode
        try {
            word.Documents.Open(fullPath)
            doc := word.ActiveDocument
        } catch {
            MsgBox "Could not reopen the document after a failed conversion attempt.`nPlease reopen it manually and try again.", "TCRC Unicode Converter", "Iconx"
            return
        }
    }

    ; ======== SLOW MODE (in-Word; preserves all formatting) ========
    word.ScreenUpdating := false

    ; read the whole text once so characters that do not occur in this
    ; document can be skipped entirely (a big speed win)
    allText := ""
    try allText := doc.Content.Text

    ; ---- pass 1: find & replace, character by character ----
    ; (this preserves bold/size/etc. formatting inside paragraphs)
    ; Each character gets its own try, so one failure cannot stop the rest.
    for ch, rep in LegacyMap {
        if (allText != "" && !InStr(allText, ch, true))
            continue
        try {
            f := doc.Content.Find
            f.ClearFormatting()
            f.Replacement.ClearFormatting()
            f.Font.Name := legacyFont
            if LegacyFindText.Has(ch)
                f.Text := LegacyFindText[ch]
            else if (ch = "^")
                f.Text := "^^"
            else
                f.Text := ch
            f.Replacement.Text := rep
            f.Replacement.Font.Name := "TCRC Youtso Unicode"
            f.Forward := true
            f.Wrap := 1            ; wdFindContinue
            f.Format := true
            f.MatchCase := true
            f.MatchWildcards := false
            f.Execute(,,,,,,,,, , 2)   ; wdReplaceAll
        }
    }

    ; ---- pass 2: sweep for anything find & replace missed ----
    ; Some characters do not survive Word's find & replace. Any paragraph
    ; that still contains non-ASCII legacy characters is converted directly.
    swept := 0
    sweepErrors := 0
    totalParagraphs := 0
    remaining := ""
    try remaining := doc.Content.Text
    if (remaining = "" || HasHighLegacyChars(remaining)) {
        try totalParagraphs := doc.Paragraphs.Count
    }
    Loop totalParagraphs {
        try {
            para := doc.Paragraphs.Item(A_Index)
            {
                rng := para.Range.Duplicate
                text := rng.Text
                ; leave the paragraph mark / table-cell mark out of the range
                trailing := 0
                while (trailing < StrLen(text)) {
                    lastChar := SubStr(text, StrLen(text) - trailing, 1)
                    if (lastChar = "`r" || lastChar = Chr(7))
                        trailing += 1
                    else
                        break
                }
                if (trailing > 0) {
                    rng.MoveEnd(1, -trailing)   ; 1 = wdCharacter
                    text := SubStr(text, 1, StrLen(text) - trailing)
                }
                if (text = "" || !HasHighLegacyChars(text))
                    continue
                converted := ConvertHighCharsOnly(text)
                if (converted != text) {
                    rng.Text := converted
                    swept += 1
                }
            }
        } catch {
            sweepErrors += 1
        }
    }

    ; ---- pass 3: leftover characters still marked with the old font
    ; (spaces etc.) -> just switch their font ----
    if (legacyFont != "TCRC Youtso Unicode") {
        try {
            f := doc.Content.Find
            f.ClearFormatting()
            f.Replacement.ClearFormatting()
            f.Font.Name := legacyFont
            f.Text := ""
            f.Replacement.Text := ""
            f.Replacement.Font.Name := "TCRC Youtso Unicode"
            f.Format := true
            f.Execute(,,,,,,,,, , 2)
        }
    }

    word.ScreenUpdating := true
    report := "Conversion finished."
    if (swept > 0)
        report .= "`n(" swept " paragraph(s) needed the deep-sweep pass.)"
    if (sweepErrors > 0)
        report .= "`nWARNING: " sweepErrors " paragraph(s) could not be processed -`nplease check the document and report this."
    report .= "`n`nCheck the text, then save the document.`nThe text is now Unicode in TCRC Youtso Unicode`n(you can switch to Monlam or any Unicode Tibetan font)."
    MsgBox report, "TCRC Unicode Converter", "Iconi"
}

; ---- Ctrl+Alt+N: selected number -> Tibetan digits, Indian grouping ----
; Example: select "900000" and press Ctrl+Alt+N -> it becomes Tibetan 9,00,000
; (For Excel: keep real numbers in cells for math; use this on labels, or
;  see the user guide for a cell format that displays Tibetan digits.)
^!n:: {
    saved := ClipboardAll()
    A_Clipboard := ""
    Send "^c"
    if !ClipWait(1) {
        TrayTip "TCRC Converter", "Nothing selected"
        return
    }
    A_Clipboard := TibetanNumber(A_Clipboard)
    Send "^v"
    Sleep 300
    A_Clipboard := saved
}

TibetanNumber(s) {
    s := Trim(s, " `t`r`n")
    isNegative := SubStr(s, 1, 1) = "-"
    if isNegative
        s := SubStr(s, 2)
    s := StrReplace(s, ",")          ; remove any existing separators

    ; split whole part and decimal part
    dotPosition := InStr(s, ".")
    if (dotPosition > 0) {
        wholePart := SubStr(s, 1, dotPosition - 1)
        decimalPart := SubStr(s, dotPosition + 1)
    } else {
        wholePart := s
        decimalPart := ""
    }

    ; Indian grouping: last 3 digits, then groups of 2 (9,00,000)
    grouped := ""
    if (StrLen(wholePart) > 3) {
        grouped := SubStr(wholePart, StrLen(wholePart) - 2)
        rest := SubStr(wholePart, 1, StrLen(wholePart) - 3)
        while (StrLen(rest) > 2) {
            grouped := SubStr(rest, StrLen(rest) - 1) "," grouped
            rest := SubStr(rest, 1, StrLen(rest) - 2)
        }
        grouped := rest "," grouped
    } else {
        grouped := wholePart
    }

    result := isNegative ? "-" : ""
    result .= grouped
    if (decimalPart != "")
        result .= "." decimalPart

    ; western digits -> Tibetan digits
    tibetan := ""
    loop parse result {
        if (A_LoopField >= "0" && A_LoopField <= "9")
            tibetan .= Chr(0x0F20 + Integer(A_LoopField))
        else
            tibetan .= A_LoopField
    }
    return tibetan
}

; ---- Ctrl+Alt+D: convert the active Word document right now ----
; Use this if the automatic prompt did not appear.
^!d:: {
    global PromptedDocs
    if !WinActive("ahk_exe WINWORD.EXE") {
        TrayTip "TCRC Converter", "Switch to the Word document first, then press Ctrl+Alt+D"
        return
    }
    try word := ComObjActive("Word.Application")
    catch {
        TrayTip "TCRC Converter", "Could not reach Word"
        return
    }
    try {
        doc := word.ActiveDocument
        try PromptedDocs.Delete(doc.FullName)
        found := DetectLegacyText(doc)
        if (found = "") {
            MsgBox "No legacy TCRC text found in this document.", "TCRC Unicode Converter", "Iconi"
            return
        }
        ConvertWordDoc(word, doc, found)
    }
}
