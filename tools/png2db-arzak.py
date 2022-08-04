#!/usr/bin/env python3
import png
import sys
import os
from subprocess import call, Popen, PIPE
from math import *
from operator import itemgetter
from utils import *
from base64 import b64encode
import array

VARCHUNK=2
LEFTOFS=4

# if cell is empty and all cells in this column above it are empty
#       check cell directly below and if it is not empty consider current one not empty as well
#
# if cell is empty and all cells in this column under it are empty
#       check cell directly above and if it is not empty, consider current one not empty as well
#   
# step 1: shrinkwrap
# step 2: profit



def shrinkwrap(plane, ncolumns):
    rows = list(chunker(plane, ncolumns))
    hull = [[1 for x in range(len(rows[0]))] for y in range(len(rows))]

    for x in range(len(rows[0])):
        y1 = 0
        y2 = len(rows) - 1
        top_end = bottom_end = False
        while y1 < y2 and not (top_end and bottom_end):
            if rows[y1][x] == 0 and rows[y1+1][x] == 0 and rows[y1+2][x] == 0:
                hull[y1][x] = 0
                y1 += 1
            else:
                top_end = True
            if rows[y2][x] == 0 and rows[y2-1][x] == 0 and rows[y2-2][x] == 0:
                hull[y2][x] = 0
                y2 -= 1
            else:
                bottom_end = True
    #for h in hull:
    #    print(h)
    return hull



# use precalculated offset instead of number of 2-col chunks
def varformat(plane, ncolumns, hull):
    rows = list(chunker(plane, ncolumns))
    #print(hull)

    for y in range(len(rows)):
        #print(line)
        line = rows[y]
        first = 0
        while first < len(line) and hull[y][first] == 0:
            first = first + 1
        last = len(line) - 1
        while last > first and hull[y][last] == 0:
            last = last - 1
        columns = list(chunker(line[first:last+1], VARCHUNK))
        end = len(columns)

        jump = (16 - end) * 5
        dbline = '.db %d, %d ' % (first + LEFTOFS, jump)
        #dbline = '.db %d, %d ' % (first, end)
        for c in columns[:end]:
            for i in range(VARCHUNK - len(c)):
                c.append(0)
            dbline = dbline + ',' + ','.join(['$%02x' % x for x in c])
        print(dbline)
    print('.db 0, 0 ; end of plane data')


def readPNG(filename):
    reader = None
    pix = None
    w, h = -1, -1
    try:
        if reader == None:        
            reader=png.Reader(filename)
        img = reader.read()
        #print('img=', repr(img))
        pix = list(img[2])
    except:
        print('Could not open image, file exists?')
        return None
    w, h = len(pix[0]), len(pix)
    print ('; Opened image %s %dx%d' % (filename, w, h))            
    return pix

foreground=sys.argv[1]
(origname, ext) = os.path.splitext(foreground)
pic = readPNG(foreground)

ncolumns = len(pic[0])//8

# indexed color, lines of bytes
#print('xbytes=', xbytes, ' nlines=', nlines)

def starprint(pic):
    print('; ', ''.join(['*' if x > 0 else ' ' for x in pic]))


def pixels_to_bitplanes(pic, lineskip):
    #lut = [0, 0, 1, 2, 3]
    #lut = [0, 0, 2, 3, 1]
    lut = [0] * 256 # for grayscale input
    lut[255] = 1    # if grayscale b&w
    lut[1] = 1      # for indexed 1bpp

    planes = [[], [], [], []]
    nlines = len(pic)
    for y in range(0, nlines, lineskip):
        starprint(pic[y])
        for col in chunker(pic[y], 8):
            c1 = sum([(lut[c] & 1) << (7-i) for i, c in enumerate(col)])
            planes[0].append(c1)
            c2 = sum([((lut[c] & 2) >> 1) << (7-i) for i, c in enumerate(col)])
            planes[1].append(c2)
            c3 = sum([((lut[c] & 4) >> 1) << (7-i) for i, c in enumerate(col)])
            planes[1].append(c2)
            c4 = sum([((lut[c] & 8) >> 1) << (7-i) for i, c in enumerate(col)])
            planes[1].append(c2)
    return planes

# a different approach:
# every line:   [offset of first column]
#               [number of 8-column chunks]
#               data

planes = pixels_to_bitplanes(pic, lineskip=2)

hull = None
try:
    # if a second frame is specified, create a common hull for 2 frames
    glitchframe=sys.argv[2]
    pic2 = readPNG(glitchframe)
    print(f'; Using {glitchframe} to calculate common hull')

    glitchplanes = pixels_to_bitplanes(pic2, lineskip=2)

    orplane = [x or y for x, y in zip(planes[0], glitchplanes[0])]
    # for line in chunker(orplane, ncolumns):
    #     starprint(line)

    hull = shrinkwrap(orplane, ncolumns)
except:
    pass

if hull == None:
    # use single hull
    hull = shrinkwrap(planes[0], ncolumns)

varformat(planes[0], ncolumns, hull)
            
