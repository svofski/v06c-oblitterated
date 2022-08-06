set -e

PASM=prettyasm/main.js
BIN2WAV=../bin2wav/bin2wav.js
ZX0=tools/zx0.exe

ZX0_ORG=4000


MAIN=oblitterated
ROM=$MAIN-raw.rom
ROMZ=$MAIN.rom
WAV=$MAIN.wav
ROM_ZX0=$MAIN.zx0
DZX0_BIN=dzx0-fwd.$ZX0_ORG
RELOC=reloc-zx0
RELOC_BIN=$RELOC.0100

rm -f $ROM_ZX0 $ROM


maketexts()
{
    # prepare text pictures
    #!/bin/bash
    files="
      tape_error1.png
      tape_error2.png
      hello1.png
      hello2.png
      what_a_strange_place.png
      i_have_to_blit_myself.png
      as_fast_as_i_can.png
      just_to_stay_where_i_am.png
      i_am_fully.png
      oblitterated.png
      an_unlikely_max_headroom_incident.png
      svo2022.png
      music_by_firestarter_a.png
      music_by_firestarter_b.png
      no_longer_inv1.png
      no_longer_inv2.png
      null.png


      gr_else.png
      gr_errorsoft.png
      gr_frog.png
      gr_ivagor.png
      gr_kansoft.png
      gr_lafromm.png
      gr_metamorpho.png
      gr_nzeemin.png
      gr_orgaz.png
      gr_tnt23.png
      gr_manwe.png

      "

    for f in $files; do
        ./tools/png2db.py assets/$f 
    done
}

if ! test -e messages.inc; then
    maketexts >messages.inc
    echo "messages.inc: `wc -l messages.inc` lines"
fi

if ! test -e cafe.inc; then
    tools/png2db-arzak.py assets/cafeparty-color.png -lineskip 1 -nplanes 2 -lut 0,3,2,1 -leftofs 14 -labels cafe_e0,cafe_c0 >cafe.inc
    tools/png2db-arzak.py assets/cafeparty_bw.png -lineskip 1 -nplanes 2 -lut 0,3,2,1 -leftofs 14 -labels cafe_bw >>cafe.inc

fi

if ! test -e firestarter_2006_027.inc ; then
  ./ym6break.py music/firestarter_2006_027.ym songA_
fi

if ! test -e firestarter_3elehaq.inc ; then
    ./ym6break.py music/firestarter_3elehaq.ym songB_
fi

$PASM $MAIN.asm -o $ROM
ROM_SZ=`cat $ROM | wc -c`
echo "$ROM: $ROM_SZ octets"

$ZX0 -c $ROM $ROM_ZX0
ROM_ZX0_SZ=`cat $ROM_ZX0 | wc -c`
echo "$ROM_ZX0: $ROM_ZX0_SZ octets"

$PASM -Ddzx0_org=0x$ZX0_ORG dzx0-fwd.asm -o $DZX0_BIN
DZX0_SZ=`cat $DZX0_BIN | wc -c`
echo "$DZX0_BIN: $DZX0_SZ octets"

$PASM -Ddst=0x$ZX0_ORG -Ddzx_sz=$DZX0_SZ -Ddata_sz=$ROM_ZX0_SZ $RELOC.asm -o $RELOC_BIN
RELOC_SZ=`cat $RELOC_BIN | wc -c`
echo "$RELOC_BIN: $RELOC_SZ octets"

cat $RELOC_BIN $DZX0_BIN $ROM_ZX0 > $ROMZ

$BIN2WAV -m v06c-turbo $ROMZ $WAV
