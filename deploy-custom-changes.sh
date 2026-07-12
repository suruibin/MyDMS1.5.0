#!/usr/bin/env bash
set -euo pipefail

# ============================================================
# DMS 自定义修改部署脚本
# 将仓库 (v1.6-beta) 中修改过的文件部署到安装目录 (v1.5.0)
# 替换前自动备份原始文件到 backup/
# ============================================================

SOURCE_DIR="/home/suruibin/DankMaterialShell/quickshell"
TARGET_DIR="/usr/share/quickshell/dms"
BACKUP_DIR="/home/suruibin/DankMaterialShell/backup/$(date +%Y%m%d_%H%M%S)"

# 需要部署的文件列表 (相对于 quickshell/)
FILES=(
    "Common/SettingsData.qml"
    "Common/settings/SettingsSpec.js"
    "Modules/DankDash/DankDashPopout.qml"
    "Modules/DankDash/AppDrawer.qml"
    "Modules/DankDash/MediaPlayerTab.qml"
    "Modules/DankDash/WallpaperTab.qml"
    "translations/en.json"
)

echo "=============================================="
echo " DMS 自定义修改部署"
echo " 源目录: $SOURCE_DIR"
echo " 目标目录: $TARGET_DIR"
echo " 备份目录: $BACKUP_DIR"
echo "=============================================="
echo ""

# ---- Step 1: 检查源文件 ----
echo "[1/4] 检查源文件..."
for f in "${FILES[@]}"; do
    src="$SOURCE_DIR/$f"
    if [ ! -f "$src" ]; then
        echo "  ❌ 源文件不存在: $src"
        exit 1
    fi
    echo "  ✓ $f"
done
echo ""

# ---- Step 2: 检查目标目录 ----
echo "[2/4] 检查目标目录..."
if [ ! -d "$TARGET_DIR" ]; then
    echo "  ❌ 目标目录不存在: $TARGET_DIR"
    exit 1
fi
for f in "${FILES[@]}"; do
    tgt="$TARGET_DIR/$f"
    if [ -f "$tgt" ]; then
        echo "  ✓ $f (将备份)"
    else
        echo "  ⚠ $f (目标不存在，将新建)"
    fi
done
echo ""

# ---- Step 3: 备份原始文件 ----
echo "[3/4] 备份原始文件到 $BACKUP_DIR..."
mkdir -p "$BACKUP_DIR"
for f in "${FILES[@]}"; do
    tgt="$TARGET_DIR/$f"
    if [ -f "$tgt" ]; then
        # 保留目录结构
        bak_dir="$BACKUP_DIR/$(dirname "$f")"
        mkdir -p "$bak_dir"
        cp "$tgt" "$bak_dir/"
        echo "  ✓ 已备份: $f"
    else
        echo "  - 跳过: $f (不存在，无需备份)"
    fi
done
echo ""

# ---- Step 4: 部署新文件 ----
echo "[4/4] 部署修改后的文件..."
for f in "${FILES[@]}"; do
    src="$SOURCE_DIR/$f"
    tgt="$TARGET_DIR/$f"
    tgt_dir="$(dirname "$tgt")"
    mkdir -p "$tgt_dir"
    sudo cp "$src" "$tgt"
    echo "  ✓ 已部署: $f"
done
echo ""

echo "=============================================="
echo " ✅ 部署完成!"
echo "    备份位置: $BACKUP_DIR"
    echo "    如需恢复: sudo cp -r $BACKUP_DIR/* $TARGET_DIR/"
echo "=============================================="
