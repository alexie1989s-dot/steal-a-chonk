import numpy as np, math
import os
# Project root: CFG["root"] when exec'd from Blender, else derived from this file's location.
try:
    ROOT = CFG.get("root")
except NameError:
    ROOT = None
if not ROOT:
    ROOT = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..")) if "__file__" in globals() else os.getcwd()
from PIL import Image, ImageFilter
W=H=2048
OUT=os.path.join(ROOT, "assets", "chonks", "penguin")
RECT={"wing":(0.00,0.34),"foot":(0.36,0.58),"tail":(0.60,0.70),"crest":(0.72,0.80),"beak":(0.82,1.00)}

def build(dark, belly, lid, name):
    img=np.zeros((H,W,3),np.float32); img[:]=np.array(dark)/255.0
    # ---- body region: v in [0,0.75]
    ys=np.arange(H); xs=np.arange(W)
    v=1.0-(ys+0.5)/H; u=(xs+0.5)/W
    V,U=np.meshgrid(v,u,indexing='ij')
    body=V<=0.75
    el=(V/0.75)*math.pi-math.pi/2          # -pi/2..pi/2
    az=(U-0.5)*2*math.pi                   # -pi..pi, 0 = front
    nx=np.sin(az)*np.cos(el); ny=-np.cos(az)*np.cos(el); nz=np.sin(el)
    # belly: ellipsoidal oval on the front
    a,c,zc=0.88,0.72,-0.36
    f=(nx/a)**2+((nz-zc)/c)**2
    alpha=np.clip((1.0-f)/0.05,0,1)*(ny<0)*body
    # soften boundary a touch
    col_belly=np.array(belly)/255.0
    img=img*(1-alpha[...,None])+col_belly*alpha[...,None]
    # eyes
    ele=math.radians(33.0)
    for sgn in (-1,1):
        aze=math.radians(sgn*16.0)
        dx=np.degrees((az-aze))*math.cos(ele)      # horizontal angular offset (deg)
        dy=np.degrees(el-ele)                      # vertical angular offset (deg)
        rx,ry=10.0,7.0
        eye=((dx/rx)**2+(dy/ry)**2<1)&body
        # lid: covers upper part, lower toward the inner side (grumpy)
        inner=-sgn*dx                              # positive toward center
        lidline=0.6-0.34*inner
        lidmask=eye&(dy>lidline)
        white=eye&~lidmask
        img[white]=np.array([245,245,242])/255.0
        # pupil, looking slightly inward and down
        px_=-sgn*1.6; py_=-1.0
        pupil=(((dx-px_)/3.9)**2+((dy-py_)/3.9)**2<1)&white
        img[pupil]=np.array([28,26,28])/255.0
        hl=(((dx-px_-1.3)/1.1)**2+((dy-py_-1.4)/1.1)**2<1)&white
        img[hl]=np.array([255,255,255])/255.0
        img[lidmask]=np.array(lid)/255.0
        # thin dark line under the lid edge for definition
        edge=eye&(np.abs(dy-lidline)<0.45)
        img[edge]=np.array([22,22,26])/255.0
    # ---- accessory strip
    def fill(key,col):
        u0,u1=RECT[key]; x0,x1=int(u0*W),int(u1*W); y0=0; y1=int((1-0.78)*H)
        img[y0:y1,x0:x1]=np.array(col)/255.0
    fill("wing",dark); fill("tail",dark); fill("crest",dark)
    fill("foot",[26,26,30]); fill("beak",[236,142,38])
    # ---- fuzz: subtle multiplicative noise, blurred
    rng=np.random.default_rng(7)
    noise=rng.normal(0,1,(H,W)).astype(np.float32)
    nimg=Image.fromarray(np.clip(noise*40+128,0,255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(1.2))
    n=(np.asarray(nimg).astype(np.float32)-128)/128.0
    img=np.clip(img*(1+0.045*n[...,None]),0,1)
    Image.fromarray((img*255).astype(np.uint8)).save(f"{OUT}\{name}.png")
    print("saved",name)

build(dark=[30,32,37], belly=[232,222,206], lid=[58,62,70], name="penguin_black")
build(dark=[118,146,184], belly=[238,240,242], lid=[140,164,196], name="penguin_blue")
