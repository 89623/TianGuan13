# Medical Blanks (MEDICAL_BLANKS)

Module ID: MEDICAL_BLANKS

## Description

Adds 14 Chinese medical paper blank templates (SSFMTU branded) to the photocopier, expanding the Medical Department's form library from 7 to 21.

These templates use the 太阳系联邦医科大附属医疗中心 (Solar System Federation Medical Technician University Teaching Medical Center) branding instead of the standard NT logo.

## Templates

| Code | 中文名称 | Purpose |
|------|---------|---------|
| NT-MDC-EM | 院前急救出勤单 | Prehospital emergency response record |
| NT-MDC-SG | 手术记录单 | Surgical procedure record |
| NT-MDC-PM | 病理尸检报告 | Pathology autopsy report |
| NT-MDC-CR | 死亡医学证明书 | Medical certificate of death |
| NT-MDC-RQ | 药品领用单 | Medication requisition form |
| NT-MDC-RC | 门诊/住院病历记录 | Outpatient/inpatient medical record |
| NT-MDC-RT | 拒绝治疗知情同意书 | Refusal of treatment consent |
| NT-MDC-PL | 病理报告 | Pathology report |
| NT-MDC-PY | 精神病强制住院通知书 | Psychiatric involuntary admission order |
| NT-MDC-ID | 传染病报告卡 | Infectious disease report card |
| NT-MDC-RX | 处方笺 | Prescription form |
| NT-MDC-OD | 器官捐献同意书 | Organ donation consent |
| NT-MDC-TG | 急诊分诊标签 | Emergency triage tag |
| NT-MDC-LR | 实验室检验申请单 | Laboratory test request form |

## Architecture

```
config/tianguan/blanks.json                    ← 14 template definitions (Chinese)
modular_tianguan/modules/medical_blanks/
  code/init_medical_blanks.dm                  ← load + inject via Initialize() hook
  readme.md                                    ← This file
```

**No core files modified.** The module hooks into `/obj/machinery/photocopier/Initialize()` via proc override. On the first photocopier to spawn (at world init), it injects the 14 Tianguan blanks into `GLOB.paper_blanks`. A static guard flag prevents re-injection.

Since templates contain Chinese text directly, `lang_reverse_text()` passes them through as-is (no i18n hash match → returns original). No `strings/i18n/` modifications needed.

## Core files modified

| File | Change | Reason |
|------|--------|--------|
| *None* | — | Fully modular via proc override |

## Testing

1. Compile with `BUILD.bat`
2. Launch server, join as any medical role
3. Use a photocopier → check Medical Department category shows 21 templates (7 existing + 14 new)
4. Print each template → verify Chinese text displays correctly

## Maintenance notes

- New templates should be added to `config/tianguan/blanks.json` (keep standard JSON format)
- Check for code collisions against both `config/blanks.json` and `config/nova/blanks.json` before assigning new codes
- If upstream merges bring changes to `photocopier.dm`, check the TIANGUAN EDIT line

## Credits

太阳系联邦医科大学教研组 / SSFMTU Teaching Medical Center
