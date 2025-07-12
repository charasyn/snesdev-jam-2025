#!/usr/bin/env python
# charasyn 2025
# with code from others as noted

import array
import base64
from collections.abc import Sequence
from dataclasses import dataclass
import json
import pathlib
import struct
from typing import Optional

from PIL import Image

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
