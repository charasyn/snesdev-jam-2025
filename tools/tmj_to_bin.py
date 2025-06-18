#!/usr/bin/env python
'''
Convert a Tiled TMJ file (Tiled Map JSON?) to binary data to put in the game.

'''

import argparse
import array
import base64
from collections.abc import Sequence
from dataclasses import dataclass
import json
import pathlib
import re
import struct
from typing import Iterator, Optional

from PIL import Image, ImageOps

import image_cropper
import palettepacker

def boolxor(a: bool, b: bool) -> bool:
    return (not b) if a else (not not b)

def snesTilemapEntry(character: int, palette: int, priority: bool = False,
                     flipH: bool = False, flipV: bool = False) -> int:
    assert 0 <= character < 1024
    assert 0 <= palette < 8
    nPriority = (0b0010_0000_0000_0000 if priority else 0)
    nFlipH = (0b0100_0000_0000_0000 if flipH else 0)
    nFlipV = (0b1000_0000_0000_0000 if flipV else 0)
    return (character | (palette << 10) | nPriority | nFlipH | nFlipV)

@dataclass
class TiledTile:
    id: int
    collision: int
    image: Image.Image

@dataclass
class TiledTileset:
    tileWidth: int
    tileHeight: int
    tiles: dict[int, TiledTile]

    @classmethod
    def fromTsjPath(cls, path: str) -> 'TiledTileset':
        tsjDir = pathlib.Path(path).parent
        with open(path) as fTsj:
            tsjJson = json.load(fTsj)
        tileWidth=tsjJson['tilewidth']
        tileHeight=tsjJson['tileheight']
        assert tsjJson['margin'] == 0
        assert tsjJson['spacing'] == 0
        tiles = {}
        imageWidth, imageHeight, columns = [tsjJson[x] for x in ('imagewidth','imageheight','columns')]
        with Image.open(tsjDir / tsjJson['image']) as img:
            imageWidth = min(imageWidth, img.width)
            imageHeight = min(imageHeight, img.height)
            for i in range(tsjJson['tilecount']):
                tx = i % columns
                ty = i // columns
                px = tx * tileWidth
                py = ty * tileHeight
                if px >= imageWidth or py >= imageHeight:
                    continue
                tileImage = img.crop((px, py, px+tileWidth, py+tileHeight))
                tiles[i] = TiledTile(i, 0, tileImage)
        return cls(
            tileWidth=tileWidth,
            tileHeight=tileHeight,
            tiles=tiles
        )

@dataclass
class TiledMap:
    width: int
    height: int
    tilesets: list[tuple[int, TiledTileset]]
    data: Sequence[int]

    @classmethod
    def fromTmjPath(cls, path: str) -> 'TiledMap':
        tmjDir = pathlib.Path(path).parent
        with open(path) as fTmj:
            tmjJson = json.load(fTmj)
        assert tmjJson['type'] == 'map'
        assert tmjJson['orientation'] == 'orthogonal'
        assert tmjJson['renderorder'] == 'right-down'
        assert tmjJson['tileheight'] == 8
        assert tmjJson['tilewidth'] == 8
        assert tmjJson['infinite'] == False
        assert tmjJson['compressionlevel'] == -1
        height, width = tmjJson['height'], tmjJson['width']
        mapLayer: Optional[dict] = None
        objLayer: Optional[dict] = None
        for layer in tmjJson['layers']:
            layerType = layer['type']
            if layerType == 'tilelayer':
                assert mapLayer is None, 'Multiple tile layers'
                mapLayer = layer
            elif layerType == 'objectgroup':
                assert objLayer is None, 'Multiple object layers'
                objLayer = layer
            else:
                assert False, 'Unknown layer type'
        assert mapLayer
        assert objLayer
        tilesets = []
        for tileset in tmjJson['tilesets']:
            tilesetPath: str = tileset['source']
            tilesetPath = tilesetPath.replace('.tsx','.tsj')
            tilesets.append((tileset['firstgid'], TiledTileset.fromTsjPath(str(tmjDir / tilesetPath))))
        tilesets.sort()
        mapTileBytes = base64.b64decode(mapLayer['data'], validate=True)
        (mapTileData := array.array('L')).extend(struct.unpack(f'<{width*height}L', mapTileBytes))
        return cls(
            width=width,
            height=height,
            tilesets=tilesets,
            data=mapTileData
        )


