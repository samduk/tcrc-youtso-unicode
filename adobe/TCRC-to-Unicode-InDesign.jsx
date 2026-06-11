// TCRC to Unicode - for Adobe InDesign
//
// HOW TO USE
//   Copy this file into InDesign's Scripts Panel folder
//   (Window > Utilities > Scripts > right-click "User" > Reveal),
//   then double-click it in the Scripts panel.
//
// It works like Find/Change: every character of legacy TCRC text is
// replaced with the correct Unicode Tibetan, formatting preserved,
// and the font is switched to "TCRC Youtso Unicode".
//
// TIP: run it on a COPY of your file, then compare.

var MAP = {33:"\u0F5C",34:"\u0F5B\u0FB2",35:"\u0F7E",36:"\u0F62\u0FB1",37:"\u0025",38:"\u0F38",39:"\u0FB7",40:"\u0028",41:"\u0029",42:"\u0FBE",43:"\u0F90",44:"\u002C",45:"\u0F0B",46:"\u0F0B",47:"\u002F",48:"\u0F20",49:"\u0F21",50:"\u0F22",51:"\u0F23",52:"\u0F24",53:"\u0F25",54:"\u0F26",55:"\u0F27",56:"\u0F28",57:"\u0F29",58:"\u0F08",59:"\u0F40",60:"\u0F83",61:"\u0F40\u0FB2",62:"\u0F40",63:"\u0F90",64:"\u0F62\u0F90",65:"\u0F62\u0F90\u0FB1",66:"\u0F66\u0F90\u0FB1",67:"\u0F66\u0F90\u0FB2",68:"\u0F41",69:"\u0F41\u0FB1",70:"\u0F41\u0FB2",71:"\u0F42",72:"\u0F42\u0FB1",73:"\u0F42\u0FB2",74:"\u0F42",75:"\u0F92",76:"\u0F62\u0F92",77:"\u0F62\u0F92\u0FB1",78:"\u0F66\u0F92\u0FB1",79:"\u0F66\u0F92\u0FB2",80:"\u0F44",81:"\u0F62\u0F94",82:"\u0F94",83:"\u0F94",84:"\u0F45",85:"\u0F95",86:"\u0F46",87:"\u0F47",88:"\u0F62\u0F97",89:"\u0F97",90:"\u0F49",91:"\u0F3C",92:"\u0F4C\u0FB2",93:"\u0F3D",94:"\u0F4C",95:"\u0F9C",96:"\u0F9C",97:"\u0F4E",98:"\u0F4F",99:"\u0F4F\u0FB2",100:"\u0F62\u0F9F",101:"\u0F9F",102:"\u0F50",103:"\u0F50\u0FB2",104:"\u0F51",105:"\u0F51\u0FB2",106:"\u0F51",107:"\u0FA1",108:"\u0F62\u0FA1",109:"\u0F53",110:"\u0F62\u0FA3",111:"\u0FA3",112:"\u0F66\u0FA3\u0FB2",113:"\u0F54",114:"\u0F54\u0FB1",115:"\u0F54\u0FB2",116:"\u0FA4",117:"\u0F66\u0FA4\u0FB1",118:"\u0F66\u0FA4\u0FB2",119:"\u0F55",120:"\u0F55\u0FB1",121:"\u0F55\u0FB2",122:"\u0F56",123:"\u0F04",124:"\u0F11",125:"\u0F05",126:"\u0FA6",160:"\u0020",161:"\u0F62\u0FA6",162:"\u0F66\u0FA6\u0FB1",163:"\u0F66\u0FA6\u0FB2",164:"\u0F58",165:"\u0F58\u0FB1",167:"\u0F58\u0FB2",168:"\u0FA8",169:"\u0F62\u0FA8",170:"\u0F62\u0FA8\u0FB1",171:"\u0F66\u0FA8\u0FB1",172:"\u0F66\u0FA8\u0FB2",174:"\u0F59",175:"\u0F62\u0FA9",176:"\u0F66\u0FA9",177:"\u0F5A",178:"\u0F5B",179:"\u0F5B",180:"\u0FAB",181:"\u0F62\u0FAB",182:"\u0F5D",184:"\u0F5F",185:"\u0F5F\u0FB3",186:"\u0F60",187:"\u0F61",188:"\u0F62",189:"\u0F62",190:"\u0F63",191:"\u0F63",192:"\u0FB3",193:"\u0F64",194:"\u0F64\u0FB2",195:"\u0F65",196:"\u0F65",197:"\u0F66",198:"\u0F66\u0FB2",199:"\u0F66",200:"\u0F67",201:"\u0F67\u0FB2",203:"\u0FB7",204:"\u0F67",205:"\u0F68",206:"\u0F84",207:"\u0F84",208:"\u0FAD",209:"\u0FAD",210:"\u0FAD",211:"\u0FAD",212:"\u0FAD",213:"\u0FAD",214:"\u0FAD\u0F71",215:"\u0F71",216:"\u0F71",217:"\u0F71",218:"\u0F71",219:"\u0F72",220:"\u0F72\u0F7E",221:"\u0F74",222:"\u0F74",223:"\u0F74",224:"\u0F74",225:"\u0F74",226:"\u0F74",227:"\u0F74",228:"\u0F74",229:"\u0F74",230:"\u0F74",231:"\u0F74",232:"\u0F74",233:"\u0F71\u0F74",234:"\u0F75",235:"\u0F71\u0F74",236:"\u0F71\u0F74",237:"\u0F80",238:"\u0F80\u0F7E",239:"\u0F7A",240:"\u0F7A\u0F7E",241:"\u0F7B",242:"\u0F7B\u0F7E",243:"\u0F7C",244:"\u0F7C",245:"\u0F7C\u0F7E",246:"\u0F7D",247:"\u0F7D\u0F7E",248:"\u0F37",249:"\u0F83",250:"\u0F7F",251:"\u0F14",252:"\u0F0D",253:"\u0F05",254:"\u0FBE",255:"\u0F5A",339:"\u0F4C\u0FB2",352:"\u0F82",353:"\u0F9C",376:"\u0F5E",402:"\u0F56\u0FB2",710:"\u0F40\u0FB1",732:"\u0F55",8211:"\u00D0",8212:"\u0FB7",8216:"\u0063",8217:"\u0F67",8218:"\u0F56\u0FB1",8222:"\u0F56",8224:"\u0F4F\u0FB1",8225:"\u0F4A",8226:"\u0F62\u0F9E",8230:"\u0F62\u0FA0",8240:"\u0F99",8249:"\u0F74",8250:"\u0F9C",8482:"\u0F53"};
// Convert one string of legacy TCRC characters to Unicode Tibetan.
function convertText(text) {
    var result = "";
    for (var i = 0; i < text.length; i++) {
        var code = text.charCodeAt(i);
        if (MAP[code] !== undefined) {
            result += MAP[code];
        } else {
            result += text.charAt(i);
        }
    }
    return result;
}

