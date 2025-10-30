; ////////////////////////////////////////////////////////
; ////////////////// Preprocessor Stuff //////////////////
; ////////////////////////////////////////////////////////
BITS 32

; .hacks segment info:
%define ExecutableBaseAddress           00011000h           ; Base address of the executable

%define HacksSegmentAddress             003af000h           ; Virtual address of the .hacks segment
%define HacksSegmentOffset              002f1000h           ; File offset of the .hacks segment
%define HacksSegmentSize                00002000h           ; Size of the .hacks segment


; Main binary functions:
%define UObject_StaticLoad      0004E740h
%define UObject_SavePackage     0004d0c0h
%define wstrcpy                 001b19e9h
%define appStrchr               000293D0h
%define appStrcat               000293e0h
%define EndLoad                 00048D80h
%define ExportIndex             00039620h
%define ExportSize              00000024h


; Data defines:
; The `mov` instruction at the end of UObject::StaticLoad
; that cleans up state.
%define StaticLoad_Cleanup                              0004E84Fh
; The `mov` instruction that would be executed immediately
; after our VerifyImport hook
%define VerifyImport_Continue                           0003907Bh
; The `mov eax` instruction that woudl be executed immediately
; after the `EndLoad` hook
%define EndLoad_Continue                                00048E04h
; The instruction after the loop which touches up flags on
; imports/exports in SavePackage
%define Save_Package_Save_Summary_Start                 0004d7a8h

; When serializing data, it calls `ResetLoaders`. We want to nop
; that
%define ResetLoadersCall                                0003d1cbh

; Some very long string that we can overwrite
%define VeryLongString                                  002862d0h

; A single backslash
%define Backslash                                       00260954h

; The Z drive
%define ZDrive                                          0027235ch

%define GlobalError                                     002b1508h

; Offset of the Summary field on a ULinkerLoad
%define ULinkerLoadSummaryOffset                        00000030h
%define SummaryExportCountOffset                        (6 * 4)
%define ExportFlagsOffset                               (5 * 4)
%define RF_NeedLoad                                     00000200h

%define StaticLoad_NoObject_Path                        00004E808h
%define StaticLoad_LinkerCreate_NoResult_Path           00004E7F1h


; Macros
%macro HACK_FUNCTION 1
    %define %1          HacksSegmentAddress + (_%1 - _hacks_code_start)
%endmacro

%macro HACK_DATA 1
    %define %1          HacksSegmentAddress + (_%1 - _hacks_code_start)
%endmacro

; Functions in our .hacks segment.
HACK_FUNCTION Hack_StaticLoad_Hook
HACK_FUNCTION Hack_VerifyImport_Hook
HACK_FUNCTION Hack_EndLoad_Preload_Call_Hook
HACK_FUNCTION Hack_DumpFile
HACK_FUNCTION Hack_StaticLoad_LinkerCreate_NoResult_Hook
HACK_FUNCTION Hack_EndLoad

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
    ; BEGIN PATCHES WITHIN `SavePackage` WHICH PREVENT DATA
    ; FROM BEING MUTATED
    ;---------------------------------------------------------

    ; offset
    ; this instruction sequence is
    ;
    ; 0004d212  mov     eax, dword [ebp-0x21c {i_5}]
    ; 0004d218  mov     ecx, dword [data_33c424]
    ; 0004d21e  mov     esi, 0xfff8ffe7
    ; 0004d223  cmp     eax, ecx
    dd      0003d21eh
    dd      (_set_package_flag_end - _set_package_flag_start)
    _set_package_flag_start:

        ; five-byte insruction
        ; mov     esi, 0

    _set_package_flag_end:

    ; offset
    dd      0003d105h
    dd      (_clear_flags_end - _clear_flags_start)
    _clear_flags_start:

        ; two-byte insruction
        ;nop
        ;nop

    _clear_flags_end:

    ; offset
    dd      0003d551h
    dd      (_skip_import_export_touchups_end - _skip_import_export_touchups_start)
    _skip_import_export_touchups_start:

        ;mov     eax, Save_Package_Save_Summary_Start
        ;jmp     eax

    _skip_import_export_touchups_end:

    ; offset
    dd      0003d1cbh
    dd      (_reset_loaders_end - _reset_loaders_start)
    _reset_loaders_start:

        nop
        nop
        nop
        nop
        nop

    _reset_loaders_end:

    ;---------------------------------------------------------
    ; END `SavePackage` MUTATIONS
    ;---------------------------------------------------------

    ;---------------------------------------------------------
    ; Patch the StaticLoad function to re-serialize the file
    ; right after it's loaded.
    ;---------------------------------------------------------
    ;dd      (4E804h - ExecutableBaseAddress)
    ; offset
    dd      3e801h
    dd      (_hook_static_load_end - _hook_static_load_start)
    _hook_static_load_start:
        ; Jump to our detour function
        ;mov     ecx, Hack_StaticLoad_Hook
        ;jmp     ecx

    _hook_static_load_end:

    ;---------------------------------------------------------
    ; Patch the StaticLoad function to re-serialize the file
    ; right after it's loaded.
    ;---------------------------------------------------------
    ;dd      (4E804h - ExecutableBaseAddress)
    ; offset
    dd      3e7eah
    dd      (_hook_static_load_linker_no_result_end - _hook_static_load_linker_no_result_start)
    _hook_static_load_linker_no_result_start:
        ; Jump to our detour function
        ;mov     ecx, Hack_StaticLoad_LinkerCreate_NoResult_Hook
        ;jmp     ecx

    _hook_static_load_linker_no_result_end:

    ;---------------------------------------------------------
    ; Patch the StaticLoad function to re-serialize the file
    ; right after it's loaded.
    ;---------------------------------------------------------
    ;dd      (4E804h - ExecutableBaseAddress)
    ; offset
    dd      38dd9h
    dd      (_hook_end_load_end - _hook_end_load_start)
    _hook_end_load_start:
        ; Jump to our detour function
        mov     ecx, Hack_EndLoad
        jmp     ecx
        nop
        nop

    _hook_end_load_end:

    ;---------------------------------------------------------
    ; Patch VerifyImport to dump the file immediately after
    ; `GetPackageLinker` is called
    ;---------------------------------------------------------
    ;dd      (38fech - ExecutableBaseAddress)
    ; offset
    dd      28fech
    dd      (_verify_import_end - _verify_import_start)
    _verify_import_start:

        ; Jump to our detour function
        ;mov     ecx, Hack_VerifyImport_Hook
        ;jmp     ecx

    _verify_import_end:

    ;---------------------------------------------------------
    ; Patch EndLoad to dump right after Preload on the object
    ; is called
    ;---------------------------------------------------------
    ;dd      (48dfbh - ExecutableBaseAddress)
    ; offset
    dd      38dfbh
    dd      (_endload_preload_call_end - _endload_preload_call_start)
    _endload_preload_call_start:

        ; Jump to our detour function
        ;push    ebx
        ;mov     ebx, Hack_EndLoad_Preload_Call_Hook
        ;jmp     ebx

    _endload_preload_call_end:


