# /// script
# requires-python = ">=3.10"
# dependencies = ["pillow>=10.0.0"]
# ///
"""
图片压缩脚本 - 压缩 assets 目录下的大图片，支持转换为 WebP

用法:
    uv run scripts/compress_images.py                  # 压缩所有超过 500KB 的图片
    uv run scripts/compress_images.py --to-webp        # 将 PNG/JPG 转换为 WebP
    uv run scripts/compress_images.py --to-webp --delete  # 转换并删除原文件
    uv run scripts/compress_images.py --max-size 200   # 设置阈值为 200KB
    uv run scripts/compress_images.py --quality 70     # 设置压缩质量 (1-95)
    uv run scripts/compress_images.py --dry-run        # 只预览，不实际执行
"""

import argparse
from pathlib import Path

from PIL import Image


def get_file_size_kb(path: Path) -> float:
    """获取文件大小 (KB)"""
    return path.stat().st_size / 1024


def format_size(size_kb: float) -> str:
    """格式化文件大小显示"""
    if size_kb >= 1024:
        return f"{size_kb / 1024:.2f} MB"
    return f"{size_kb:.1f} KB"


def convert_to_webp(
    image_path: Path,
    quality: int = 85,
    max_dimension: int = 2048,
    delete_original: bool = False,
) -> tuple[bool, Path, float, float]:
    """
    将图片转换为 WebP 格式

    Returns:
        (是否成功, 新文件路径, 原始大小KB, 新大小KB)
    """
    original_size = get_file_size_kb(image_path)
    webp_path = image_path.with_suffix(".webp")

    with Image.open(image_path) as img:
        # 如果图片太大，先缩小尺寸
        if max(img.size) > max_dimension:
            ratio = max_dimension / max(img.size)
            new_size = (int(img.size[0] * ratio), int(img.size[1] * ratio))
            img = img.resize(new_size, Image.Resampling.LANCZOS)

        # 保存为 WebP（method=6 压缩率最高，但速度稍慢）
        img.save(webp_path, "WEBP", quality=quality, method=6)

    new_size = get_file_size_kb(webp_path)

    # 删除原文件
    if delete_original and image_path != webp_path:
        image_path.unlink()

    return True, webp_path, original_size, new_size


def compress_image(
    image_path: Path,
    quality: int = 85,
    max_dimension: int = 2048,
) -> tuple[bool, float, float]:
    """
    压缩单张图片（保持原格式）

    Returns:
        (是否成功, 原始大小KB, 压缩后大小KB)
    """
    original_size = get_file_size_kb(image_path)

    with Image.open(image_path) as img:
        # 如果图片太大，先缩小尺寸
        if max(img.size) > max_dimension:
            ratio = max_dimension / max(img.size)
            new_size = (int(img.size[0] * ratio), int(img.size[1] * ratio))
            img = img.resize(new_size, Image.Resampling.LANCZOS)

        # 根据格式选择压缩方式
        suffix = image_path.suffix.lower()

        if suffix == ".png":
            if img.mode == "RGBA":
                alpha = img.getchannel("A")
                if alpha.getextrema() == (255, 255):
                    img = img.convert("RGB")
            img.save(image_path, "PNG", optimize=True)

        elif suffix in (".jpg", ".jpeg"):
            if img.mode == "RGBA":
                img = img.convert("RGB")
            img.save(image_path, "JPEG", quality=quality, optimize=True)

        elif suffix == ".webp":
            img.save(image_path, "WEBP", quality=quality, method=6)

    new_size = get_file_size_kb(image_path)
    return True, original_size, new_size


