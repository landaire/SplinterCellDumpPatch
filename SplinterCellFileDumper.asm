; ////////////////////////////////////////////////////////
; ////////////////// Preprocessor Stuff //////////////////
; ////////////////////////////////////////////////////////
BITS 32

; .hacks segment info:
%define ExecutableBaseAddress           00011000h           ; Base address of the executable

%define HacksSegmentAddress             003af000h           ; Virtual address of the .hacks segment
%define HacksSegmentOffset              002f1000h           ; File offset of the .hacks segment
%define HacksSegmentSize                00002000h           ; Size of the .hacks segment


; Package saving functions:
%define UObject_StaticLoad      0004E740h
%define UObject_SavePackage     0004d0c0h
%define wstrcpy                 001b19e9h
%define appStrchr               000293D0h
%define appStrcat               000293e0h
%define EndLoad                 00048D80h


; Data defines:
; The `mov` instruction at the end of UObject::StaticLoad
; that cleans up state.
%define StaticLoad_Cleanup                              0004E84Fh

; Some very long string that we can overwrite
%define VeryLongString                                  002862d0h

; A single backslash
%define Backslash                                       00260954h

; The Z drive
%define ZDrive                                          0027235ch

%define GlobalError                                     002b1508h


; Macros
%macro HACK_FUNCTION 1
    %define %1          HacksSegmentAddress + (_%1 - _hacks_code_start)
%endmacro

%macro HACK_DATA 1
    %define %1          HacksSegmentAddress + (_%1 - _hacks_code_start)
%endmacro

; Functions in our .hacks segment.
HACK_FUNCTION Hack_StaticLoad_Hook
HACK_FUNCTION Hack_DumpFile

; HACK_FUNCTION Hack_MenuHandler_MainMenu
;
; HACK_FUNCTION Hack_SendNetworkBroadcastReply_Hook
; HACK_FUNCTION Hack_NetworkSquadListUpdate_Hook
;
; HACK_FUNCTION Hack_LegaleseCustomText_Hook
;
; HACK_DATA Hack_PrintMessageFormat
; HACK_DATA Hack_EULA_Watermark
; HACK_DATA Hack_GameVariantCategoryMenuOptionTable
;
; HACK_DATA Hack_MenuHandler_MainMenu_JumpTable

;-------------------------------------------------------------
; Main Patches (Basic/Entry)
;-------------------------------------------------------------

    ;---------------------------------------------------------
    ; Patch the data section to update the very long string
    ; to be `Z:`
    ;---------------------------------------------------------
    ; offset
    dd      2841d0h
    dd      (_long_string_end - _long_string_start)
    _long_string_start:

            dw      __?utf16?__(`Z:`),0

    _long_string_end:

    ;---------------------------------------------------------
    ; Patch the StaticLoad function to re-serialize the file
    ; right after it's loaded.
    ;
    ; NOTE: We have 0x42 bytes to work with!
    ;---------------------------------------------------------
    ;dd      (4E804h - ExecutableBaseAddress)
    ; offset
    dd      3e804h
    dd      (_call_object_save_end - _call_object_save_start)
    _call_object_save_start:

        ; Jump to our detour function
        mov     eax, Hack_StaticLoad_Hook
        jmp     eax

    _call_object_save_end:


;---------------------------------------------------------
; .hacks code segment
;---------------------------------------------------------
    dd  HacksSegmentOffset
    dd  (_hacks_code_end - _hacks_code_start)
    _hacks_code_start:

    ;---------------------------------------------------------
    ; Not a function, but a jmp detour
    ;---------------------------------------------------------
    _Hack_StaticLoad_Hook:

        ; Call EndLoad so that the object gets populated
        ; Save the result object from the last call
        mov     eax, EndLoad
        call    eax

        ; Grab the Linker object
        mov     eax, [ebp-0x18]
        ; If the linker object is NULL, don't do anything
        test    eax, eax
        jz      _do_object_save_jmp_cleanup

        ; Only argument is the Linker object
        mov     ecx, Hack_DumpFile
        push    eax
        call    ecx
        add     esp, (4 * 1)

        ; Do function cleanup
        _do_object_save_jmp_cleanup:
        mov     eax, StaticLoad_Cleanup
        jmp     eax

    _Hack_DumpFile:
        ; Load the argument representing the
        ; object that's being saved
        mov     eax, [esp + 4]

        ; Save registers
        push    edi
        push    esi

        ; Allocate space for the file path
        sub     esp, 0x200

        ; Move the object into edi because I'm too lazy
        ; to re-adjust registers
        mov     edi, eax

        ; Grab the input filename
        mov     eax, [edi + 0x98]
        ; If the input filename is empty, jump to the cleanup routine
        ; since this is not a file that's in the packed .lin
        cmp    word [eax], 0
        jz     _Hack_DumpFile_Done

        ; Put the input filename in esi
        mov     esi, eax

        _Hack_DumpFile_File_BaseName:

        ; We are looking for a backslash
        ; this is wchar_t `\`
        push    0x005c
        ; Grab the position of the last backslash for the
        ; input file
        push    esi
        mov     eax, appStrchr
        call    eax
        add     esp, (4 * 2)

        test    eax, eax
        jz      _Hack_DumpFile_BaseName_Continue

        ; Save the position
        mov     esi, eax
        lea     esi, [esi + 2]
        jmp     _Hack_DumpFile_File_BaseName

        _Hack_DumpFile_BaseName_Continue:

        ; We need to go back 1 character to restore
        ; the lost final slash
        lea     esi, [esi - 2]

        ; The file path is located at the beginning of the stack
        mov     ebx, esp

        ; Set the start of VeryLongString to `Z:`
        push    ZDrive
        push    ebx
        mov     eax, wstrcpy
        call    eax
        add     esp, (4 * 2)

        ; Set the copy target to the bytes immediatley
        ; following `z:`, so the result should be
        ; `z:\filename`
        lea     eax, [ebx + 4]

        ; Copy the filename to the path buffer
        push    esi

        ; Set ESI to the full file path for later use
        mov     esi, ebx

        push    eax
        mov     eax, wstrcpy
        call    eax
        add     esp, (4 * 2)

        ; Error
        mov     edx, dword [GlobalError]
        ; InOuter
        mov     eax, [edi + 2Ch]

        ; Conform
        push    0x0
        ; Error
        push    edx
        ; Filename
        push    esi
        ; TopLeveLFlags
        push    0xFFFFFFFF
        ; Base
        push    edi
        ; InOuter
        push    eax

        ; ( UObject* InOuter,
        ;   UObject* Base,
        ;   DWORD TopLevelFlags,
        ;   const TCHAR* Filename,
        ;   FOutputDevice* Error=GError,
        ;   ULinkerLoad* Conform=NULL );
        mov     eax, UObject_SavePackage
        call    eax
        add     esp, (6 * 4)


        _Hack_DumpFile_Done:

        ; Restore the stack to clean up the file
        ; path
        add     esp, 0x200
        ; Restore saved registers
        pop esi
        pop edi

        ret

    _hacks_code_end:


; ////////////////////////////////////////////////////////
; //////////////////// End of file ///////////////////////
; ////////////////////////////////////////////////////////
dd -1