// Conservative fallback for stories whose font metadata is unavailable.
function looksLegacy(text) {
    var mappedHighCharacters = 0;
    var nonSpaceLength = 0;
    for (var i = 0; i < text.length; i++) {
        var code = text.charCodeAt(i);
        if (!/\s/.test(text.charAt(i))) {
            nonSpaceLength++;
        }
        if (code >= 0xA0 && code <= 0xFF && MAP[code] !== undefined) {
            mappedHighCharacters++;
        }
    }
    return mappedHighCharacters >= 2 &&
           mappedHighCharacters * 2 >= Math.max(nonSpaceLength, 1);
}

var LEGACY_FONTS = ["TCRC Bod-Yig", "TCRC Youtsoweb", "TCRC Youtso"];
var UNICODE_FONT = "TCRC Youtso Unicode";

function convertWithFindChange(doc) {
    var replacements = 0;
    for (var f = 0; f < LEGACY_FONTS.length; f++) {
        for (var code in MAP) {
            app.findTextPreferences = NothingEnum.NOTHING;
            app.changeTextPreferences = NothingEnum.NOTHING;
            app.findChangeTextOptions.caseSensitive = true;
            app.findTextPreferences.findWhat = String.fromCharCode(Number(code));
            app.findTextPreferences.appliedFont = LEGACY_FONTS[f];
            app.changeTextPreferences.changeTo = MAP[code];
            try { app.changeTextPreferences.appliedFont = UNICODE_FONT; } catch (e) { }
            try {
                var found = doc.changeText();
                replacements += found.length;
            } catch (e) { }
        }
    }
    app.findTextPreferences = NothingEnum.NOTHING;
    app.changeTextPreferences = NothingEnum.NOTHING;
    return replacements;
}

function sweepRemainingStories(doc) {
    // safety net: stories that still contain legacy characters
    // (for example text whose font was changed by hand earlier)
    var swept = 0;
    for (var s = 0; s < doc.stories.length; s++) {
        var story = doc.stories[s];
        if (!looksLegacy(story.contents)) {
            continue;
        }
        var goAhead = confirm(
            "A text story still contains legacy characters that were not\\n" +
            "marked with a TCRC font. Convert it as well?\\n\\n" +
            "(Character formatting inside this story may be simplified.)");
        if (!goAhead) {
            continue;
        }
        story.contents = convertText(story.contents);
        try { story.texts[0].appliedFont = UNICODE_FONT; } catch (e) { }
        swept++;
    }
    return swept;
}

if (app.documents.length === 0) {
    alert("Open a document first, then run this script again.");
} else {
    var doc = app.activeDocument;
    var replaced = convertWithFindChange(doc);
    var swept = sweepRemainingStories(doc);
    alert("Done.\\n" + replaced + " characters converted by Find/Change.\\n" +
          swept + " additional story/stories converted by the sweep.");
}
