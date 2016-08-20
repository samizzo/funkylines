;----------------------------------------------------------------------------
;
; Funky lines effect
;
;----------------------------------------------------------------------------


;----------------------------------------------------------------------------
; compiler options
;----------------------------------------------------------------------------

        .386
        .model flat, stdcall
        option casemap :none                ; case sensitive

;----------------------------------------------------------------------------


;----------------------------------------------------------------------------
; includes
;----------------------------------------------------------------------------

        include d:\masm32\include\windows.inc
        include d:\masm32\include\user32.inc
        include d:\masm32\include\kernel32.inc
        include d:\masm32\include\gdi32.inc

        include ddraw.inc

        ; ------------------------------------
        ; libs
        ; ------------------------------------
        includelib d:\masm32\lib\gdi32.lib
        includelib d:\masm32\lib\user32.lib
        includelib d:\masm32\lib\kernel32.lib
        includelib d:\masm32\lib\ddraw.lib

;----------------------------------------------------------------------------


;----------------------------------------------------------------------------
; local macros
;----------------------------------------------------------------------------

        return  MACRO   arg
                mov     eax, arg
                ret
        ENDM

        fatal   MACRO   msg
                local @@msg
                .data
                @@msg       db      msg, 0
                .code
                
                invoke  MessageBox, hWnd, ADDR @@msg, ADDR szDispName,
                        MB_OK OR MB_ICONEXCLAMATION
                invoke  ExitProcess, 0
        ENDM

;----------------------------------------------------------------------------


;----------------------------------------------------------------------------


;----------------------------------------------------------------------------
; initialised data
;----------------------------------------------------------------------------

        .DATA

index           DD                  0
redShift        DD                  11

seed            DD                  12345678h

wc              WNDCLASS            <CS_HREDRAW+CS_VREDRAW, offset WndProc, \
                                    0, 0, 0, 0, 0, 0, 0, offset szClassName>
szClassName     DB                  "DDTest", 0
szDispName      DB                  "DirectX test program", 0

; direct draw data
stretch         DB                  FALSE


deg             DW                  256
deg2            DW                  128
cosmul          DW                  60 ;90
sinmul          DW                  70 ;80


;----------------------------------------------------------------------------
; uninitialised data
;----------------------------------------------------------------------------

        .DATA?

hInst           HANDLE              ?
hWnd            HWND                ?

ddsd            DDSURFACEDESC       <?>
ddscaps         DDSCAPS             <?>
ddpf            DDPIXELFORMAT       <?>
lpDD            LPDIRECTDRAW        ?
lpDDSp          LPDIRECTDRAWSURFACE ?           ; primary surface
lpDDSb          LPDIRECTDRAWSURFACE ?           ; attached back buffer

msg             MSG                 <?>

temp1           DW                  ?
temp2           DW                  ?

; lines data
arctan          DB                  640*401 dup (?)
cos             SDWORD              256 dup (?)
sin             SDWORD              256 dup (?)
pal             DW                  256 dup (?)

yoffstab        DD                  400 dup (?)
;----------------------------------------------------------------------------


;----------------------------------------------------------------------------
; equates
;----------------------------------------------------------------------------

FALSE           EQU         0
TRUE            EQU         1

;----------------------------------------------------------------------------


;----------------------------------------------------------------------------
; begin main code
;----------------------------------------------------------------------------

        .CODE

start:
        invoke  GetModuleHandle, NULL
        mov     hInst, eax

;;; register and create window
        mov     wc.hInstance, eax
        invoke  GetStockObject, BLACK_BRUSH
        mov     wc.hbrBackground, eax
        invoke  RegisterClassA, ADDR wc

        invoke  CreateWindowExA, WS_EX_TOPMOST, ADDR szClassName,
                ADDR szDispName, WS_POPUP, 0, 0, 320, 200, 0, 0, hInst, 0
        cmp     eax, 0
        je      done
        mov     hWnd, eax

        invoke  ShowWindow, hWnd, SW_SHOWNORMAL
        invoke  UpdateWindow, hWnd
        invoke  ShowCursor, 0

