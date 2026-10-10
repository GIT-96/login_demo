from pathlib import Path
from math import sqrt
import struct
import zlib

manifest=Path('android/app/src/main/AndroidManifest.xml')
text=manifest.read_text()
text=text.replace('android:label="git_credit_tracker"', 'android:label="GIT Credit Tracker"')
text=text.replace('<application', '<application android:allowBackup="false"', 1)
manifest.write_text(text)

# Generate all launcher mipmaps with the Python standard library (no image dependency).
# White G + cyan wallet stripe, on GIT deep-blue rounded-square background.
def png_image(size):
    rows=[]
    bitmap=[
      "0111110",
      "1100011",
      "1100000",
      "1100000",
      "1101111",
      "1100011",
      "1100011",
      "1100011",
      "0111110",
    ]
    for y in range(size):
        pixels=bytearray()
        for x in range(size):
            px=x/size;py=y/size
            rad=.22
            cx=max(rad,min(1-rad,px)); cy=max(rad,min(1-rad,py))
            outside=((px-cx)**2+(py-cy)**2)>rad**2
            blue=(10,35,78,0) if outside else (12,86,188,255)
            col=blue
            # top-edge cyan highlight
            if not outside and py<.18: col=(13,105,213,255)
            # bold white G with soft dark-blue shadow margin
            gx=(px-.205)/.59*7;gy=(py-.17)/.58*9
            if 0<=gx<7 and 0<=gy<9 and bitmap[int(gy)][int(gx)]=="1":
                col=(255,255,255,255)
            # cyan bottom underline representing financial progress
            if not outside and .82<py<.87 and .25<px<.75:
                col=(73,226,242,255)
            pixels.extend(col)
        rows.append(b'\\x00'+pixels)
    raw=b''.join(rows)
    def chunk(k,v):return struct.pack('>I',len(v))+k+v+struct.pack('>I',zlib.crc32(k+v)&0xffffffff)
    return b'\\x89PNG\\r\\n\\x1a\\n'+chunk(b'IHDR',struct.pack('>2I5B',size,size,8,6,0,0,0))+chunk(b'IDAT',zlib.compress(raw,9))+chunk(b'IEND',b'')

res=Path('android/app/src/main/res')
for density,dim in [('mdpi',48),('hdpi',72),('xhdpi',96),('xxhdpi',144),('xxxhdpi',192)]:
    dst=res/('mipmap-'+density)
    dst.mkdir(parents=True,exist_ok=True)
    (dst/'ic_launcher.png').write_bytes(png_image(dim))
print('Generated GIT launcher logo for 5 Android densities')
