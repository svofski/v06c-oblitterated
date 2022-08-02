set -e

PASM=prettyasm/main.js
ZX0=tools/zx0.exe

ZX0_ORG=4000


MAIN=oblitterated
ROM=$MAIN-raw.rom
ROMZ=$MAIN.rom
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
      all_my_cycles.png
      used_to_be.png
      blitting.png
      and_i_was_mute.png
      now_i_unpack.png
      14_reg_streams.png
      on_the_fly.png
      i_am_no_longer.png
      oblitterated.png
      an_unlikely.png
      headroom_incident.png
      svo2022.png
      music_by.png
      firestarter1.png
      firestarter2.png
      no_longer_inv1.png
      no_longer_inv2.png
      "

    for f in $files; do
        ./tools/png2db.py assets/$f 
    done
}

if ! test -e messages.inc; then
    maketexts >messages.inc
    echo "messages.inc: `wc -l messages.inc` lines"
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