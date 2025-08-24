#!/usr/bin/python3
import math
from functools import cached_property

ANGLE_SIZE = 4096

def degToAngle(deg: float) -> int:
    return int(deg / 360 * ANGLE_SIZE)

class ExpLogTable:
    LOG_ENTRY_BITS = (4, 12)
    LOG_TABLE_SIZE = 2 ** 12
    EXP_TABLE_SIZE = 4096

    @cached_property
    def logTable(self):
        TS = self.LOG_TABLE_SIZE
        ENTRY_MULT = 2 ** self.LOG_ENTRY_BITS[1]
        return [int(round(math.log(x or 1, 2) * (ENTRY_MULT))) for x in range(TS)]

    @cached_property
    def expTable(self):
        TS = self.EXP_TABLE_SIZE
        return [int(round((2 ** (x / TS) - 1) * 65536)) for x in range(TS)]

    def fastLog2(self, x: int) -> int:
        y = x
        expAdd = 0
        EXP_MULT = 2 ** self.LOG_ENTRY_BITS[1]
        while y >= self.LOG_TABLE_SIZE:
            y >>= 1
            expAdd += EXP_MULT
        result = self.logTable[y] + expAdd
        print(f'{x=} {y=} {expAdd=:04x} {result=:04x}')
        return result

    def fastExpBase2(self, x: int) -> int:
        frac = self.expTable[x & 0xfff]
        mult = x >> 12
        result = (1 << mult) + (frac >> (16 - mult))
        print(f'{x=:04x} {frac=} {mult=} {result=}')
        return result

def testExpLog():
    elt = ExpLogTable()
    assert 1000 == elt.fastExpBase2(elt.fastLog2(10000) - elt.fastLog2(10))

class AtanTable:
    ATAN_TABLE_SIZE = ANGLE_SIZE // 8
    assert ATAN_TABLE_SIZE * 8 == ANGLE_SIZE

    @cached_property
    def logTable(self):
        TS = self.ATAN_TABLE_SIZE
        return [int(math.log(x or 1, TS) * TS) for x in range(TS)]

    @cached_property
    def atanTable(self):
        TS = self.ATAN_TABLE_SIZE
        def _entry(x):
            atanParam = TS ** (x / TS - 1)
            return int(math.atan(atanParam) * 2 / math.pi * TS * 2)
        return [_entry(x) for x in range(TS)]

    def fastAtan2(self, dx: int, dy: int) -> int:
        TS = self.ATAN_TABLE_SIZE

        xinv = dx < 0
        if xinv:
            dx = -dx
        yinv = dy < 0
        if yinv:
            dy = -dy

        while (dx | dy) >= TS:
            dx >>= 1
            dy >>= 1
        logx = self.logTable[dx]
        logy = self.logTable[dy]
        dlog = logy - logx
        angleReflect = dlog < 0
        if angleReflect:
            dlog = -dlog
        atan = self.atanTable[dlog]
        # print(f'{dx=} {dy=} {logx=} {logy=} {dlog=} {atan=}')
        if angleReflect:
            atan = TS - atan
        else:
            atan = TS + atan
        if not xinv and not yinv:
            return atan
        if xinv and not yinv:
            return TS*4 - atan
        if xinv and yinv:
            return TS*4 + atan
        return TS*8 - atan

def testAtanTable():
    at = AtanTable()
    print(f'{at.logTable=}')
    print(f'{at.atanTable=}')
    assert at.ATAN_TABLE_SIZE == 512
    assert all(0 <= x < at.ATAN_TABLE_SIZE for x in at.logTable)
    assert all(0 <= x < at.ATAN_TABLE_SIZE for x in at.atanTable)
    # Quadrant 1 boundary check
    assert degToAngle(0) <= at.fastAtan2(1000, 1) <= degToAngle(3)
    assert degToAngle(87) <= at.fastAtan2(1, 1000) <= degToAngle(90)
    # Quadrant 2 boundary check
    assert degToAngle(90) <= at.fastAtan2(-1, 1000) <= degToAngle(93)
    assert degToAngle(177) <= at.fastAtan2(-1000, 1) <= degToAngle(180)
    # Quadrant 3 boundary check
    assert degToAngle(180) <= at.fastAtan2(-1000, -1) <= degToAngle(183)
    assert degToAngle(267) <= at.fastAtan2(-1, -1000) <= degToAngle(270)
    # Quadrant 4 boundary check
    assert degToAngle(270) <= at.fastAtan2(1, -1000) <= degToAngle(273)
    assert degToAngle(357) <= at.fastAtan2(1000, -1) <= degToAngle(360)
    # Midpoint checks
    def _mpcheck(center, cx, cy):
        assert degToAngle(center - 3) <= at.fastAtan2(    1 * cx,     1 * cy) <= degToAngle(center + 3)
        assert degToAngle(center - 3) <= at.fastAtan2( 1000 * cx,  1000 * cy) <= degToAngle(center + 3)
        assert degToAngle(center - 3) <= at.fastAtan2(10000 * cx, 10000 * cy) <= degToAngle(center + 3)
    _mpcheck(90 * 0 + 45,  1,  1)
    _mpcheck(90 * 1 + 45, -1,  1)
    _mpcheck(90 * 2 + 45, -1, -1)
    _mpcheck(90 * 3 + 45,  1, -1)

if __name__ == '__main__':
    testExpLog()
