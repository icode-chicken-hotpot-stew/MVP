# /// script
# requires-python = ">=3.10"
# dependencies = ["pillow>=10.0.0"]
# ///
"""
Pre-commit hook: 检测并自动转换 assets 目录下的 PNG/JPG 图片为 WebP

如果检测到未转换的图片：
1. 自动转换为 WebP
2. 删除原文件
3. 自动暂存新文件
4. 返回非零退出码，提示用户重新提交
"""

import subprocess
import sys
from pathlib import Path

from PIL import Image


def get_project_root() -> Path:
    """获取项目根目录"""
    result = subprocess.run(
        ["git", "rev-parse", "--show-toplevel"],
        capture_output=True,
        text=True,
    )
    return Path(result.stdout.strip())


def get_staged_images(project_root: Path) -> list[Path]:
    """获取暂存区中的 PNG/JPG 图片"""
    result = subprocess.run(
        ["git", "diff", "--cached", "--name-only", "--diff-filter=ACM"],
        capture_output=True,
        text=True,
        cwd=project_root,
    )

    staged_files = result.stdout.strip().split("\n")
    image_extensions = {".png", ".jpg", ".jpeg"}

    images = []
    for f in staged_files:
        if not f:
            continue
        path = project_root / f
        if path.suffix.lower() in image_extensions and "assets" in path.parts:
            images.append(path)

    return images


def convert_to_webp(image_path: Path) -> Path:
    """将图片转换为 WebP 并删除原文件"""
    webp_path = image_path.with_suffix(".webp")

    with Image.open(image_path) as img:
        img.save(webp_path, "WEBP", quality=85, method=6)

    # 计算压缩比
    original_size = image_path.stat().st_size / 1024
    new_size = webp_path.stat().st_size / 1024

    # 删除原文件
    image_path.unlink()

    return webp_path, original_size, new_size


def main() -> int:
    project_root = get_project_root()
    images = get_staged_images(project_root)

    if not images:
        return 0  # 没有需要转换的图片，通过

    print("\n🖼️  检测到未转换的图片，正在自动处理...")
    print("-" * 50)

    converted = []
    for img_path in images:
        try:
            relative_path = img_path.relative_to(project_root)
            webp_path, old_size, new_size = convert_to_webp(img_path)
            webp_relative = webp_path.relative_to(project_root)

            reduction = (1 - new_size / old_size) * 100
            print(
                f"  ✅ {relative_path} → {webp_relative.name} "
                f"({old_size:.0f}KB → {new_size:.0f}KB, -{reduction:.0f}%)"
            )
            converted.append((img_path, webp_path))
        except Exception as e:
            print(f"  ❌ {img_path.name}: 转换失败 - {e}")
            return 1

    # 更新 git 暂存区
    for old_path, new_path in converted:
        old_relative = old_path.relative_to(project_root)
        new_relative = new_path.relative_to(project_root)

        # 从暂存区移除旧文件
        subprocess.run(
            ["git", "rm", "--cached", str(old_relative)],
            cwd=project_root,
            capture_output=True,
        )
        # 添加新文件到暂存区
        subprocess.run(
            ["git", "add", str(new_relative)],
            cwd=project_root,
            capture_output=True,
        )

    print("-" * 50)
    print(f"📦 已转换 {len(converted)} 张图片并更新暂存区")
    print("\n⚠️  请重新运行 git commit 完成提交\n")

    return 1  # 返回非零，阻止本次提交


if __name__ == "__main__":
    sys.exit(main())
