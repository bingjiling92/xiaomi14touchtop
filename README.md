# 小米14 (houji) 触控手感优化

> 在不牺牲稳定性的前提下，优化小米14触控从采样到屏幕响应的全链路延迟。
>
> **实测结论：手感良好** ✅ （作者本人长期使用验证）

<p align="center">
  <img alt="device" src="https://img.shields.io/badge/device-Xiaomi%2014%20(houji)-orange">
  <img alt="touch-ic" src="https://img.shields.io/badge/touch%20IC-Synaptics-blue">
  <img alt="root" src="https://img.shields.io/badge/root-KernelSU-green">
  <img alt="license" src="https://img.shields.io/badge/license-All%20Rights%20Reserved-red">
</p>

---

## ⚖️ 版权声明 / Copyright

**Copyright © 2026 bingjiling92. All Rights Reserved.**
**本作品版权归作者 [bingjiling92](https://github.com/bingjiling92) 所有。**

- 本仓库中的所有配置参数、技术文档、脚本及说明文字，**版权均归原作者所有**。
- 未经作者书面许可，**禁止用于任何商业用途**（包括但不限于售卖、付费整合、商业产品内置等）。
- **欢迎二次开发与学习参考，但必须在显著位置标注原作者及原仓库链接**，格式建议如下：

  ```
  本项目基于 bingjiling92/xiaomi14touchtop 二次开发
  原作者：bingjiling92
  原仓库：https://github.com/bingjiling92/xiaomi14touchtop
  ```

- 二次开发的作品**不得删除或篡改本版权声明**。
- 转载、搬运本文档或参数表，请注明出处。

---

## 📌 简介

小米14（codename: **houji** / S3910P）触控模块为 **Synaptics**，物理采样率 240Hz。
默认配置下存在以下现象：

- 空闲时大幅降频（报点率跌至 ~112Hz）
- 移动跟踪进入稳态较慢
- 首帧丢弃

**优化目标**：维持物理采样率不变，尽量降低「采样 → 上报 → 响应」的延迟，同时保留合理的滤波以维持顺滑手感。

---

## ✨ 优化成果

相对原厂配置，共修改 **10 处参数**：

- 原厂 md5：`11ee96df284ac4a10ca3c6448d7865aa`
- 优化后 md5：`63319deadb21d7d19cf57051dec7e6c7`

| # | 参数 | 原厂 → 优化 | 作用 |
|---|---|---|---|
| 1 | `super_report_en` | 0 → **1** | 开启高报点率上报 |
| 2 | `idle_normal` | 500 → **300** | 缩短空闲判定 |
| 3 | `idle_baseline_time_normal` | 400 → **250** | 加快基线恢复 |
| 4 | `first_jitter_stable_frame` | 18 → **10** | 更快进入稳定跟踪 |
| 5 | `first_jitter_stable_frame_game_mode` | 36 → **18** | 游戏模式同上 |
| 6 | `move_jitter_pre_count` | 20 → **10** | 减少移动预判延迟 |
| 7 | `move_jitter_lock_dis` | 6 → **3** | 收紧移动锁定阈值 |
| 8 | `move_jitter_lock_dis_min` | 2 → **1** | 同上 |
| 9 | `move_jitter_first_dis` | 2 → **1** | 同上 |
| 10 | `skip_first_frame_num` | 1 → **0** | 不丢首帧 |

### 滤波参数（保持原厂值，防抖优先）

| 参数 | 值 | 说明 |
|---|---|---|
| `kalman_filter_smooth_en` | **1** | 卡尔曼平滑，保持开启 |
| `jitter_filter_en` | **1** | 抖动滤波，保持开启 |

> 经权衡后选择「延迟与平滑的平衡点」，而非极致低延迟。

---

## 📂 文件说明

```
.
├── README.md                            # 本说明
├── LICENSE                              # 许可证（保留所有权利）
├── TOUCH_FINAL_REPORT.md                # 完整技术报告
├── touch_config/
│   └── ini_CURRENT_working.ini          # 当前生效的优化配置
└── module/                              # KernelSU 模块
    ├── module.prop                      # 模块信息
    ├── post-fs-data.sh                  # 开机挂载脚本
    └── uninstall.sh                     # 卸载脚本
```

---

## 🔧 技术要点

### 1. 配置文件挂载机制

设备上的配置文件 `/odm/firmware/houji_syna_thp_config.ini` 是一个**独立的 f2fs 单文件挂载**：

```
/dev/block/dm-54 on /odm/firmware/houji_syna_thp_config.ini type f2fs (rw,...)
```

这解释了为什么 `sed -i` 改写会异常失败——它不是普通文件。最终使用 `awk` 重写全文件方式成功改写。

### 2. 根权限方案

- **KernelSU (KSU)**（非 Magisk）
- 模块目录：`/data/adb/modules/`

### 3. report_rate 段（原厂本就支持 300Hz）

```ini
rate_default=240
rate_normal=300
rate_game=300
super_report_en=1
super_report_rate=2
```

原厂 ini 本身允许 300Hz，之前测到的低报点率是**空闲降频**所致。

### 4. speed_touch 模块（未启用）

- 模块已加载但 `refcnt=0`，参数归零
- 厂商预留调试接口（`init.target.rc` 给了 0666 权限）
- 需 framework 主动调用或严格匹配 `vsync_period` 才生效
- **结论：当前手感已好，不建议强行开启**

---

## 🚀 应用方法

```sh
# 0. 确保已获取 Root（KernelSU）
# 1. 备份原厂配置
cp /odm/firmware/houji_syna_thp_config.ini /sdcard/tp_config.orig.bak

# 2. 写入优化配置
cp touch_config/ini_CURRENT_working.ini /odm/firmware/houji_syna_thp_config.ini

# 3. 重启 touchfeature-service 或直接重启设备
```

> 若使用模块方式，请将 `module/` 复制到 `/data/adb/modules/touch_xiaomi14/`，
> 并在 `Link/odm/firmware/` 下放置同一份 ini（模块通过 bind mount 生效）。

---

## ↩️ 回滚

```sh
# 恢复原厂配置（原厂 md5: 11ee96df284ac4a10ca3c6448d7865aa）
cp /sdcard/tp_config.orig.bak /odm/firmware/houji_syna_thp_config.ini
```

---

## ⚠️ 免责声明

- 本仓库仅供**个人设备调优记录与技术学习**使用
- 修改系统配置文件有风险，请**务必先备份原文件**
- 不同批次 / 固件版本的设备参数可能存在差异，请谨慎套用
- 因使用本项目的配置或脚本而导致的任何设备损坏、数据丢失或系统异常，**作者不承担任何责任**

---

## 🧪 环境

| 项目 | 值 |
|---|---|
| 设备 | 小米14 (houji) |
| 触控 IC | Synaptics |
| 系统 | HyperOS |
| 根方案 | KernelSU |

---

## 📃 License

**All Rights Reserved** © 2026 [bingjiling92](https://github.com/bingjiling92)

本项目仅供学习交流。**二次开发请务必标注原作者及原仓库链接。**
商业用途需获得作者书面授权。

See [LICENSE](./LICENSE) for details.