;---------------------------------------------------------
; .hacks code segment
;---------------------------------------------------------
    dd  HacksSegmentOffset
    dd  (_hacks_code_end - _hacks_code_start)
    _hacks_code_start:

    _Hack_EndLoad:
        ; We overwrote these instruction

          mov   eax, [ebp - 0x1c]
          mov   eax, [eax + edi * 4]
          mov   [ebp - 0x28], eax

          ; Grab this object's linker
          mov   eax, [eax + 0x10]

          push  eax

          mov   ecx, Hack_DumpFile
          call  ecx

          add   esp, (4 * 1)

          ; Restore this object
          mov   eax, [ebp - 0x1c]
          mov   eax, [eax + edi * 4]
          mov   [ebp - 0x28], eax

          mov   ecx, 0x48de2
          jmp   ecx


    _Hack_EndLoad_Preload_Call_Hook:
        ; Save eax for our own greedy usage
        mov     ebx, ecx
        sub     ebx, 0xA8

        ; Call Preload on the Object
        ; thiscall so no need to clean up stack
        push    eax
        call    dword [edx + 0x10]

        ; Dump the object
        push    ebx
        mov     ecx, Hack_DumpFile
        call    ecx
        add     esp, (4 * 1)

        ; unknown data location. this location gets partially
        ; overwritten by us, so we're doing it here instead.
        mov     eax, [0x33C414]

        ; Restore saved registers
        pop     ebx

        mov     ecx, EndLoad_Continue
        jmp     ecx


    _Hack_VerifyImport_Hook:
        ; These are the instructions we overwrote for our hook
        add     esp, 14h
        mov     [edi+14h], eax
        mov     [ebp-4], dword 0FFFFFFFFh

        ; ebx is the only register that the hooked function
        ; needs, so we save it here.
        push    ebx

        push    eax
        ; ecx gets immediately clobbered by the caller, so
        ; there's no need to restore it
        mov     ecx, Hack_DumpFile
        call    ecx
        add     esp, (4 * 1)

        ; restore registers the caller needs
        pop     ebx

        ; Return control flow back to VerifyImport
        mov     ecx, VerifyImport_Continue
        jmp     ecx

    _Hack_StaticLoad_LinkerCreate_NoResult_Hook:
        ; We overwrote this instruction
        mov     eax, [ebp - 0x14]
        test    eax, eax

        ; If eax is zero, restore execution. Otherwise
        ; jump to the location that continues with dumping
        jnz     _do_object_save_start

        mov     ecx, StaticLoad_LinkerCreate_NoResult_Path
        jmp     ecx

    ;---------------------------------------------------------
    ; Not a function, but a jmp detour
    ;---------------------------------------------------------
    _Hack_StaticLoad_Hook:
        ; We overwrote this instruction
        mov     [ebp - 0x14], eax

        ; If `eax` is zero, we need to restore execution immediately
        test    eax, eax
        jnz     _do_object_save_start

        ; Restore execution
        mov     ecx, StaticLoad_NoObject_Path
        jmp     ecx

    _do_object_save_start:
        push    esi
        push    edi
        push    ebx

        ; Call EndLoad so that the object gets populated
        ; Save the result object from the last call
        mov     eax, EndLoad
        call    eax

        ; Grab the Linker object
        mov     eax, [ebp-0x18]
        ; If the linker object is NULL, don't do anything
        test    eax, eax
        jz      _do_object_save_jmp_cleanup

        _do_object_save_dump_file:

        ; Grab the Linker object
        mov     eax, [ebp-0x18]
        push    eax

        ; Only argument is the Linker object
        mov     ecx, Hack_DumpFile
        call    ecx
        add     esp, (4 * 1)

        ; Do function cleanup
        _do_object_save_jmp_cleanup:
        ;mov     [ebp - 0x4], dword 0FFFFFFFFh

        pop     ebx
        pop     edi
        pop     esi

        mov     ecx, StaticLoad_Cleanup
        jmp     ecx

    _Hack_DumpFile:
        ; Load the argument representing the
        ; object that's being saved
        mov     eax, [esp + 4]

        ; Save registers
        push    edi
        push    esi
        push    ebx

        mov     edi, eax

        ; Iterate the object's exports. If all are loaded, we can dump

        ; Grab the export data pointer
        mov     ecx, [eax + 0x88]
        ; Grab the number of exports
        mov     ebx, [eax + 0x8C]

        ; Allocate space to hold flags
