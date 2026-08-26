#!/bin/bash
#
# compress   <path>      => <path>.tar.gz
# decompress <archive>   => extracts it, dispatching on the extension

compress() {
  if [ -z "$1" ]; then
    echo "Usage: compress <file-or-directory>"
    return 1
  fi

  if [ ! -e "${1%/}" ]; then
    echo "Not found: ${1%/}"
    return 1
  fi

  tar -czf "${1%/}.tar.gz" "${1%/}" && echo "${1%/}.tar.gz"
}

decompress() {
  if [ ! -f "$1" ]; then
    echo "Usage: decompress <archive>"
    return 1
  fi

  case "$1" in
    *.tar.bz2 | *.tbz2) tar -xjf "$1" ;;
    *.tar.gz | *.tgz) tar -xzf "$1" ;;
    *.tar.xz | *.txz) tar -xJf "$1" ;;
    *.tar.zst) tar --zstd -xf "$1" ;;
    *.tar) tar -xf "$1" ;;
    *.bz2) bunzip2 "$1" ;;
    *.gz) gunzip "$1" ;;
    *.xz) unxz "$1" ;;
    *.zst) unzstd "$1" ;;
    *.zip) unzip "$1" ;;
    *.7z) 7z x "$1" ;;
    *.rar) unrar x "$1" ;;
    *)
      echo "Unknown archive format: $1"
      return 1
      ;;
  esac
}
