from pathlib import Path
import struct, zlib

p=Path('android/app/src/main/AndroidManifest.xml')
p.write_text(p.read_text().replace('android:label="git_credit_tracker"','android:label="GIT Credit Tracker"'))

glyph=['0111110','1100011','1100000','1100000','1101111','1100011','1100011','1100011','0111110']
def icon(n):
    raw=bytearray()
    for y in range(n):
        raw.append(0)
        for x in range(n):
            a=x/n; b=y/n
            cx=max(.20,min(.80,a))
            cy=max(.20,min(.80,b))
            inside=(a-cx)**2+(b-cy)**2<=.04
            color=(15,91,198,255) if inside else (0,0,0,0)
            gx=int((a-.22)*7/.56)
            gy=int((b-.17)*9/.60)
            if inside and 0<=gx<7 and 0<=gy<9 and glyph[gy][gx]=='1':
                color=(255,255,255,255)
            if inside and .84<b<.88 and .24<a<.76:
                color=(67,235,243,255)
            raw.extend(color)
    def chunk(tag,data):
        return struct.pack('>I',len(data))+tag+data+struct.pack('>I',zlib.crc32(tag+data)&0xffffffff)
    return bytes([137,80,78,71,13,10,26,10])+chunk(b'IHDR',struct.pack('>IIBBBBB',n,n,8,6,0,0,0))+chunk(b'IDAT',zlib.compress(bytes(raw),9))+chunk(b'IEND',b'')
for dpi,n in [('mdpi',48),('hdpi',72),('xhdpi',96),('xxhdpi',144),('xxxhdpi',192)]:
    path=Path('android/app/src/main/res')/('mipmap-'+dpi)/'ic_launcher.png'
    path.parent.mkdir(parents=True,exist_ok=True)
    path.write_bytes(icon(n))
print('Generated Android GIT launcher icons')
