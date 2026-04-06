# After Action Review (AAR)

**Data**: 2026-03-26
**Operacao**: Kernel Blackout — TryHackMe (Premium Network Room)
**Target**: 10.200.150.10 (Target DC), 10.200.150.20 (MalwareDev)
**Categoria**: CTF
**Resultado**: Success

---

## 1. Objetivo
Desenvolver rootkit kernel (DKOM) para esconder processo `implant.exe` no Target. Build no MalwareDev com VS x64 + WDK. Upload via web app `/api/upload`.

## 2. O Que Funcionou
| Tecnica | Contexto | Por que funcionou |
|---------|----------|-------------------|
| DKOM ActiveProcessLinks unlink | Esconder implant.exe de psutil/NtQuerySystemInformation | Remover da doubly-linked list impede enumeracao userspace |
| Dynamic EPROCESS offset detection | Scan 0x2D0-0x500 por PID=4 + validacao kernel pointer | Cobre todos builds Win10/11/Server sem hardcode |
| NULL-safe DriverEntry (kdmapper) | ZERO referencia a DriverObject/RegistryPath | KDMapper passa NULL — qualquer deref = BSOD |
| Backend source code analysis | Ler app.py revelou kdmapper.exe como mecanismo de deploy | Sem isso, impossivel saber por que drivers crashavam |
| Remote build via wmiexec + SMB | Upload .c/.bat via SMB, compilar via wmiexec, download .sys | Sem necessidade de RDP interativo |

## 3. O Que Falhou
| Erro | Impacto | Causa Raiz |
|------|---------|------------|
| 4 BSODs por DriverObject->DriverUnload = DriverUnload | ~45 min perdidos esperando reboots | Nao sabia que kdmapper passa NULL DriverObject |
| Nao investigar backend source ANTES de escrever driver | 3 rewrites desnecessarios | Fui direto para codigo sem entender o mecanismo de deploy |
| Nmap full port scan desnecessario | Tempo perdido, user corrigiu | Lab de desenvolvimento, nao pentest. Briefing ja deu tudo |
| curl para HTTP manual (4x) | Violacao R01 | Default para curl em vez de Burp |
| VPN no Windows local | Tempo perdido procurando OpenVPN | VPN sempre na VPS, nao local |
| Dynamic offset search com false positive | BSOD no primeiro driver | UserTimeMs=4 interpretado como PID. Range 0x200 muito amplo |

## 4. Descobertas Tecnicas
- **KDMapper**: Mapeia driver em kernel via Intel vuln driver (iqvw64e.sys). DriverObject=NULL, RegistryPath=NULL. DriverUnload NAO funciona (driver manually mapped, nao registered).
- **EPROCESS offsets Windows Server 2019 Build 17763**: UniqueProcessId=0x2E0, ActiveProcessLinks=0x2E8, ImageFileName=0x450
- **Dynamic offset scan range**: 0x2D0-0x500 cobre Win10 1607 ate Win11 24H2+ sem false positives
- **DKOM unlink seguro**: Raise IRQL to DISPATCH_LEVEL durante unlink. Self-reference (entry->Flink=entry) previne BSOD por dangling pointer.
- **psutil.process_iter()** usa NtQuerySystemInformation que walk ActiveProcessLinks — DKOM esconde completamente
- **Build flags kernel driver**: `/c /GS- /Zl /kernel /NODEFAULTLIB /SUBSYSTEM:NATIVE /DRIVER /ENTRY:DriverEntry`
- **WDK paths Server 2019**: Include=`C:\Program Files (x86)\Windows Kits\10\Include\10.0.19041.0\km`, Lib=`...\Lib\10.0.19041.0\km\x64`

## 5. Licoes
1. **INVESTIGAR MECANISMO DE DEPLOY ANTES DE ESCREVER CODIGO** — ler backend source, entender como .sys e carregado
2. **KDMapper = NULL DriverObject** — NUNCA tocar DriverObject quando driver e manually mapped
3. **CTF dev labs TEM starter code/hints** — verificar C:\inetpub\wwwroot\challenge, C:\gitea\repos, Desktop
4. **Lab de desenvolvimento != pentest** — seguir briefing, nao fazer full port scan
5. **EPROCESS dynamic scan range 0x2D0-0x500** — elimina false positives de timer fields (~0x200)
6. **VPN na VPS, NAO local** — Windows local nao tem OpenVPN

## 6. Flag
THM{H1D3N_FR0M_US3RSP4C3}