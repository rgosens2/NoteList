//=============================================================================
//  MuseScore
//
//  Note List Plugin
//
//  Show and save a note list of the score or a selection
//
//  Version 2.1
//
//  Copyright (C) 2021 rgos
//=============================================================================
import QtQuick 2.0
import QtQuick.Controls 1.1
import QtQuick.Controls.Styles 1.3
import QtQuick.Layouts 1.1
import QtQuick.Window 2.2
import Qt.labs.settings 1.0
import QtQuick.Dialogs 1.1

import FileIO 3.0

import MuseScore 3.0


MuseScore {
    menuPath: "Plugins.Note List (Dark)"
    version: "3.0"
    description: qsTr("Show and save a note list of the score or a selection")
    pluginType: "dialog"
    requiresScore: true


    /////////////////
    // JS global var for access in QML
    // Alas QML does not use the variable that JS has changed
    // TODO: make QML access a JS var
    // YESS: works now!!! Accessible from QML and JS can manipulate the var
    property var notelist: ""
    property var msg: ""

    function saveNotelist() {
        // Still can't access notelist of course. Do we really have to rebuild it here?
        // No. It works now!!!
        var rc = outfile.write(notelist);
        if (rc) {
              msg = "Note list has been saved in " + outfile.source;
              console.log(msg);
              //txtSaved.text = msg;
              return [true, outfile.source];
              // Cannot show message box from JS
              //alert("Alert text");
              //if (Qt.platform.os=="windows") {
              //    proc.start("notepad " + outfile.source); // Windows
              //}
        } else {
              msg = "Could not write note list to " + outfile.source;
              console.log(msg);
              //txtSaved.text = msg;
              return [false, outfile.source];
        }
    }


    /////////////////
    // TODO: gaat fout met opmaat: er wordt tweemaal measure 1 geteld
    // NOTE: let op dat de maatnummering bij een opmaat/pickup telt vanaf de eerste hele maat maar dat Ms
    // zelf de opmaat als nummer 1 telt, maar dat was hier niet het issue. Hij deed iets met noOffset en irregular
    function buildMeasureMap(score) {
        var map = {};
        var no = 1;
        var cursor = score.newCursor();
        cursor.rewind(Cursor.SCORE_START);
        while (cursor.measure) {
            var m = cursor.measure;
            var tick = m.firstSegment.tick;
            var tsD = m.timesigActual.denominator;
            var tsN = m.timesigActual.numerator;
            var ticksB = division * 4.0 / tsD;
            var ticksM = ticksB * tsN;
            //no += m.noOffset;
            var cur = {
                "tick": tick,
                "tsD": tsD,
                "tsN": tsN,
                "ticksB": ticksB,
                "ticksM": ticksM,
                "past" : (tick + ticksM),
                "no": no
            };
            map[cur.tick] = cur;
            console.log(tsN + "/" + tsD + " measure " + no +
                " at tick " + cur.tick + " length " + ticksM);
            //if (!m.irregular)
            //  ++no;
            no++;
            cursor.nextMeasure();
        }
        return map;
    }

    function showPos(cursor, measureMap) {
        var t = cursor.segment.tick;
        var m = measureMap[cursor.measure.firstSegment.tick];
        var b = "?";
        if (m && t >= m.tick && t < m.past) {
            b = 1 + (t - m.tick) / m.ticksB;
        }

        return "St: " + (cursor.staffIdx + 1) +
            " Vc: " + (cursor.voice + 1) +
            " Ms: " + m.no + " Bt: " + b;
    }
    ////////////////////



    onRun: {
        if (!curScore) {
            console.log(qsTranslate("QMessageBox", "No score open.\nThis plugin requires an open score to run.\n"));
            Qt.quit();
        }


        // TODO: make accessible from QML
        //var notelist = '';


        // RG: why do we have to start at -3 to get the correct number of measures?
        // It is because we loop through segments and we had 4 notes in the first measure
        // It only works when measures are empty.
        var internalMeasureNumber = 1; //we will use this to track the current measure number
        //var currentMeasure = null; //we use this to keep a reference to the actual measure, so we can know when it changes

        var chordCount = 0;
        var noteCount = 0;

        var noteCountC = 0;
        var noteLengthC = 0;
        var noteCountCis = 0;
        var noteLengthCis = 0;

        var measureCount = 0;
        measureCount = curScore.nmeasures;

        var staffCount = 0;
        staffCount = curScore.nstaves;

        var partCount = 0;
        partCount = curScore.parts.length;

        // for selection
        var measureCount2 = 0;
        var staffCount2 = 0;
        var partCount2 = 0;
        var oldPart = 0;

        //get a cursor to be able to run over the score
        var cursor = curScore.newCursor();
        cursor.rewind(0);
        cursor.voice = 0;
        cursor.staffIdx = 0;


        var measure = 1;
        var beat = 1;

        //var tickCount = 0;



        // find ticks for measure 2
        var m2 = cursor.measure.nextMeasure.firstSegment.tick;
        console.log('m2: ' + m2);

        var nextM = m2;


        var measureMap = buildMeasureMap(curScore);




        // TODO: loop through all staves
        // NOTE: when staves are made invisible they are still counted: check for visibility


        // HELL: we can only loop through 2 staves. Why?
        // Works OK with Ligeti but not our Test1 file.
        // staffCount is OK.
        // If we recreate the cursor it will work.


        var staffBeg = 0;
        var staffEnd = staffCount;
        var tickEnd = 0;
        var toEOF = true;


        // TEST: We have a selection
        if (curScore.selection.startSegment) {
            console.log('Sel start: ' + curScore.selection.startSegment.tick);
            //console.log('Sel end: ' + curScore.selection.endSegment.tick);
            cursor.rewind(Cursor.SELECTION_END);
            cursor.staffIdx = 0;
            cursor.voice = 0;
            if (!cursor.tick) {
                /*
                 * This happens when the selection goes to the
                 * end of the scorerewind() jumps behind the
                 * last segment, setting tick = 0.
                 */
                toEOF = true;
            } else {
                toEOF = false;
                tickEnd = cursor.tick;
            }

            // find staffs of selection
            staffBeg = curScore.selection.startStaff;
            staffEnd = curScore.selection.endStaff;
            console.log('Staff beg: ' + staffBeg);
            console.log('Staff end: ' + staffEnd);


            // TODO: find the correct number of measures, staves and parts for a selection
            staffCount2 = staffEnd - staffBeg;

            //var mstart = measureMap[curScore.selection.startSegment.tick];
            //var mend = measureMap[curScore.selection.endSegment.tick];
            //measureCount = mend.no - mstart.no;
            // Jammer: Cannot read property 'no' of undefined
            // Als we een een deel van een voorgaande measure selecteren dan staat voor die tick
            // de measure niet in de measuremap (die bevat alleen de begin tick van measures).
            // Hoe op te lossen?
            // We kunnen in de notelist de hoogste en laagste measure vinden en die gebruiken.
            // Of zo:
            cursor.rewind(Cursor.SELECTION_START);
            cursor.staffIdx = curScore.selection.startStaff;
            cursor.voice = 0;
            // Use measure map
            var mstart = measureMap[cursor.measure.firstSegment.tick];

            cursor.rewind(Cursor.SELECTION_END);
            cursor.staffIdx = curScore.selection.endStaff;
            cursor.voice = 0;
            // Use measure map
            // SHIT: cursor.measure null when select All
            // HACK:
            if (toEOF) {
                measureCount2 = measureCount;
            } else {
                var mend = measureMap[cursor.measure.firstSegment.tick];
                measureCount2 = (mend.no - mstart.no) + 1;
            }


        }







        // loop through all staves
        //for (var s = 0; s < staffCount; s++) {
        for (var s = staffBeg; s < staffEnd; s++) {
            //cursor = curScore.newCursor(); // recreate to be sure
            //cursor.rewind(0);
            //cursor.staffIdx = s;
            //cursor.voice = 0;
            // TEST:
            if (curScore.selection.startSegment) {
              cursor.rewind(Cursor.SELECTION_START);
            } else {
              cursor.rewind(Cursor.SCORE_START);
            }
            // HELL: now staff change does not work. Why?
            // Cursor rewind is flaky. See: https://musescore.org/en/node/301846
            // Looks like cursor does not change to the next staff when there is a selection
            // Yep, confirmed: count-note-beats.qml heeft er ook last van: selecteer twee staves
            // en de onderste krijgt geen beats.
            // YESS: we forgot to add a staff indication in the voice loop after a rewind
            // Also, we do not need the rewind here in the staff loop, only the voice loop
            // so get rid of all that crap here
            // Well, we do need to rewind here or we will not find the last staff when there is
            // no selection
            //cursor.voice = 0;
            cursor.staffIdx = s;
            cursor.voice = 0;

            //console.log('s: ' + s)



            // restart
            //measure = 1;
            //nextM = m2;

            // loop through all voices
            for (var v = 0; v < 4; v++) {
                //cursor.rewind(0);
                // TEST:
                //cursor.rewind(Cursor.SELECTION_START); // Fucker does not rewind properly for voice 2 selection!!!
                //cursor.rewindToTick(curScore.selection.startSegment.tick); // Hell, still does not rewind
                if (curScore.selection.startSegment) {
                    cursor.rewind(Cursor.SELECTION_START);
                } else {
                    cursor.rewind(Cursor.SCORE_START);
                }

                //console.log(curScore.selection.startSegment);



                //console.log('t: ' + cursor.tick); // we are not getting the right tick here

                // NOTE NOTE NOTE: After a rewind we always need a voice AND staff indication!!!!!
                cursor.staffIdx = s;
                cursor.voice = v;

                console.log('s: ' + s);
                console.log('v: ' + v);


                // TODO:
                // * select All gives no output. Probably because of end measure overshoot. Fix it.
                // DONE: use toEOF to account for selection to end of score
                // * no select does not see all staffs. Fix it.
                // DONE: rewind in staff loop


                // selection geeft de juiste start en end tick voor voice 2 selection.
                // Maar als we rewind doen gaat dat kennelijk op basis van voice 1 en dan wordt niks gevonden
                // en pakt ie maar de tick van het eerstvolgende voice 1 segment buiten de selectie.
                // En zelfs als we een noot in voice 1 zetten aan begin selectie gaat het ook fout: de cursor
                // rewind dan wel correct maar de voice wordt niet opgehoogd.
                // Yep, confirmed: als v is opgehoogd zou de cursor naar de volgende voice moeten gaan
                // maar hij blijft in voice 1.
                // YESS: we must do cursor voice change AFTER rewind
                //console.log('v: ' + v)
                //console.log( showPos(cursor, measureMap) );


                // restart
                //measure   = 1;
                //nextM = m2;

                // loop through all segments
                // TEST: with selection
                //while (cursor.segment) {
                while (cursor.segment && (toEOF || cursor.tick < tickEnd)) {
                    // TEST: selection
                    // TODO: make it work when only voice 2 notes are selected
                    // Het lijkt wel alsof Cursor.SELECTION_START niet goed rewind als er slechts
                    // noten in voice 2 geselecteerd zijn. Pas als er een noot van voice 1 mee is
                    // geselecteerd krijgen we de juiste tick.
                    console.log('ts: ' + cursor.segment.tick);
                    console.log('tickEnd: ' + tickEnd);
                    //console.log('Sel end: ' + curScore.selection.endSegment.tick);
//                    if (curScore.selection.startSegment) {
//                        //if (cursor.segment.tick >= curScore.selection.endSegment.tick) break;
//                        if (cursor.segment.tick >= tickEnd) break;
//                    }

                    // TODO: count correctly when measures are full
                    // SHIT: why are we getting 4 different pointers to the first measure?
                    // This causes the 3 times overcount of measures when there are 4 chords in the first measure
                    //console.log(cursor.measure);
                    // We should just use:
                    //measureCount = curScore.nmeasures;

                    // NONO:
        //            if (cursor.measure != currentMeasure) {
        //                 //we moved into a new measure
        //                 // NONO: will not work because cursor.measure returns a different pointer for every chord
        //                 // even when in the same measure!!! Sucks!!!
        //                 internalMeasureNumber++;
        //                 currentMeasure = cursor.measure;
        //
        //                 // LOOK: how nasty
        //                 console.log(cursor.measure);
        //
        //                 // TODO: find a way to count measures correctly in a loop
        //            }


                    // TODO: list all notes as in the Musescore status bar:
                    // Note; Pitch: C6; Duration: Quarter; Voice: 1; Measure: 1; Beat: 1; Staff: 1 (Piano)


                    // TODO: get instrument name
                    // MS uses Part.longName in the status bar
                    //console.log(cursor.part.longName);
                    // This works but how do we find out how many staves a part has?
                    // See Staff.part:
                    // Ms::PluginAPI::Part  part
                    // Part which this staff belongs to
                    //
                    // So like this: Score->Stave->Part
                    //console.log(curScore.parts[0].longName); // works
                    //console.log(curScore.staves[s].part.longName); // why not?
                    //console.log(curScore.title);
                    // staves is niet bereikbaar, fout in API
                    // Yep: https://musescore.org/en/node/317368
                    //console.log(curScore.parts.length); // OK
                    //console.log(curScore.staves.length); // cannot read property of undefined
                    // YESS: can get staff via element
                    // cursor.element.staff.part.longName

                    // TEST: find actual time sig
                    // YESS: need cursor.measure
                    //console.log(cursor.measure.timesigActual.numerator + '/' + cursor.measure.timesigActual.denominator);

                    // TEST:
                    var m = cursor.measure;
                    var tsD = m.timesigActual.denominator;
                    var tsN = m.timesigActual.numerator;
                    var ticksB = division * 4.0 / tsD;
                    var ticksM = ticksB * tsN;

                    //console.log(ticksB + '/' + ticksM);





                    // we are looping through segments, can we find the proper measure and beat without
                    // first constructing a measure map?
                    //var t = cursor.tick;


                    // YESS: it can be done like this
                    // TODO: find a way to find the initial nextM
                    // DONE
                    // SHIT: things go wrong with voice 2 with empty measures because of firstSegment
                    // skipping totally empty measures
                    // NOTE: dit moet dus ook fout gaan in count-note-beats.qml maar daar is het niet
                    // erg want het measure nummer is niet nodig, alleen de beat. En dat gaat goed.
                    // TODO: hoe kunnen we juist blijven tellen bij maten die helemaal leeg zijn?
                    // Hebben we toch een measure map nodig die is gemaakt met voice 1 die nooit helemaal
                    // lege maten heeft?
                    // Is waarschijnlijk toch het handigst: je kunt dan voor elk segment met zijn tick
                    // opzoeken in welke maat het zich bevindt.
                    // Old method
                    var t = cursor.segment.tick;
                    //console.log(t);


                    // Use measure map
                    var mm = measureMap[cursor.measure.firstSegment.tick];
                    measure = mm.no;

                    beat = 1 + (t - mm.tick) / mm.ticksB;


                    // TODO: round beat to 5 decimals for triplets
                    beat = +beat.toFixed(5);



                    // TEST:
                    //console.log( showPos(cursor, measureMap) );




                    // TEST: part count for selection
                    if (curScore.selection.startSegment) {
                        if (cursor.element && !cursor.element.staff.part.is(oldPart)) {
                            partCount2++;
                            oldPart = cursor.element.staff.part;
                        }
                        //console.log('Part: ' + cursor.element.staff.part.is(cursor.element.staff.part));
                        console.log('Part Count: ' + partCount2);
                    }





                    // TEST: count notes
                    if (cursor.element && cursor.element.type == Element.CHORD) {
                        chordCount++;
                        //noteCount += cursor.element.notes.length;

                        //console.log('Chords: ' + chordCount);
                        //console.log('Notes: ' + noteCount);

                        // TEST: print measure number
                        //console.log( 'Measure: ' + ( Math.floor(cursor.tick/1920) + 1) );
                        //console.log( 'Beat: ' + (((cursor.tick/480)%4) + 1) );

                        // TODO: 1920 for measure and 480 for beat are for quarter note
                        // Make universal and make sure it works with unregular measures
                        // and pickup measures
                        // A pickup measure of 1 quarter is measure 1, beat 1 so must use
                        // Actual measure duration (timesigActual)
                        // For every measure we are in we need to know the actual time signature
                        // Use cursor.element.timesigActual
                        //var measure = Math.floor(cursor.tick/1920) + 1;
                        //var beat = (cursor.tick/480)%4 + 1;




                        // get note duration
                        var duration = cursor.element.duration.str;


                        // TODO: get all the notes in a chord
                        // DONE
                        //console.log(cursor.element.notes.CountFunction);
                        //console.log( cursor.element.notes.length );

                        // TODO: loop through all notes in a chord and count the pitches
                        for (var i = 0; i < cursor.element.notes.length; i++) {
                            noteCount++;

                            // TEST:
                            switch (cursor.element.notes[i].tpc) {
                                case 14:
                                case 26:
                                case 2:
                                    noteCountC++;
                                    noteLengthC += cursor.element.duration.ticks;
                                    // TEST: print note and length and voice
                                    //console.log('Voice: ' + (v+1) + ' Note: C' + ' ' + cursor.element.duration.str);
                                    //console.log('Note; Pitch: C; Duration: ' + duration + '; Voice: ' + (v+1) + '; Measure: ' + measure +'; Beat: ' + beat + '; Staff 1');
                                    break;
                                case 21:
                                case 33:
                                case 9:
                                    noteCountCis++;
                                    noteLengthCis += cursor.element.duration.ticks;
                                    // TEST: print note and length and voice
                                    //console.log('Voice: ' + (v+1) + ' Note: C#/Db' + ' ' + cursor.element.duration.str);
                                    //console.log('Note; Pitch: C#/Db; Duration: ' + duration + '; Voice: ' + (v+1) + '; Measure: ' + measure +'; Beat: ' + beat + '; Staff 1');
                                    break;
                            }

                            var pitch = cursor.element.notes[i].pitch;
                            var tpc   = cursor.element.notes[i].tpc;

                            var octave = Math.floor(pitch/12)-1;
                            var notename = '';

                            switch (pitch%12) {
                                case 0:
                                    if (tpc == 26) notename ='B#';
                                    if (tpc == 14) notename ='C';
                                    if (tpc == 2 ) notename ='Dbb';
                                    break;
                                case 1:
                                    if (tpc == 33) notename ='B##';
                                    if (tpc == 21) notename ='C#';
                                    if (tpc == 9 ) notename ='Db';
                                    break;
                                case 2:
                                    if (tpc == 28) notename ='C##';
                                    if (tpc == 16) notename ='D';
                                    if (tpc == 4 ) notename ='Ebb';
                                    break;
                                case 3:
                                    if (tpc == 23) notename ='D#';
                                    if (tpc == 11) notename ='Eb';
                                    if (tpc == -1) notename ='Fbb';
                                    break;
                                case 4:
                                    if (tpc == 30) notename ='D##';
                                    if (tpc == 18) notename ='E';
                                    if (tpc == 6 ) notename ='Fb';
                                    break;
                                case 5:
                                    if (tpc == 25) notename ='E#';
                                    if (tpc == 13) notename ='F';
                                    if (tpc == 1 ) notename ='Gbb';
                                    break;
                                case 6:
                                    if (tpc == 32) notename ='E##';
                                    if (tpc == 20) notename ='F#';
                                    if (tpc == 8 ) notename ='Gb';
                                    break;
                                case 7:
                                    if (tpc == 27) notename ='F##';
                                    if (tpc == 15) notename ='G';
                                    if (tpc == 3 ) notename ='Abb';
                                    break;
                                case 8:
                                    if (tpc == 22) notename ='G#';
                                    //
                                    if (tpc == 10 ) notename ='Ab';
                                    break;
                                case 9:
                                    if (tpc == 29) notename ='G##';
                                    if (tpc == 17) notename ='A';
                                    if (tpc == 5 ) notename ='Bbb';
                                    break;
                                case 10:
                                    if (tpc == 24) notename ='A#';
                                    if (tpc == 12) notename ='Bb';
                                    if (tpc == 0 ) notename ='Cbb';
                                    break;
                                case 11:
                                    if (tpc == 31) notename ='A##';
                                    if (tpc == 19) notename ='B';
                                    if (tpc == 7 ) notename ='Cb';
                                    break;
                            }


/*
pitch   tpc name    tpc name    tpc name
11  31  A## 19  B   7   Cb
10  24  A#  12  Bb  0   Cbb
9   29  G## 17  A   5   Bbb
8   22  G#          10  Ab
7   27  F## 15  G   3   Abb
6   32  E## 20  F#  8   Gb
5   25  E#  13  F   1   Gbb
4   30  D## 18  E   6   Fb
3   23  D#  11  Eb  -1  Fbb
2   28  C## 16  D   4   Ebb
1   33  B## 21  C#  9   Db
0   26  B#  14  C   2   Dbb
*/


                            // get part
                            var part = cursor.element.staff.part.longName;



                            // TODO: print correct notename using tpc and pitch
                            // DONE
                            //console.log(notename + octave);
                            console.log('Note; Pitch: ' + notename + octave + '; Duration: ' + duration + '; Voice: ' + (v+1) + '; Measure: ' + measure + '; Beat: ' + beat + '; Staff: ' + (s+1) + ' (' + part + ')');


                            tV.append({ number: noteCount,
                                        element: 'Note',
                                        pitch: notename + octave,
                                        duration: duration,
                                        voice: (v+1),
                                        measure: measure,
                                        beat: beat,
                                        staff: (s+1),
                                        part: part});

                            notelist += (noteCount + '; Note; Pitch: ' + notename + octave + '; Duration: ' + duration + '; Voice: ' + (v+1) + '; Measure: ' + measure + '; Beat: ' + beat + '; Staff: ' + (s+1) + ' (' + part + ')');
                            notelist += '\n';


                        } // End note loop


                        // TEST: get duration of note
                        //console.log('Length: ' + cursor.element.duration.ticks);

                        //console.log(noteCount);

                    } // End chord loop

                    // step to next segment
                    cursor.next();


                } // End while loop segments

                // rewind for next voice (will do at begin)
                //cursor.rewind(0);

            } // End voice loop

            // rewind cursor for next staff (not necessary)
            //cursor.rewind(0);

        } // End staff loop



        // TEST: Count number of measures with cursor loop
        // Why does it no longer work since we added voice count?
        // DONE: it works again with a new cursor. Why can't we use the old one?
        var cursor2 = curScore.newCursor();
        cursor2.rewind(0);
        cursor2.voice = 0;
        cursor2.staffIdx = 0;
        while ( cursor2.nextMeasure() ) {
            internalMeasureNumber++;
            //console.log('M');
        }


        // NONO: this will overcount when measures contain notes
        // DONE: its correct now
        console.log('Measures: ' + internalMeasureNumber);
        //Qt.quit();


        // List counts
        if (curScore.selection.startSegment) {
            helloQml0.text = 'Selection';
            helloQml1.text = 'Found ' + measureCount2 + ' measures.';
            helloQml2.text = 'Found ' + noteCount + ' notes.'; // is OK
            helloQml3.text = 'Found ' + staffCount2 + ' staves.';
            helloQml4.text = 'Found ' + partCount2 + ' parts.';
        } else {
            helloQml0.text = 'Score';
            helloQml1.text = 'Found ' + measureCount + ' measures.';
            helloQml2.text = 'Found ' + noteCount + ' notes.';
            helloQml3.text = 'Found ' + staffCount + ' staves.';
            helloQml4.text = 'Found ' + partCount + ' parts.';
        }




        // list notes
//        helloQmlC.text =   '\t' + noteCountC   + '\t' + noteLengthC/480;
//        helloQmlCis.text = '\t' + noteCountCis + '\t' + noteLengthCis/480;


        // TEST: fill table YESS
//        tV.append({title: "some value",
//                           author: "Another value",
//                           year: "One more value",
//                           revision: "uno mas"});

        // Write note list to home dir
        // TODO: we actually want to do this from QML with a button but cannot access the JS variable
        // DONE
        //var rc = outfile.write(notelist);



    }


    ////////////////////////////////////////////////////
    FileIO {
        id: outfile
        source: homePath() + "/" + curScore.scoreName + "_notelist.csv"
        onError: console.log(msg)
    }


    width:  700
    height: 475

    Rectangle {
        //id: myRect
        //color: "blue"
        //anchors.fill: parent
        //anchors.margins: 10

        Text {
            id: helloQml0
            //anchors.centerIn: parent
            x: 20
            y: 20
            text: qsTr("Hello Qml")
            color: "#ffffff"
            font.bold: true
        }

        Rectangle {
            color: "white"
            //anchors.horizontalCenter: parent.horizontalCenter
            height: 1
            width: 660
            x: 20
            y: 40
        }

        Rectangle {
            color: "grey"
            //anchors.horizontalCenter: parent.horizontalCenter
            height: 1
            width: 660
            x: 20
            y: 41
        }

        Text {
            id: helloQml1
            //anchors.centerIn: parent
            x: 20
            y: 50
            text: qsTr("Hello Qml")
            color: "#ffffff"
        }

        Text {
            id: helloQml2
            //anchors.centerIn: parent
            x: 20
            y: 70
            text: qsTr("Hello Qml")
            color: "#ffffff"
        }

        Text {
            id: helloQml3
            //anchors.centerIn: parent
            x: 20
            y: 90
            text: qsTr("Hello Qml")
            color: "#ffffff"
        }

        Text {
            id: helloQml4
            //anchors.centerIn: parent
            x: 20
            y: 110
            text: qsTr("Hello Qml")
            color: "#ffffff"
        }

//        Rectangle {
//          color: "grey"
//          //anchors.horizontalCenter: parent.horizontalCenter
//          height: 1
//          width: 300
//          y: 10
//          x: 25
//        }
//
//        Label {
//            x: 20
//            y: 70
//            text: qsTr("C")
//            font.bold: true
//        }
//
//        Text {
//          id: helloQmlC
//            //anchors.centerIn: parent
//            x: 40
//            y: 70
//            text: qsTr("Hello Qml")
//        }
//
//        Label {
//            x: 20
//            y: 90
//            text: qsTr("C#/Db")
//            font.bold: true
//        }
//
//        Text {
//          id: helloQmlCis
//            //anchors.centerIn: parent
//            x: 40
//            y: 90
//            text: qsTr("Hello Qml")
//        }



//        ListModel {
//          ListElement {
//              name: "Bill Smith"
//              number: "555 3264"
//          }
//          ListElement {
//              name: "John Brown"
//              number: "555 8426"
//          }
//          ListElement {
//              name: "Sam Wise"
//              number: "555 0473"
//          }
//      }


        TableView {
            x: 20
            y: 170
            width: 660
            height: 200
            //enabled: enabledCheck.checked

            TableViewColumn { role: "number" ; title: "#" ; width: 50 ; resizable: true ; movable: true  }
            TableViewColumn { role: "element" ; title: "Element" ; width: 70 ; resizable: true ; movable: true  }
            TableViewColumn { role: "pitch"  ; title: "Pitch" ; width: 50 ;resizable: true ; movable: true }
            TableViewColumn { role: "duration" ; title: "Duration" ; width: 70 ;resizable: true ; movable: true }
            TableViewColumn { role: "voice" ; title: "Voice" ; width: 50 ;resizable: true ; movable: true }
            TableViewColumn { role: "measure" ; title: "Measure" ; width: 70 ; resizable: true ; movable: true  }
            TableViewColumn { role: "beat"  ; title: "Beat" ; width: 70 ;resizable: true ; movable: true }
            TableViewColumn { role: "staff" ; title: "Staff" ; width: 50 ;resizable: true ; movable: true }
            TableViewColumn { role: "part" ; title: "Part" ; width: 120 ;resizable: true ; movable: true }

            model: ListModel {
                id: tV
            }


            // TODO: sorting when clicking column headers
            //sortingEnabled: true

            alternatingRowColors: true
            backgroundVisible: true
            headerVisible: true

            //style: TableViewStyle {
//              headerDelegate: Rectangle {
//                  height: textItem.implicitHeight * 1.2
//                  width: textItem.implicitWidth
//                  //color: "lightsteelblue"
//                  Text {
//                      id: textItem
//                      anchors.fill: parent
//                      verticalAlignment: Text.AlignVCenter
//                      horizontalAlignment: styleData.textAlignment
//                      anchors.leftMargin: 12
//                      text: styleData.value
//                      elide: Text.ElideRight
//                      color: textColor
//                      renderType: Text.NativeRendering
//                  }
//              }
                itemDelegate: Item {
                    Text {
                        //id: textItem
                        anchors.fill: parent
                        //verticalAlignment: Text.AlignVCenter
                        //horizontalAlignment: styleData.textAlignment
                        anchors.leftMargin: 5
                        text: styleData.value
                        color: "#ffffff"
                        //elide: Text.ElideRight
                        //color: textColor
                        //renderType: Text.NativeRendering
                    }
                } // Item
            //}
        }// TableView





//        MouseArea {
//            anchors.fill: parent
//            onClicked: Qt.quit()
//        }


        MessageDialog {
            id: messageDialog
            title: "May I have your attention please"
            text: "It's so cool that you are using Qt Quick."
            //modality: Qt.NonModal
            onAccepted: {
                console.log("And of course you could only agree.")
                txtSaved.text = msg;
                //Qt.quit()
            }
            Component.onCompleted: visible = false
        }


        Text {
            id: txtSaved
            //anchors.centerIn: parent
            x: 20
            y: 440
            text: qsTr("")
            color: "#ffffff"
        }





        Button {
            id: saveButton
            //Layout.columnSpan: 3
            //anchors.centerIn: parent
            // Anchored to 20px off the top right corner of the parent
            //anchors.right: parent.right
            //anchors.bottom: parent.bottom
            //anchors.rightMargin: 20
            //anchors.bottomMargin: 20
            x: 20
            y: 400

            text: qsTranslate("PrefsDialogBase", "Save .csv")
            onClicked: {
                // Save notelist
                var ret = saveNotelist()
                if ( ret[0] == true ) {
                    // Show message
                    messageDialog.icon = StandardIcon.Information
                    messageDialog.title = qsTr("Test")
                    messageDialog.text = qsTr("File saved in " + ret[1])
                } else {
                    messageDialog.icon = StandardIcon.Critical
                    messageDialog.title = qsTr("Test")
                    messageDialog.text = qsTr("Could not save " + ret[1])
                }

                //messageDialog.onAccepted: {
                //}

                messageDialog.visible = true
                //Qt.quit()
            }
        }

        Button {
            id: doneButton
            //Layout.columnSpan: 3
            //anchors.centerIn: parent
            // Anchored to 20px off the top right corner of the parent
            //anchors.right: parent.right
            //anchors.bottom: parent.bottom
            //anchors.rightMargin: 20
            //anchors.bottomMargin: 20
            x: 600
            y: 430

            text: qsTranslate("PrefsDialogBase", "Done")
            onClicked: {
                //pluginId.parent.Window.window.close();
                Qt.quit()
            }
        }
    }
}