def main():
    parser = argparse.ArgumentParser(description="压缩 assets 目录下的图片")
    parser.add_argument(
        "--to-webp",
        action="store_true",
        help="将 PNG/JPG 图片转换为 WebP 格式",
    )
    parser.add_argument(
        "--delete",
        action="store_true",
        help="转换为 WebP 后删除原文件（需配合 --to-webp 使用）",
    )
    parser.add_argument(
        "--max-size",
        type=int,
        default=500,
        help="超过此大小(KB)的图片才会被处理，默认 500",
    )
    parser.add_argument(
        "--quality",
        type=int,
        default=85,
        help="JPEG/WebP 压缩质量 (1-95)，默认 85",
    )
    parser.add_argument(
        "--max-dimension",
        type=int,
        default=2048,
        help="图片最大边长(像素)，超过会等比缩小，默认 2048",
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="只显示会被处理的文件，不实际执行",
    )
    parser.add_argument(
        "--path",
        type=str,
        default="assets",
        help="要扫描的目录，默认 assets",
    )
    parser.add_argument(
        "--all",
        action="store_true",
        help="处理所有图片，忽略大小限制",
    )

    args = parser.parse_args()

    # 获取项目根目录 (脚本在 scripts/ 下)
    script_dir = Path(__file__).parent
    project_root = script_dir.parent
    assets_dir = project_root / args.path

    if not assets_dir.exists():
        print(f"❌ 目录不存在: {assets_dir}")
        return

    # 支持的图片格式
    if args.to_webp:
        # 转换模式：只处理非 WebP 图片
        image_extensions = {".png", ".jpg", ".jpeg"}
        mode_desc = "WebP 转换"
    else:
        # 压缩模式：处理所有图片
        image_extensions = {".png", ".jpg", ".jpeg", ".webp"}
        mode_desc = "压缩"

    # 扫描图片
    images = [
        f
        for f in assets_dir.rglob("*")
        if f.is_file() and f.suffix.lower() in image_extensions
    ]

    if not images:
        print(f"📁 {assets_dir} 下没有找到可处理的图片")
        return

    print(f"📁 扫描目录: {assets_dir}")
    print(f"🔧 模式: {mode_desc}")
    print(f"🔍 找到 {len(images)} 张图片\n")

    # 统计
    total_original = 0.0
    total_new = 0.0
    processed_count = 0

    for img_path in sorted(images):
        size_kb = get_file_size_kb(img_path)
        relative_path = img_path.relative_to(project_root)

        # 检查大小限制（除非使用 --all）
        if not args.all and size_kb <= args.max_size:
            print(f"  ✓ {relative_path}: {format_size(size_kb)} (跳过)")
            continue

        if args.dry_run:
            action = "将转为 WebP" if args.to_webp else "将被压缩"
            print(f"  📦 {relative_path}: {format_size(size_kb)} ({action})")
            continue

        try:
            if args.to_webp:
                # WebP 转换
                success, new_path, original, new_size = convert_to_webp(
                    img_path,
                    quality=args.quality,
                    max_dimension=args.max_dimension,
                    delete_original=args.delete,
                )
                new_relative = new_path.relative_to(project_root)
                if success:
                    reduction = (1 - new_size / original) * 100
                    total_original += original
                    total_new += new_size
                    processed_count += 1
                    delete_note = " (已删除原文件)" if args.delete else ""
                    print(
                        f"  ✅ {relative_path} → {new_relative.name}: "
                        f"{format_size(original)} → {format_size(new_size)} "
                        f"(-{reduction:.1f}%){delete_note}"
                    )
            else:
                # 普通压缩
                success, original, new_size = compress_image(
                    img_path,
                    quality=args.quality,
                    max_dimension=args.max_dimension,
                )
                if success:
                    reduction = (1 - new_size / original) * 100
                    total_original += original
                    total_new += new_size
                    processed_count += 1
                    print(
                        f"  ✅ {relative_path}: "
                        f"{format_size(original)} → {format_size(new_size)} "
                        f"(-{reduction:.1f}%)"
                    )
        except Exception as e:
            print(f"  ❌ {relative_path}: 处理失败 - {e}")

    # 总结
    if processed_count > 0 and not args.dry_run:
        total_reduction = (1 - total_new / total_original) * 100
        print(f"\n📊 处理完成!")
        print(f"   处理: {processed_count} 张图片")
        print(
            f"   节省: {format_size(total_original - total_new)} "
            f"(-{total_reduction:.1f}%)"
        )
        if args.to_webp and not args.delete:
            print("\n💡 提示: 使用 --delete 参数可在转换后自动删除原文件")


if __name__ == "__main__":
    main()
