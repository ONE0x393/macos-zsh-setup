#!/bin/bash

set -e # 오류 발생 시 스크립트 종료

echo "=========================================="
echo " macOS 개발 환경 및 Zsh 구성 스크립트를 시작합니다."
echo "=========================================="

# 1. Homebrew 설치 확인 및 설치
if ! command -v brew &>/dev/null; then
    echo " Homebrew가 설치되어 있지 않습니다. 설치를 시작합니다..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

    # Apple Silicon 및 Intel Mac 환경에 맞춰 Homebrew 경로 설정
    if [[ "$(uname -m)" == "arm64" ]]; then
        eval "$(/opt/homebrew/bin/brew shellenv)"
    else
        eval "$(/usr/local/bin/brew shellenv)"
    fi
else
    echo " Homebrew가 이미 설치되어 있습니다."
fi

# 2. 필요한 패키지 및 CLI 도구 설치 (.zshrc 설정 기준)
echo " Homebrew를 통해 Zsh 및 의존성 도구들을 설치합니다..."
brew update

PACKAGES=(
    zsh
    fastfetch
    fzf
    neovim
    bat
    ripgrep
    fd
    dust
    duf
    btop
    grc
    hashicorp/tap/terraform
    nvm
    jenv
)

for package in "${PACKAGES[@]}"; do
    if ! brew list "$package" &>/dev/null; then
        echo "--> 설치 중: $package"
        brew install "$package"
    else
        echo "--> 이미 설치됨: $package"
    fi
done

# 3. 기본 쉘을 Homebrew Zsh로 변경
BREW_ZSH="$(brew --prefix)/bin/zsh"
if [ "$SHELL" != "$BREW_ZSH" ]; then
    echo " 기본 쉘을 Homebrew Zsh로 변경합니다. (맥 비밀번호 입력 필요)"
    if ! grep -q "$BREW_ZSH" /etc/shells; then
        echo "$BREW_ZSH" | sudo tee -a /etc/shells
    fi
    chsh -s "$BREW_ZSH"
fi

# 4. Oh My Zsh 설치
if [ ! -d "$HOME/.oh-my-zsh" ]; then
    echo " Oh My Zsh를 설치합니다..."
    # --unattended: 설치 후 자동으로 zsh 진입 방지, --keep-zshrc: 기존 파일 유지
    sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended --keep-zshrc
else
    echo " Oh My Zsh가 이미 설치되어 있습니다."
fi

# 5. Powerlevel10k 테마 다운로드
P10K_DIR="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/themes/powerlevel10k"
if [ ! -d "$P10K_DIR" ]; then
    echo " Powerlevel10k 테마를 다운로드합니다..."
    git clone --depth=1 https://github.com/romkatv/powerlevel10k.git "$P10K_DIR"
else
    echo " Powerlevel10k 테마가 이미 존재합니다."
fi

# 6. .zshrc 설정 파일 작성 (기존 파일 백업)
ZSHRC="$HOME/.zshrc"
if [ -f "$ZSHRC" ]; then
    echo " 기존 .zshrc 파일을 .zshrc.bak으로 백업합니다."
    cp "$ZSHRC" "${ZSHRC}.bak"
fi

echo " 요청하신 구성을 .zshrc에 반영합니다..."
cat <<'EOF' >"$ZSHRC"
# FASTFETCH
if [[ $- == *i* ]] && command -v fastfetch &>/dev/null; then
  fastfetch
fi

# Enable Powerlevel10k instant prompt. Should stay close to the top of ~/.zshrc.
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

# Path to your Oh My Zsh installation.
export ZSH="$HOME/.oh-my-zsh"

# Set name of the theme to load
ZSH_THEME="powerlevel10k/powerlevel10k"

# Plugins
plugins=(
    git
    fzf
)

source $ZSH/oh-my-zsh.sh

# User configuration
export LANG=ko_KR.UTF-8

# Aliases
alias vim="nvim"
alias ll="ls -alhF"
alias l="ls -lhF"
alias cat="bat -p"
alias grep="rg"
alias find="fd"
alias du="dust -rb"
alias df="duf"
alias top="btop"
alias lssh="lazyssh"

alias ip="ip -c"

alias grep="grc grep"
alias ifconfig="grc ifconfig"
alias ping="grc ping"
alias netstat="grc netstat"
alias lsof="grc lsof"

alias tf="terraform"

# To customize prompt, run `p10k configure` or edit ~/.p10k.zsh.
[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh

# NVM 설정
export NVM_DIR="$HOME/.nvm"
if [ -f "$(brew --prefix nvm)/nvm.sh" ]; then
  source "$(brew --prefix nvm)/nvm.sh"
fi

# jEnv 설정
export PATH="$HOME/.jenv/bin:$PATH"
if command -v jenv &>/dev/null; then
  eval "$(jenv init -)"
fi
EOF

echo "=========================================="
echo " 모든 설치와 설정이 완료되었습니다!"
echo " 새 터미널 창을 열거나 'exec zsh'를 실행하세요."
echo " 처음 시작 시 Powerlevel10k 설정 화면이 나타납니다."
echo "=========================================="