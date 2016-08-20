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

seed            DD                  12345678h

wc              WNDCLASS            <CS_HREDRAW+CS_VREDRAW, offset WndProc, \
                                    0, 0, 0, 0, 0, 0, 0, offset szClassName>
szClassName     DB                  "DDTest", 0
szDispName      DB                  "Funkylines", 0

pPoint          POINT               <0, 0>

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

rRect           RECT                <?>

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
pal             DD                  256 dup (?)

yoffstab        DD                  400 dup (?)
;----------------------------------------------------------------------------


;----------------------------------------------------------------------------
; equates
;----------------------------------------------------------------------------

FALSE           EQU         0
TRUE            EQU         1
WINDOW_WIDTH    EQU         320
WINDOW_HEIGHT   EQU         200

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

        invoke  CreateWindowExA, 0, ADDR szClassName,
        ADDR szDispName,
        WS_OVERLAPPEDWINDOW,
        CW_USEDEFAULT, CW_USEDEFAULT, WINDOW_WIDTH, WINDOW_HEIGHT,
        0, 0, hInst, 0

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
        DDINVOKE SetCooperativeLevel, lpDD, hWnd, DDSCL_NORMAL
        .if eax != DD_OK
            fatal "Couldn't set cooperative level"
        .endif

        ; create primary surface
        invoke  RtlZeroMemory, ADDR ddsd, SIZEOF DDSURFACEDESC

        mov     ddsd.dwFlags, DDSD_CAPS
        mov     ddsd.ddsCaps.dwCaps, DDSCAPS_PRIMARYSURFACE
        mov     ddsd.dwSize, SIZEOF DDSURFACEDESC
        DDINVOKE CreateSurface, lpDD, ADDR ddsd, ADDR lpDDSp, NULL
        .if eax != DD_OK
            fatal "Couldn't create primary surface"
        .endif

        ; create back buffer surface
        invoke  RtlZeroMemory, ADDR ddsd, SIZEOF DDSURFACEDESC

        mov     ddsd.dwFlags, DDSD_WIDTH OR DDSD_HEIGHT
        mov     ddsd.dwWidth, WINDOW_WIDTH
        mov     ddsd.dwHeight, WINDOW_HEIGHT
        mov     ddsd.dwSize, SIZEOF DDSURFACEDESC
        DDINVOKE CreateSurface, lpDD, ADDR ddsd, ADDR lpDDSb, NULL
        .if eax != DD_OK
            fatal "Couldn't create back buffer surface"
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
            mov     ebp, WINDOW_WIDTH
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

            mov     edx, dword ptr pal[edx*4]
            mov     [edi], edx

            add     edi, 4

            dec     ebp
            jnz     lineloop

            mov     ebp, WINDOW_WIDTH

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

        mov     pPoint.x, 0
        mov     pPoint.y, 0
        invoke  ClientToScreen, hWnd, ADDR pPoint
        invoke  GetClientRect, hWnd, ADDR rRect
        invoke  OffsetRect, ADDR rRect, pPoint.x, pPoint.y

        ; copy back buffer to primary surface
        DDSINVOKE Blt, lpDDSp, ADDR rRect, lpDDSb, NULL, 0, NULL

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
        add     eax, WINDOW_WIDTH * 2
        loop    yoffsloop

        mov     edi, offset arctan
        mov     ecx, WINDOW_WIDTH * 2
        mov     eax, WINDOW_HEIGHT * 2
    arctanloop:
        mov     ebx, eax
        sub     ebx, WINDOW_HEIGHT
        mov     edx, ecx
        sub     edx, WINDOW_WIDTH

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

        mov     ecx, WINDOW_WIDTH * 2

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

        setpal MACRO i, ofs, r0, g0, b0, r1, g1, b1
            ; red
            mov     eax, i
            imul    eax, (r1 - r0)
            sar     eax, 5
            add     eax, r0
            shl     eax, 16

            ; green
            mov     ecx, i
            imul    ecx, (g1 - g0)
            sar     ecx, 5
            add     ecx, g0
            shl     ecx, 8

            ; combine red and green
            or      eax, ecx

            ; blue
            mov     ecx, i
            imul    ecx, (b1 - b0)
            sar     ecx, 5
            add     ecx, b0

            ; combine blue with red and green
            or      eax, ecx

            mov     ebx, i
            add     ebx, ofs
            mov     [edi+ebx*4], eax
        ENDM

    palloop:
        ; r=0, g=159, b=255 to r=3, g=189, b=40
        setpal esi, 0, 0, 159, 255, 3, 189, 40

        ; r=3, g=189, b=40 to r=227, g=245, b=3
        setpal esi, 32, 3, 189, 40, 227, 245, 3

        ; r=227, g=245, b=3 to r=251, g=173, b=102
        setpal esi, 64, 227, 245, 3, 251, 173, 102

        ; r=251, g=173, b=102 to r=232, g=0, b=40
        setpal esi, 96, 251, 173, 102, 232, 0, 40

        ; r=232, g=0, b=40 to r=206, g=22, b=233
        setpal esi, 128, 232, 0, 40, 206, 22, 233

        ; r=206, g=22, b=233 to r=133, g=15, b=240
        setpal esi, 160, 206, 22, 233, 133, 15, 240

        ; r=133, g=15, b=240 to r=50, g=120, b=205
        setpal esi, 192, 133, 15, 240, 50, 120, 205

        ; r=60, g=120, b=205 to r=0, g=159, b=255
        setpal esi, 224, 60, 120, 205, 0, 159, 255

        inc     esi
        cmp     esi, 32
        jne     palloop

        ret
initTables ENDP

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
