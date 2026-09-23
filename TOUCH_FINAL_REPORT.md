# 小米14 (houji) 触控手感优化 — 最终报告

> 生成时间：设备重启后验证版
> 状态：**已完成，用户确认手感良好** ✅

---

## 一、结论速览

| 项目 | 结果 |
|---|---|
| 核心优化 | ✅ **已生效**（10 处 ini 改动） |
| 滤波参数 | ✅ 已回滚至原厂值（防抖优先） |
| 用户手感评价 | ✅ **不错（满意）** |
| speed_touch | ⚠️ 未启用（厂商预留功能，当前不需要） |
| 生效机制 | KernelSU 单文件挂载 + 直接改写 |

**当前生效配置 md5：`63319deadb21d7d19cf57051dec7e6c7`**

---

## 二、系统架构真相

### 2.1 根权限方案
- **KernelSU (KSU)**，非 Magisk
- 模块目录：`/data/adb/modules/`
- KSU overlay 示例：`/odm/etc`、`/vendor/firmware` 由 overlay 提供

### 2.2 触控配置文件挂载机制（关键）
```
/dev/block/dm-54 on /odm/firmware/houji_syna_thp_config.ini type f2fs (rw,...)
```
- 该 ini **被作为独立 f2fs 文件系统挂载**（单文件挂载）
- 这是为何 `sed -i` 会异常失败的根本原因（f2fs 单文件挂载 + 可能的原子替换限制）
- **可用 rw，直接改写能落盘**（用 awk 重写成功验证）

### 2.3 模块 `touch_xiaomi14`
- 位置：`/data/local/tmp/touch_adapter/`
- module.prop：`id=touch_xiaomi14`、`name=小米14触控采样率 300Hz`、`v2.0`
- `post-fs-data.sh` 会把 `Link/odm/firmware/houji_syna_thp_config.ini` bind 到 `/odm/firmware/`
- **注意**：当前 `mount` 列表中**未看到该模块的 bind mount 生效**，但 `/odm/firmware/` 内文件 md5 已是优化版 → 说明**文件本体已被直接改写**，不依赖模块挂载

### 2.4 相关进程
- `vendor.xiaomi.hw.touchfeature-service`（HAL）
- `com.xiaomi.touchservice`（系统服务）
- `toucheventcheck`

---

## 三、当前生效的 10 处优化（相对原厂）

原厂 md5：`11ee96df284ac4a10ca3c6448d7865aa`

| # | 参数 | 原厂 → 当前 | 作用 |
|---|---|---|---|
| 1 | super_report_en | 0 → **1** | 开启高报点率 |
| 2 | idle_normal | 500 → **300** | 缩短空闲判定 |
| 3 | idle_baseline_time_normal | 400 → **250** | 加快基线恢复 |
| 4 | first_jitter_stable_frame | 18 → **10** | 更快进入稳定跟踪 |
| 5 | first_jitter_stable_frame_game_mode | 36 → **18** | 游戏模式同上 |
| 6 | move_jitter_pre_count | 20 → **10** | 减少移动预判延迟 |
| 7 | move_jitter_lock_dis | 6 → **3** | 收紧移动锁定阈值 |
| 8 | move_jitter_lock_dis_min | 2 → **1** | 同上 |
| 9 | move_jitter_first_dis | 2 → **1** | 同上 |
| 10 | skip_first_frame_num | 1 → **0** | 不丢首帧 |

### 保持原厂值（用户主动回滚，防抖优先）
- `kalman_filter_smooth_en=1`（卡尔曼平滑）
- `jitter_filter_en=1`（抖动滤波）

---

## 四、report_rate 段真实结构（原厂本来支持 300Hz）

```
rate_default=240
rate_normal=300
rate_game=300
super_report_en=1
super_report_rate=2
```
→ 原厂 ini 本身允许 300Hz，之前测到的低报点率是**空闲降频**所致。

---

## 五、speed_touch 分析（未启用，建议保持）

### 状态
- 模块已加载：`lsmod | grep speed_touch` 有
- `refcnt = 0`（框架未使用）
- 参数归零：`track_vsync_signal=0`、`vsync_period=0`、`sf_available_buffer_size=0`
- persist 属性：`false` / `false`

### 权限配置（厂商预留调试口）
`/vendor/etc/init/hw/init.target.rc`：
```
chmod 0666 /sys/module/speed_touch/parameters/speed_touch_enable
chmod 0666 .../cur_layer_name
chmod 0666 .../sf_available_buffer_size
chmod 0666 .../track_vsync_signal
```

### 建议
speed_touch 是厂商**半成品/预留功能**，需 framework 主动调用或严格匹配 vsync_period（如 120Hz → 8333333ns）才有效。**当前手感已好，不建议强行开启**（配错可能变差）。

---

## 六、回滚方法

### 方法 1：还原为优化前版本（如果保留过备份）
```sh
# 原厂纯净版需从模块安装包提取，原厂 md5 = 11ee96df284ac4a10ca3c6448d7865aa
```

### 方法 2：卸载模块
```sh
rm -rf /data/adb/modules/touch_xiaomi14   # 若模块已注册
# 或删除 /data/local/tmp/touch_adapter/
```

### 方法 3：仅关高报点率（最温和）
```sh
# 把 super_report_en 改回 0 即可，其余参数影响很小
```

---

## 七、关键路径速查

| 用途 | 路径 |
|---|---|
| 设备生效文件 | `/odm/firmware/houji_syna_thp_config.ini` |
| 模块源文件 | `/data/local/tmp/touch_adapter/Link/odm/firmware/houji_syna_thp_config.ini` |
| 模块脚本 | `/data/local/tmp/touch_adapter/post-fs-data.sh` |
| speed_touch 参数 | `/sys/module/speed_touch/parameters/*` |
| touchfeature HAL | `vendor.xiaomi.hw.touchfeature-service` |
| touch_thp_ic_cmd | 格式 `user_cmd mode`（两段，与采样率无关） |

---

## 八、最终评价

- ✅ **目标达成**：在不牺牲稳定性的前提下提升了触控响应
- ✅ **平衡取舍**：保留响应类优化，回滚滤波类优化（防抖优先）
- ✅ **用户认可**：重启后手感"不错"
- 📌 **无需进一步操作**

**核心改动 = 10 处 ini 参数，全部已落盘生效。**