;;; set up direct draw surfaces

        ; create direct draw object
        invoke  DirectDrawCreate, NULL, ADDR lpDD, NULL
        .if eax != DD_OK
            fatal "Couldn't initialise DirectDraw"
        .endif

        ; set exclusive and fullscreen cooperative level
        DDINVOKE SetCooperativeLevel, lpDD, hWnd, DDSCL_EXCLUSIVE OR DDSCL_FULLSCREEN
        .if eax != DD_OK
            fatal "Couldn't set cooperative level"
        .endif

        ; set new video mode
        DDINVOKE SetDisplayMode, lpDD, 320, 200, 16
        .if eax == DDERR_INVALIDMODE
            DDINVOKE SetDisplayMode, lpDD, 640, 480, 16
            .if eax != DD_OK
                fatal "Couldn't set display mode (tried 320x200x16bpp and 640x480x16bpp)"
            .endif
            mov stretch, TRUE
        .elseif eax != DD_OK
            fatal "Couldn't set display mode"
        .endif

        ; create primary surface with one backbuffer
        mov     ddsd.dwFlags, DDSD_CAPS OR DDSD_BACKBUFFERCOUNT
        mov     ddsd.ddsCaps.dwCaps, DDSCAPS_PRIMARYSURFACE OR DDSCAPS_FLIP OR \
                                     DDSCAPS_COMPLEX OR DDSCAPS_VIDEOMEMORY
        mov     ddsd.dwBackBufferCount, 1
        mov     ddsd.dwSize, SIZEOF DDSURFACEDESC
        DDINVOKE CreateSurface, lpDD, ADDR ddsd, ADDR lpDDSp, NULL
        .if eax != DD_OK
            fatal "Couldn't create primary surface"
        .endif

        ; get attached surface (back buffer)
        mov     ddscaps.dwCaps, DDSCAPS_BACKBUFFER
        DDSINVOKE GetAttachedSurface, lpDDSp, ADDR ddscaps, ADDR lpDDSb
        .if eax != DD_OK
            fatal "Couldn't get attached surface"
        .endif

        ; get pixel format
        mov     ddpf.dwSize, SIZEOF DDPIXELFORMAT
        DDSINVOKE GetPixelFormat, lpDDSp, ADDR ddpf
        .if eax != DD_OK
            fatal "Couldn't get pixel format"
        .endif

        .if ddpf.dwGBitMask != 7e0h
            mov redShift, 10
        .endif

        call    initTables

;;; message loop (main body of code)

mainloop:
        invoke  PeekMessageA, ADDR msg, 0, 0, 0, PM_REMOVE
        cmp     eax, 0
        je      nomsg
        cmp     msg.message, WM_QUIT
        je      done
        cmp     msg.message, WM_CLOSE
        je      done

        invoke  TranslateMessage, ADDR msg
        invoke  DispatchMessage, ADDR msg
    nomsg:


;;; main demo code

        ; lock surface
        mov     ddsd.dwSize, SIZEOF DDSURFACEDESC
        DDSINVOKE mLock, lpDDSb, NULL, ADDR ddsd, DDLOCK_WAIT, NULL

        mov     edi, ddsd.lpSurface

        ; edi = surface pointer

;        .if stretch == TRUE
;        .else
            push    ebp

            mov     ebx, index
            mov     eax, dword ptr sin[ebx*4]
            mov     ebx, dword ptr cos[ebx*4]
            mov     ebp, 320d
            mov     ecx, 100d
            mov     esi, offset arctan

            ; eax = sin(index)
            ; ebx = cos(index)
            ; ebp = i, ecx = j

        lineloop:
            mov     esi, ecx
            add     esi, eax
            mov     esi, dword ptr yoffstab[esi*4]
            add     esi, ebp
            add     esi, ebx
            add     esi, 210d ;160d
            mov     dl, byte ptr arctan[esi]
            shl     dl, 1

            mov     esi, ecx
            add     esi, eax
            mov     esi, dword ptr yoffstab[esi*4]
            add     esi, ebp
            add     esi, eax
            add     esi, 190d ;160-40d
            sub     dl, byte ptr arctan[esi]

            mov     esi, ecx
            add     esi, ebx
            mov     esi, dword ptr yoffstab[esi*4]
            add     esi, ebp
            add     esi, eax
            add     esi, 110d ;160d
            add     dl, byte ptr arctan[esi]
            add     dl, byte ptr arctan[esi]

            mov     esi, ecx
            add     esi, ebx
            mov     esi, dword ptr yoffstab[esi*4]
            add     esi, ebp
            sub     esi, ebx
            add     esi, 160d; 160+30d
            add     dl, byte ptr arctan[esi]
            add     dl, byte ptr arctan[esi]

            mov     esi, ecx
            add     esi, ebx
            mov     esi, dword ptr yoffstab[esi*4]
            add     esi, ebp
            add     esi, eax
            add     esi, 160+30+10d
            sub     dl, byte ptr arctan[esi]

            mov     esi, ecx
            sub     esi, eax
            mov     esi, dword ptr yoffstab[esi*4]
            add     esi, ebp
            add     esi, eax
            add     esi, 140d
            add     dl, byte ptr arctan[esi]

            ;mov     esi, ecx
            ;sub     esi, eax
            ;mov     esi, dword ptr yoffstab[esi*4]
            ;add     esi, ebp
            ;add     esi, eax
            ;add     esi, 170d
            ;add     dl, byte ptr arctan[esi]

            add     dl, bl
            and     edx, 0ffh

            mov     dx, word ptr pal[edx*2]
            mov     [edi], dx

            add     edi, 2

            dec     ebp
            jnz     lineloop

            mov     ebp, 320d

            inc     ecx
            cmp     ecx, 300d
            jne     lineloop

            pop     ebp
