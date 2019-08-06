```bash
# 基本用法
./git-file-downloader.sh -r https://github.com/user/repo.git -d ./downloads

# 带更多选项
./git-file-downloader.sh \
  -r https://github.com/user/repo.git \
  -d ./my-downloads \
  --max-retries 5 \
  --retry-delay 10
```

```bash
# 从中断处继续下载
./git-file-downloader.sh --resume

# 重新开始下载
./git-file-downloader.sh --reset
```