# Code borrowed from https://github.com/charasyn/eb-png2fts/blob/main/eb_png2fts.py
# Thanks Catador!
class SnesPalette:
    """Represents a color palette of 96 colors (6 subpalettes of 15 colors)"""

    def __init__(self, backdrop=(0, 248, 0), numRows=6):
        self.backdrop = backdrop
        self.numRows = numRows
        self.subpalettes = [[] for _ in range(self.numRows)]

    def to_image(self):
        """Returns an image representation of the palette"""
        im = Image.new('RGB', (16, self.numRows), self.backdrop)
        for y, colors in enumerate(self.subpalettes):
            for x in range(15):
                try:
                    value = colors[x]
                    im.putpixel((x+1, y), value)
                except IndexError:
                    pass

        # Now resize it to 8x size
        im = im.resize((16*8, self.numRows*8), resample=Image.Resampling.NEAREST)
        return im

    @classmethod
    def from_image(cls, image: Image.Image, numRows: Optional[int]=None) -> 'SnesPalette':
        if not numRows:
            numRows = image.height // 8
        assert image.width == 16 * 8
        assert image.height == numRows * 8
        ret = cls(numRows=numRows)
        for ty in range(numRows):
            py = ty * 8
            for tx in range(1, 16):
                px = tx * 8
                tileImage = image.crop((px, py, px+8, py+8))
                color = tileImage.getcolors(1)
                assert color, f"Palette image had too many colours at row {ty}, column {tx}"
                ret.subpalettes[ty].append(color)
        return ret

    def to_bytes(self) -> bytes:
        def _c(r,g,b) -> int:
            return (r//8) | ((g//8)<<5) | ((b//8)<<10)
        def _p(pal: list[tuple[int,int,int]]) -> list[int]:
            ret = [_c(*self.backdrop)]
            for colour in pal:
                ret.append(_c(*colour))
            for _ in range(len(ret), 16):
                ret.append(_c(*self.backdrop))
            return ret
        return b''.join(b''.join(x.to_bytes(2, 'little') for x in _p(pal)) for pal in self.subpalettes)

class SnesTile:
    """Represents an 8x8 tile"""

    def __init__(self, data, palette, palette_row, index=0, is_flipped_h=False, is_flipped_v=False):
        self.data = data
        self.palette = palette
        self.palette_row = palette_row
        self.index = index
        self.is_flipped_h = is_flipped_h
        self.is_flipped_v = is_flipped_v

    def __eq__(self, other):
        return (isinstance(other, type(self)) and
                (self.data, self.palette, self.palette_row, self.index, self.is_flipped_h, self.is_flipped_v) ==
                (other.data, other.palette, other.palette_row, self.index, self.is_flipped_h, self.is_flipped_v))

    def __hash__(self):
        return hash((self.data, self.palette, self.palette_row, self.index, self.is_flipped_h, self.is_flipped_v))

    @property
    def is_flipped(self):
        """Returns True if the tile is flipped either horizontally or vertically"""
        return self.is_flipped_h or self.is_flipped_v

    @property
    def is_flipped_hv(self):
        """Returns True if the tile is flipped both horizontally and vertically"""
        return self.is_flipped_h and self.is_flipped_v

    def to_image(self):
        """Returns an image representation of the tile"""
        image = Image.new('RGB', (8, 8))
        colors = self.palette[self.palette_row]
        for y, row in enumerate(self.data):
            for x, pixel in enumerate(row):
                image.putpixel((x, y), colors[pixel])

        return image

    def to_bytes(self) -> bytes:
        ret = []
        for bitshift in (0, 2):
            for y in range(8):
                accum0 = 0
                accum1 = 0
                for x in range(8):
                    i = x + y * 8
                    pixel = self.data[i] >> bitshift
                    accum0 = (accum0 << 1) | (1 if (pixel & 1) else 0)
                    accum1 = (accum1 << 1) | (1 if (pixel & 2) else 0)
                ret.append(accum0)
                ret.append(accum1)
        return bytes(ret)


class SnesChunk:
    """Represents a 32x32 chunk of 16 tiles with surface flag data"""

    def __init__(self, tiles: Sequence[SnesTile], surface_flags: Sequence[int], chunk_width=1, chunk_height=1):
        self.tiles = tuple(tiles)
        assert self.tiles
        self.surface_flags = tuple(surface_flags)
        assert len(self.tiles) == len(self.surface_flags)
        self.chunk_width = chunk_width
        self.chunk_height = chunk_height
        self.chunk_tile_count = chunk_width * chunk_height
        assert self.chunk_tile_count > 0
        assert len(self.tiles) == self.chunk_tile_count

    def _key(self):
        return (self.tiles, self.surface_flags)

    def __eq__(self, other):
        return (isinstance(other, type(self)) and self._key() == other._key())

    def __hash__(self):
        return hash(self._key())

    def to_image(self):
        """Returns an image representation of the chunk"""
        image = Image.new('RGB', (8 * self.chunk_width, 8 * self.chunk_height))

        tx = 0
        ty = 0
        for tile in self.tiles:
            im_tile = tile.to_image()
            image.paste(im_tile, (tx * 8, ty * 8))
            tx += 1
            if tx >= self.chunk_width:
                tx = 0
                ty += 1

        return image

class SnesTileset:
    def __init__(self):
        # Data set prior to calling compute()
        self.chunk_tile_images: dict[int, list[Image.Image]] = {}
        self.tile_palettes = []
        self.tile_gids = []

        # Data set by compute()
        self.tile_index = 0 # Index for next unique tile
        self.chunks = []
        self.tiles: list[SnesTile] = []
        self.palette = SnesPalette()
        self.tile_dict = dict()
        self._chunk_image_cache = set()

        self.gid_to_chunk: dict[int, SnesChunk] = {}

    # def append_from_image(self, image):
    #     """Adds unique chunks and tiles from an image into the tileset"""
    #     # TODO: decide how big to make "chunks"
    #     chunk_images = image_cropper.get_tiles(image, tile_size=8)

    #     for im_chunk in chunk_images:
    #         if im_chunk.tobytes() in self._chunk_image_cache:
    #             continue

    #         self._chunk_image_cache.add(im_chunk.tobytes())

    #         tile_images = image_cropper.get_tiles(im_chunk, tile_size=8)
    #         self.chunk_tile_images.append(tile_images)
    #         for im_tile in tile_images:
    #             colors = im_tile.getcolors(15) # (count, (r,g,b))
    #             if colors is None:
    #                 raise ValueError('A single tile had more than 15 colors.')

    #             colors = [rgb for _, rgb in colors] # Discard pixel count
    #             self.tile_palettes.append(colors)

    def append_from_tiled_tileset(self, firstgid: int, tileset: TiledTileset):
        for tile in tileset.tiles.values():
            image = tile.image.convert(mode='RGB') # Get rid of the alpha channel
            image = ImageOps.posterize(image, 5) # 5-bit color
            gid = firstgid + tile.id
            assert gid not in self.chunk_tile_images
            self.chunk_tile_images[gid] = [image]
            colors = image.getcolors(15) # (count, (r,g,b))
            if colors is None:
                raise ValueError('A single tile had more than 15 colors.')

            colors = [rgb for _, rgb in colors] # Discard pixel count
            self.tile_palettes.append(colors)
            self.tile_gids.append(gid)

    def compute(self):
        # Use palettepacker library to perform better packing of
        # palettes into subpalettes
        packedSubpalettes, subpalette_map = \
            palettepacker.tilePalettesToSubpalettes(self.tile_palettes)
        assert(len(packedSubpalettes) <= 6)
        # Keep the length of subpalettes the same
        self.palette.subpalettes[:len(packedSubpalettes)] = packedSubpalettes
        gid_to_subpalette = {}
        for idx, subpalette_value in subpalette_map.items():
            assert subpalette_value < len(packedSubpalettes)
            gid_to_subpalette[self.tile_gids[idx]] = subpalette_value

        # Add blank tile as tile zero
        tile = SnesTile([0 for _ in range(64)], self.palette, 0, index=0)
        self.tile_index = 1
        self.tile_dict[bytes(0 for _ in range(64*3))] = tile
        self.tiles.append(tile)

        for chunk_gid, tile_images in self.chunk_tile_images.items():
            chunk_tiles = []
            for tile_idx, im_tile in enumerate(tile_images):
                tile_hash = im_tile.tobytes()
                if tile_hash not in self.tile_dict:
                    # Compute all rotations of the tile
                    im_tile_h = im_tile.transpose(Image.Transpose.FLIP_LEFT_RIGHT)
                    im_tile_v = im_tile.transpose(Image.Transpose.FLIP_TOP_BOTTOM)
                    im_tile_hv = im_tile_h.transpose(Image.Transpose.FLIP_TOP_BOTTOM)
                    tile_h_hash = im_tile_h.tobytes()
                    tile_v_hash = im_tile_v.tobytes()
                    tile_hv_hash = im_tile_hv.tobytes()
                    palette_row = gid_to_subpalette[chunk_gid]
                    subpalette = self.palette.subpalettes[palette_row]
                    image_data = im_tile.getdata()
                    tile_data = tuple(subpalette.index(c)+1 for c in image_data)

                    tile = SnesTile(tile_data, self.palette, palette_row, index=self.tile_index)
                    tile_h = SnesTile(tile_data, self.palette, palette_row, index=self.tile_index, is_flipped_h=True)
                    tile_v = SnesTile(tile_data, self.palette, palette_row, index=self.tile_index, is_flipped_v=True)
                    tile_hv = SnesTile(tile_data, self.palette, palette_row, index=self.tile_index, is_flipped_h=True, is_flipped_v=True)
                    self.tile_index += 1

                    # Reorder so that the non-flipped entries are inserted last
                    # so we prefer tiles without their flip-bit set.
                    self.tile_dict[tile_hv_hash] = tile_hv
                    self.tile_dict[tile_v_hash] = tile_v
                    self.tile_dict[tile_h_hash] = tile_h
                    self.tile_dict[tile_hash] = tile
                else:
                    tile = self.tile_dict[tile_hash]

                if tile not in self.tiles:
                    self.tiles.append(tile)

                chunk_tiles.append(tile)

            chunk = SnesChunk(chunk_tiles, [0x00] * 1) # Default surface flags to zeros for now...
            if chunk not in self.chunks:
                self.chunks.append(chunk)
            self.gid_to_chunk[chunk_gid] = chunk

    def tilemap_entry_to_snes(self, tile_gid: int) -> int:
        if tile_gid == 0:
            return snesTilemapEntry(character=0, palette=2)
        else:
            flipH = bool(tile_gid & 0x8000_0000)
            flipV = bool(tile_gid & 0x4000_0000)
            assert (tile_gid & 0x3000_0000) == 0, "Tile diagonal and 120-degree flips forbidden"
            tile_gid &= 0x0fff_ffff
            tile = self.gid_to_chunk[tile_gid].tiles[0]
            flipH = boolxor(flipH, tile.is_flipped_h)
            flipV = boolxor(flipV, tile.is_flipped_v)
            return snesTilemapEntry(character=tile.index, palette=2 + tile.palette_row, flipH=flipH, flipV=flipV)

    def tile_data_to_snes_binary(self) -> bytes:
        allTiles = []
        for tile in self.tiles:
            b = tile.to_bytes()
            assert len(b) == 32
            allTiles.append(b)
        return b''.join(allTiles)

@dataclass
class SnesMap:
    width: int
    height: int
    tileset: SnesTileset
    data: list[int]
    @classmethod
    def fromTiledMap(cls, tmap: TiledMap) -> 'SnesMap':
        snesTileset = SnesTileset()
        for tgid, tset in tmap.tilesets:
            snesTileset.append_from_tiled_tileset(tgid, tset)
        snesTileset.compute()
        snesData = []
        for t in tmap.data:
            snesData.append(snesTileset.tilemap_entry_to_snes(t))
        return cls(tmap.width, tmap.height, snesTileset, snesData)

    def outputToPath(self, path: str):
        tileBinPath = path.replace('.asm', '.tiles.bin')
        mapBinPath = path.replace('.asm', '.map.bin')
        palettePath = path.replace('.asm', '.pal')
        with open(tileBinPath, 'wb') as f:
            f.write(self.tileset.tile_data_to_snes_binary())
        with open(mapBinPath, 'wb') as f:
            f.write(self.mapDataToSnesBinary())
        with open(palettePath, 'wb') as f:
            f.write(self.tileset.palette.to_bytes())
        self.writeAsmFile(path, tileBinPath, mapBinPath, palettePath)

    def mapDataToSnesBinary(self) -> bytes:
        return b''.join(x.to_bytes(2, 'little') for x in self.data)

    def writeAsmFile(self, path: str, tileBinPath: str, mapBinPath: str, palettePath: str):
        symname=path.rsplit('/')[-1].replace('.asm','')
        lines=[
            '; Autogenerated by tmj_to_bin',
            '.segment "BANK01"',
            f'{symname}_tiles: .incbin "{symname}.tiles.bin"',
            f'{symname}_map: .incbin "{symname}.map.bin"',
            f'{symname}_palette: .incbin "{symname}.pal"',
            '; End of generated content'
        ]
        with open(path, 'w') as f:
            f.write('\n'.join(lines))


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