;        .endif
;
;here:
        inc     byte ptr index

        ; unlock surface
        DDSINVOKE Unlock, lpDDSb, NULL

        ; flip surfaces
        DDSINVOKE Flip, lpDDSp, NULL, DDFLIP_WAIT

        jmp     mainloop

done:
        invoke  ShowCursor, 1
        invoke  ExitProcess, 0

; end of main code

;----------------------------------------------------------------------------
; procedures
;----------------------------------------------------------------------------

initTables PROC
;;; init tables
        mov     edi, offset yoffstab
        mov     ecx, 400d
        xor     eax, eax
    yoffsloop:
        stosd
        add     eax, 640d
        loop    yoffsloop

        mov     edi, offset arctan
        mov     ecx, 640d
        mov     eax, 400d
    arctanloop:
        mov     ebx, eax
        sub     ebx, 200d
        mov     edx, ecx
        sub     edx, 320d

        mov     temp1, dx
        mov     temp2, bx
        fild    word ptr temp1
        fild    word ptr temp2
        fpatan                  ; st(0) = st(1)/st(0)
        fimul   word ptr deg    ; st(0) = st(0)*deg
        fldpi                   ; st(1) = st(0), st(0) = pi
        fdivp   st(1), st       ; st(1) = st(1)/st(0), pop st(0)
        fistp   word ptr [edi]  ; st(0) = arctan(y/x)*256/pi

        ;add     edi, 2
        inc     edi

        dec     ecx
        jnz     arctanloop

        mov     ecx, 640d

        dec     eax
        jnz     arctanloop     

        mov     ecx, 255d
        mov     edi, offset cos
    sincos:
        mov     temp1, cx
        fldpi                   ; st(0) = pi
        fimul   word ptr temp1  ; st(0) = st(0)*temp1 (i*pi)
        fidiv   word ptr deg2   ; st(0) = st(0)/deg2
        fsincos
        fimul   word ptr cosmul ; st(0) = cos(i*pi/128)*80
        fistp   dword ptr [edi]
        fimul   word ptr sinmul ; st(0) = sin(i*pi/128)*90
        fistp   dword ptr [edi+256*4]

        add     edi, 4

        dec     ecx
        jns     sincos

        xor     esi, esi
        mov     edi, offset pal
        mov     ecx, redShift

    palloop:
        ; r=0, g=159, b=255 to r=3, g=189, b=40
        ; pal[i] = ((20+(4*i >> 5)) << 5) + (31+(-27*i >> 5));
        mov     eax, esi
        imul    eax, 4
        sar     eax, 5
        add     eax, 20
        shl     eax, 5
        push    eax             ; save red
        mov     eax, esi
        imul    eax, -27
        sar     eax, 5
        add     eax, 31
        pop     edx
        add     eax, edx
        mov     ebx, esi
        mov     [edi], ax

        ; r=3, g=189, b=40 to r=227, g=245, b=3
        ; pal[32+i] = ((28*i >> 5) << redShift) + ((23+(7*i >> 5)) << 5) + (5+(-5*i >> 5));
        mov     eax, esi
        imul    eax, 28
        sar     eax, 5
        shl     eax, cl
        push    eax             ; save red
        mov     eax, esi
        imul    eax, 7
        sar     eax, 5
        add     eax, 23
        shl     eax, 5
        push    eax             ; save green
        mov     eax, esi
        imul    eax, -5
        sar     eax, 5
        add     eax, 5
        pop     edx
        add     eax, edx
        pop     edx
        add     eax, edx
        mov     [edi+32*2], ax

        ; r=227, g=245, b=3 to r=251, g=173, b=102
        ; pal[64+i] = ((28+(3*i >> 5)) << redShift) + ((30+(-9*i >> 5)) << 5) + (12*i >> 5);
        mov     eax, esi
        imul    eax, 3
        sar     eax, 5
        add     eax, 28
        shl     eax, cl
        push    eax             ; save red
        mov     eax, esi
        imul    eax, -9
        sar     eax, 5
        add     eax, 30
        shl     eax, 5
        push    eax             ; save green
        mov     eax, esi
        add     eax, 12
        sar     eax, 5
        pop     edx
        add     eax, edx
        pop     edx
        add     eax, edx
        mov     [edi+64*2], ax

        ; r=251, g=173, b=102 to r=232, g=0, b=40
        ; pal[96+i] = ((31+(-2*i >> 5)) << redShift) + ((22+(-22*i >> 5)) << 5) + (12+(-8*i >> 5));
        mov     eax, esi
        imul    eax, -2
        sar     eax, 5
        add     eax, 31
        shl     eax, cl
        push    eax             ; save red
        mov     eax, esi
        imul    eax, -22
        sar     eax, 5
        add     eax, 22
        shl     eax, 5
        push    eax             ; save green
        mov     eax, esi
        imul    eax, -8
        sar     eax, 5
        add     eax, 12
        pop     edx
        add     eax, edx
        pop     edx
        add     eax, edx
        mov     [edi+96*2], ax

        ; r=232, g=0, b=40 to r=206, g=22, b=233
        ; pal[128+i] = ((29+(-3*i >> 5)) << redShift) + ((3*i >> 5) << 5) + (4+(24*i >> 5));
        mov     eax, esi
        imul    eax, -3
        sar     eax, 5
        add     eax, 29
        shl     eax, cl
        push    eax             ; save red
        mov     eax, esi
        imul    eax, 3
        sar     eax, 5
        shl     eax, 5
        push    eax             ; save green
        mov     eax, esi
        imul    eax, 24
        sar     eax, 5
        add     eax, 4
        pop     edx
        add     eax, edx
        pop     edx
        add     eax, edx
        mov     [edi+128*2], ax

        ; r=206, g=22, b=233 to r=133, g=15, b=240
        ; pal[160+i] = ((26+(-9*i >> 5)) << redShift) + ((3+(-i >> 5)) << 5) + (28+(i >> 5));
        mov     eax, esi
        imul    eax, -9
        sar     eax, 5
        add     eax, 26
        shl     eax, cl
        push    eax             ; save red
        mov     eax, esi
        neg     eax
        sar     eax, 5
        add     eax, 3
        shl     eax, 5
        push    eax             ; save green
        mov     eax, esi
        sar     eax, 5
        add     eax, 28
        pop     edx
        add     eax, edx
        pop     edx
        add     eax, edx
        mov     [edi+160*2], ax

        ; r=133, g=15, b=240 to r=50, g=120, b=205
        ; pal[192+i] = ((17+(-10*i >> 5)) << redShift) + ((2+(13*i >> 5)) << 5) + (29+(-4*i >> 5));
        mov     eax, esi
        imul    eax, -10
        sar     eax, 5
        add     eax, 17
        shl     eax, cl
        push    eax             ; save red
        mov     eax, esi
        imul    eax, 13
        sar     eax, 5
        add     eax, 2
        shl     eax, 5
        push    eax             ; save green
        mov     eax, esi
        imul    eax, -4
        sar     eax, 5
        add     eax, 29
        pop     edx
        add     eax, edx
        pop     edx
        add     eax, edx
        mov     [edi+192*2], ax

        ; r=60, g=120, b=205 to r=0, g=159, b=255
        ; pal[224+i] = ((8+(-8*i >> 5)) << redShift) + ((15+(5*i >> 5)) << 5) + (26+(6*i >> 5));
        mov     eax, esi
        imul    eax, -8
        sar     eax, 5
        add     eax, 8
        shl     eax, cl
        push    eax             ; save red
        mov     eax, esi
        imul    eax, 5
        sar     eax, 5
        add     eax, 15
        shl     eax, 5
        push    eax             ; save green
        mov     eax, esi
        imul    eax, 6
        sar     eax, 5
        add     eax, 26
        pop     edx
        add     eax, edx
        pop     edx
        add     eax, edx
        mov     [edi+224*2], ax

        add     edi, 2

        inc     esi
        cmp     esi, 32
        jne     palloop

        ret
initTables ENDP

rand    PROC
        ; destroys eax

        push    ebx
        push    edx

        mov     ebx, seed
        mov     eax, 48370539
        imul    ebx
        add     eax, 46734
        mov     seed, eax
        shr     eax, 15

        pop     edx
        pop     ebx

        ret

rand    ENDP

WndProc PROC    hWin    :DWORD,
                uMsg    :DWORD,
                wParam  :DWORD,
                lParam  :DWORD

        cmp     uMsg, WM_KEYDOWN
        jne     @nokey

        cmp     wParam, VK_ESCAPE
        jne     @nokey
        ; escape was pressed, so quit program
        invoke  PostQuitMessage, NULL
        return  0

    @nokey:
        cmp     uMsg, WM_DESTROY
        jne     @doneWnd
        invoke  PostQuitMessage, NULL
        return  0

    @doneWnd:

        invoke  DefWindowProc, hWin, uMsg, wParam, lParam

        ret
        
WndProc ENDP

;----------------------------------------------------------------------------

END start
;-- eof ---------------------------------------------------------------------
