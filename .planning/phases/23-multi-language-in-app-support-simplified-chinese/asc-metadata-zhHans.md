# App Store Connect — Simplified Chinese (zh-Hans) Metadata for Tonus

**Status:** Drafted by Plan 23-05 Task 1. Awaiting user paste-in under Task 3 (`checkpoint:human-verify`).

**Audience:** Mainland China + global users on the zh-Hans storefront. Tone: peer-coach voice, mainland fitness culture conventions. NOT a literal translation of the English copy — follows UI-SPEC Surface 3 hybrid format (`训练负荷比 (ACWR)` on first occurrence in long-form copy) and the tone guideline from UI-SPEC lines 298–302.

**Per memory `feedback_asc_caution.md`:** the executor never clicks "Submit for Review" or "Release". The user pastes each value below into App Store Connect and saves; nothing is auto-submitted.

---

## App Name Decision (gated on user confirmation in Task 3)

ASC App Name has two valid styles for Tonus on zh-Hans:

1. **Hybrid (default in this draft):** `Tonus · 训练负荷管理` — keeps the brand as Latin while giving zh-Hans browsers an immediate descriptor. Aligns with memory `project_rename_faros.md` (Tonus is the official Latin brand).
2. **Latin-only (brand-purity option):** `Tonus` — matches international branding exactly. If you prefer this, replace the `App Name` value below with `Tonus` before pasting into ASC.

The draft below uses **option 1 (hybrid)** as the default. User confirms or edits during the Task 3 checkpoint before pasting.

---

## Metadata Fields

### App Name

Limit: 30 characters.

```text
Tonus · 训练负荷管理
```

### Subtitle

Limit: 30 characters.

```text
恢复 × 训练负荷 智能管理
```

### Promotional Text

Limit: 170 characters. Editable without re-review — use for time-sensitive announcements.

```text
全新简体中文版本上线。结合 HRV、睡眠与训练负荷,每天给你一个清晰的就绪度评分,让训练更聪明、更可持续。
```

### Description

Limit: 4000 characters.

```text
Tonus 是为认真训练的运动员打造的负荷与恢复管理工具。把每天的训练负荷与身体状态放在同一个画面里,帮你做出更聪明的决定。

核心理念

训练效果不是一次性的努力,而是负荷与恢复之间长期的平衡。Tonus 把这两条曲线画在一起,让你看见自己身体真实的反应,从根本上避免过度训练与受伤。

主要功能

- 每日就绪度评分:综合心率变异性 (HRV)、静息心率、睡眠时长与睡眠效率,给出 0–100 的恢复评分与训练建议。
- 训练负荷比 (ACWR):基于指数加权移动平均 (EWMA) 的急性/慢性负荷比,实时监控过度训练风险。所有计算遵循已发表的运动科学文献。
- 自动训练调节:Tonus 会根据当日恢复评分与负荷曲线,推荐保持原计划、降低强度或主动恢复,让你少走弯路。
- 个人记录追踪 (PR):自动检测力量训练的最大重量、最大次数与体积里程碑,无需手动标记。
- 模板化训练日志:支持自定义动作、训练组与训练计划模板,适用力量、跑步、骑行与综合训练。
- HealthKit 深度集成:只读读取 HRV、静息心率、睡眠与训练心率,原始数据不上传云端,只有评分会同步。
- 教练-运动员协作:支持教练查看运动员就绪度、分配训练模板、远程跟进。
- 简体中文全功能本地化:UI、术语、单位、日期格式与图表均按中国大陆习惯呈现。

订阅说明

Tonus 提供两个订阅档:Athlete Pro(运动员高级版)解锁历史趋势、智能负荷建议与自定义动作;Coach(教练版)在 Athlete Pro 基础上加入教练面板与运动员管理。订阅通过 Apple 内购管理,可随时取消。

隐私

所有 HealthKit 原始健康数据仅在本机处理,从不上传服务器。云端仅保存恢复评分、训练负荷等合成指标,用于跨设备同步。详细政策见应用内"隐私政策"页面。
```

### Keywords

Limit: 100 characters. Comma-separated, no spaces after commas (ASC convention).

```text
训练负荷,恢复评分,HRV,心率变异性,ACWR,运动表现,过度训练,周期化,跑步,力量训练
```

### What's New

Limit: 4000 characters. Per-release notes.

```text
新增简体中文支持

- 全应用界面与术语完成简体中文本地化:仪表盘、训练日志、恢复评分、训练负荷与教练面板均已翻译。
- 训练专业术语采用首次出现"中文+英文缩写"的混合写法,例如"训练负荷比 (ACWR)"、"心率变异性 (HRV)",兼顾可读性与专业性。
- 日期、时间、数字与体重单位按中国大陆习惯呈现。
- HealthKit 权限说明文字已本地化。
- 修复若干稳定性问题。
```

### Support URL

Limit: 255 characters. Reuse existing en URL unless you maintain a zh-specific page.

```text
https://tuwa.app/support
```

### Marketing URL

Limit: 255 characters. Reuse existing en URL unless you maintain a zh-specific page.

```text
https://tuwa.app
```

---

## Character-Count Self-Check

The verification script in Task 1 extracts each fenced block above and asserts `len(value) <= limit` (Chinese characters count as 1 each per ASC rules). Re-run via:

```bash
python3 - <<'PY'
import re
content = open('.planning/phases/23-multi-language-in-app-support-simplified-chinese/asc-metadata-zhHans.md').read()
patterns = {
  'App Name': 30,
  'Subtitle': 30,
  'Promotional Text': 170,
  'Description': 4000,
  'Keywords': 100,
  "What's New": 4000,
}
errors = []
for label, limit in patterns.items():
    m = re.search(r'###\s+' + re.escape(label) + r'.*?\n+```(?:text)?\n(.*?)\n```', content, re.DOTALL)
    if not m:
        errors.append(f'{label}: section missing')
        continue
    val = m.group(1).strip()
    print(f'{label}: {len(val)} / {limit}')
    if len(val) > limit:
        errors.append(f'{label}: {len(val)} > {limit}')
print('Errors:', errors)
assert not errors
PY
```

## Glossary Anchors (per UI-SPEC Surface 3 / D-07)

First occurrences of technical terms in long-form copy use the hybrid form `Chinese (ASCII Latin)` with a single ASCII space and ASCII parentheses:

- 训练负荷比 (ACWR) — appears in Description
- 心率变异性 (HRV) — appears in Description
- 指数加权移动平均 (EWMA) — appears in Description
- 个人记录 (PR) — appears in Description

Subsequent occurrences within the same surface drop the parenthetical and use the Chinese term alone.