;        mov     eax, ebx
;        imul    eax, 4
;        sub     esp, eax
;
;        ; esi will hold the current export index for the lifetime of the loop
;        mov     esi, 0
;        _dump_file_object_ready_loop_start:
;        cmp     esi, ebx
;        jz      _dump_file_do_dump
;
;        ; Grab the current export flags
;        lea     eax, [ecx + esi]
;        mov     eax, [eax + ExportFlagsOffset + 4]
;
;        ; Ignore if this export's size is zero
;        cmp     eax, 0
;        jz      _dump_file_object_ready_loop_end
;
;        ; Load the export again
;        mov     edx, esi
;        imul    edx, ExportSize
;        push    ebx
;        lea     ebx, [ecx + edx]
;
;        ; Load the flag
;        mov     eax, [ebx + ExportFlagsOffset]
;
;        ; Push the flags to the stack
;        mov     edx, esi
;        imul    edx, 4
;        ; mov     [esp + edx], eax
;
;        ; Drop the RF_NeedLoad bit
;        mov     edx, RF_NeedLoad
;        not     edx
;        and     eax, edx
;        ;mov     [ebx + ExportFlagsOffset], eax
;        pop     ebx
;
;        ; If all lower bits are set, ignore this
;        ; and     eax, (0x7f | 0x00080000)
;        ; test    eax, eax
;        ; je      _dump_file_object_ready_loop_end
;
;        ; lea     eax, [ecx + esi * ExportSize]
;        ; Grab the object pointer
;        ; mov     eax, [eax + ExportFlagsOffset]
;       ; mov     eax, [eax + ExportFlagsOffset + 0x12]
;        ; and     eax, RF_NeedLoad
;
;        ; If the export has the RF_NeedLoad flag,
;        ; we should ignore this object.
;        ; test    eax, eax
;        ; lea     eax, [ecx + esi * ExportSize]
;        ; mov     eax, [eax + ExportFlagsOffset]
;        ; jnz    _dump_file_restore_registers
;
;        _dump_file_object_ready_loop_end:
;
;        inc     esi
;        jmp     _dump_file_object_ready_loop_start

        _dump_file_do_dump:

        ; Iterate the object's exports and save their flags

        ; ==== NOT USED
        ; Grab the export data pointer
        mov     ecx, [edi + 0x88]
        ; Grab the number of exports
        mov     ebx, [edi + 0x8C]
        ; ==== NOT USED

        ; Allocate space for the file path
        sub     esp, 0x200

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
        ;;call    eax
        add     esp, (6 * 4)


        _Hack_DumpFile_Done:

        ; Restore the stack to clean up the file
        ; path
        add     esp, 0x200

        ; Restore the export flags

        ; Grab the export data pointer
        mov     ecx, [edi + 0x88]
        ; Grab the number of exports
        mov     ebx, [edi + 0x8C]

        ; esi will hold the current export index
;        mov     esi, 0
;        _dump_file_restore_flags_loop_start:
;        cmp     esi, ebx
;        jz      _dump_file_restore_registers
;
;        ; Load the export
;        mov     edx, esi
;        imul    edx, ExportSize
;
;        ; Load the export
;        lea     eax, [ecx + edx]
;        ; Load its flag
;        mov     edx, [esp + (esi * 4)]
;        ; Set the export's flag
;        ; mov     [eax + ExportFlagsOffset], edx
;
;        inc     esi
;        jmp     _dump_file_restore_flags_loop_start
;
;        _dump_file_restore_registers:
;        imul    esi, 4
;        add     esp, esi

        ; Restore saved registers
        pop     ebx
        pop     esi
        pop     edi

        ret

    _hacks_code_end:


; ////////////////////////////////////////////////////////
; //////////////////// End of file ///////////////////////
; ////////////////////////////////////////////////////////
dd -1
