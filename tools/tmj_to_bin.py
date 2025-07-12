#!/usr/bin/env python
'''
Convert a Tiled TMJ file (Tiled Map JSON?) to binary data to put in the game.

'''

import argparse

from ConversionLib.Tiled import TiledMap
from ConversionLib.Snes import SnesMap

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('inputFile', metavar='<input.tmj>', type=str, help="Input TMJ file to convert")
    parser.add_argument('outputFile', metavar='<output.asm>', type=str, help="Path to output .asm file")
    args = parser.parse_args()
    tiledMap = TiledMap.fromTmjPath(args.inputFile)
    snesMap = SnesMap.fromTiledMap(tiledMap)
    snesMap.outputToPath(args.outputFile)

if __name__ == '__main__':
    main()
