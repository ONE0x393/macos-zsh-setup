#!/bin/bash

set -e # 오류 발생 시 스크립트 종료

# ──────────────────────────────────────────────
# 색상 및 심볼 정의
# ──────────────────────────────────────────────
RESET="\033[0m"
BOLD="\033[1m"
GREEN="\033[0;32m"
CYAN="\033[0;36m"
YELLOW="\033[0;33m"
DIM="\033[2m"

# ──────────────────────────────────────────────
# 인터랙티브 체크박스 선택 함수
# 사용법: multiselect RESULT_VAR "label1|pkg1" "label2|pkg2" ...
# ──────────────────────────────────────────────
multiselect() {
    local result_var="$1"
    shift
    local options=("$@")
    local count=${#options[@]}
    local selected=()
    local cursor=0
    # 전체 선택/해제 행은 인덱스 0, 실제 패키지는 1~count
    local total=$((count + 1))
    local all_selected=false  # 전체 선택 상태

    # 초기 선택 상태: 전체 해제
    for ((i = 0; i < count; i++)); do
        selected+=(false)
    done

    # 터미널 정리 후 종료하는 공통 cleanup 함수
    _multiselect_cleanup() {
        tput cud "$total" 2>/dev/null  # 목록 아래로 커서 이동
        tput cnorm                     # 커서 복원
        echo ""
    }

    # Ctrl+C: 정리 후 스크립트 전체 종료
    _multiselect_abort() {
        _multiselect_cleanup
        echo -e "\n스크립트를 종료합니다."
        exit 1
    }

    # 커서 숨김 및 시그널 핸들러 등록
    tput civis
    trap '_multiselect_abort' INT TERM
    trap '_multiselect_cleanup' EXIT

    # 화면 그리기 함수
    draw() {
        # 0번 행: 전체 선택/해제 토글
        if [ "$cursor" -eq 0 ]; then
            printf "\r  ${BOLD}${CYAN}▶${RESET} "
        else
            printf "\r    "
        fi
        if [ "$all_selected" = true ]; then
            printf "${GREEN}[✓]${RESET} ${BOLD}전체 선택/해제${RESET}\n"
        else
            printf "${DIM}[ ]${RESET} ${BOLD}전체 선택/해제${RESET}\n"
        fi

        # 1번 행 이후: 개별 패키지
        for ((i = 0; i < count; i++)); do
            local label="${options[$i]%%|*}"
            local row=$((i + 1))
            if [ "$row" -eq "$cursor" ]; then
                printf "\r  ${BOLD}${CYAN}▶${RESET} "
            else
                printf "\r    "
            fi
            if [ "${selected[$i]}" = true ]; then
                printf "${GREEN}[✓]${RESET} %s\n" "$label"
            else
                printf "${DIM}[ ]${RESET} %s\n" "$label"
            fi
        done
        # 커서를 목록 위로 되돌림
        tput cuu "$total"
    }

    draw
    while true; do
        # 키 입력 읽기 (ESC 시퀀스 포함)
        IFS= read -rsn1 key
        if [[ "$key" == $'\x1b' ]]; then
            read -rsn2 -t 0.1 key2
            key="${key}${key2}"
        fi

        case "$key" in
            $'\x1b[A' | k)  # 위 방향키
                ((cursor--)) || cursor=$((total - 1))
                ;;
            $'\x1b[B' | j)  # 아래 방향키
                cursor=$(( (cursor + 1) % total ))
                ;;
            ' ')            # 스페이스바: 토글
                if [ "$cursor" -eq 0 ]; then
                    # 전체 선택/해제
                    if [ "$all_selected" = true ]; then
                        all_selected=false
                        for ((i = 0; i < count; i++)); do selected[$i]=false; done
                    else
                        all_selected=true
                        for ((i = 0; i < count; i++)); do selected[$i]=true; done
                    fi
                else
                    local pkg_idx=$((cursor - 1))
                    if [ "${selected[$pkg_idx]}" = true ]; then
                        selected[$pkg_idx]=false
                        all_selected=false  # 하나라도 해제되면 전체선택 해제
                    else
                        selected[$pkg_idx]=true
                        # 모두 선택됐으면 전체선택 체크
                        local all=true
                        for ((i = 0; i < count; i++)); do
                            [ "${selected[$i]}" = false ] && all=false && break
                        done
                        all_selected=$all
                    fi
                fi
                ;;
            '')             # 엔터: 확정
                break
                ;;
        esac
        draw
    done

    # 정상 종료 시 트랩 해제 후 직접 정리
    trap - EXIT INT TERM
    _multiselect_cleanup

    # 선택된 패키지 이름만 result_var에 배열로 저장
    local result=()
    for ((i = 0; i < count; i++)); do
        if [ "${selected[$i]}" = true ]; then
            result+=("${options[$i]##*|}")
        fi
    done
    eval "$result_var=(\"\${result[@]}\")"
}

# ──────────────────────────────────────────────
# 시작 배너
# ──────────────────────────────────────────────
echo ""
echo -e "${BOLD}==========================================${RESET}"
echo -e "${BOLD}  macOS 개발 환경 및 Zsh 구성 스크립트${RESET}"
echo -e "${BOLD}==========================================${RESET}"
echo ""

# ──────────────────────────────────────────────
# 1. 패키지 선택 화면
# ──────────────────────────────────────────────
echo -e "${BOLD}설치할 패키지를 선택하세요.${RESET}"
echo -e "${DIM}↑↓ 이동  |  Space 선택/해제  |  Enter 확정  |  Ctrl+C 종료${RESET}"
echo ""

# "표시 레이블|brew 패키지명" 형식
PACKAGE_OPTIONS=(
    "zsh                  - Z Shell (기본 쉘 변경용)|zsh"
    "fastfetch            - 시스템 정보 표시 도구|fastfetch"
    "fzf                  - 퍼지 파인더|fzf"
    "neovim               - Neovim 텍스트 에디터|neovim"
    "bat                  - cat 대체 (구문 강조)|bat"
    "ripgrep              - 빠른 grep 대체 (rg)|ripgrep"
    "fd                   - 빠른 find 대체|fd"
    "dust                 - du 대체 (디스크 사용량)|dust"
    "duf                  - df 대체 (디스크 여유 공간)|duf"
    "btop                 - top 대체 (리소스 모니터)|btop"
    "grc                  - grep/ping 등 컬러 출력|grc"
    "terraform            - IaC 도구|hashicorp/tap/terraform"
    "nvm                  - Node.js 버전 관리자|nvm"
    "jenv                 - Java 버전 관리자|jenv"
)

multiselect SELECTED_PACKAGES "${PACKAGE_OPTIONS[@]}"

echo ""
if [ ${#SELECTED_PACKAGES[@]} -eq 0 ]; then
    echo -e "${YELLOW}선택된 패키지가 없습니다. 패키지 설치를 건너뜁니다.${RESET}"
else
    echo -e "${BOLD}선택된 패키지:${RESET}"
    for pkg in "${SELECTED_PACKAGES[@]}"; do
        echo -e "  ${GREEN}✓${RESET} $pkg"
    done
fi
echo ""

# ──────────────────────────────────────────────
# 2. Homebrew 설치 확인 및 설치
# ──────────────────────────────────────────────
if ! command -v brew &>/dev/null; then
    echo -e "${CYAN}▶ Homebrew가 설치되어 있지 않습니다. 설치를 시작합니다...${RESET}"
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

    if [[ "$(uname -m)" == "arm64" ]]; then
        eval "$(/opt/homebrew/bin/brew shellenv)"
    else
        eval "$(/usr/local/bin/brew shellenv)"
    fi
else
    echo -e "${GREEN}✓${RESET} Homebrew가 이미 설치되어 있습니다."
fi

# ──────────────────────────────────────────────
# 3. 선택된 패키지 설치
# ──────────────────────────────────────────────
if [ ${#SELECTED_PACKAGES[@]} -gt 0 ]; then
    echo ""
    echo -e "${CYAN}▶ Homebrew 패키지를 설치합니다...${RESET}"
    brew update

    for package in "${SELECTED_PACKAGES[@]}"; do
        # tap이 포함된 패키지(예: hashicorp/tap/terraform)는 list 체크 시 마지막 세그먼트 사용
        local_name="${package##*/}"
        if ! brew list "$local_name" &>/dev/null; then
            echo "--> 설치 중: $package"
            brew install "$package"
        else
            echo "--> 이미 설치됨: $package"
        fi
    done
fi

# ──────────────────────────────────────────────
# 4. 기본 쉘을 Homebrew Zsh로 변경
#    (zsh가 선택된 경우에만)
# ──────────────────────────────────────────────
if printf '%s\n' "${SELECTED_PACKAGES[@]}" | grep -qx "zsh"; then
    BREW_ZSH="$(brew --prefix)/bin/zsh"
    if [ "$SHELL" != "$BREW_ZSH" ]; then
        echo ""
        echo -e "${CYAN}▶ 기본 쉘을 Homebrew Zsh로 변경합니다. (맥 비밀번호 입력 필요)${RESET}"
        if ! grep -q "$BREW_ZSH" /etc/shells; then
            echo "$BREW_ZSH" | sudo tee -a /etc/shells
        fi
        chsh -s "$BREW_ZSH"
    else
        echo -e "${GREEN}✓${RESET} 기본 쉘이 이미 Homebrew Zsh입니다."
    fi
fi

# ──────────────────────────────────────────────
# 5. Oh My Zsh 설치
# ──────────────────────────────────────────────
echo ""
if [ ! -d "$HOME/.oh-my-zsh" ]; then
    echo -e "${CYAN}▶ Oh My Zsh를 설치합니다...${RESET}"
    sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended --keep-zshrc
else
    echo -e "${GREEN}✓${RESET} Oh My Zsh가 이미 설치되어 있습니다."
fi

# ──────────────────────────────────────────────
# 6. Powerlevel10k 테마 다운로드
# ──────────────────────────────────────────────
P10K_DIR="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/themes/powerlevel10k"
if [ ! -d "$P10K_DIR" ]; then
    echo -e "${CYAN}▶ Powerlevel10k 테마를 다운로드합니다...${RESET}"
    git clone --depth=1 https://github.com/romkatv/powerlevel10k.git "$P10K_DIR"
else
    echo -e "${GREEN}✓${RESET} Powerlevel10k 테마가 이미 존재합니다."
fi

# ──────────────────────────────────────────────
# 7. LazyVim 설치 및 설정
#    (neovim이 선택된 경우에만)
# ──────────────────────────────────────────────
if printf '%s\n' "${SELECTED_PACKAGES[@]}" | grep -qx "neovim"; then
    echo ""
    NVIM_CONFIG_DIR="$HOME/.config/nvim"
    if [ ! -d "$NVIM_CONFIG_DIR" ] || [ -z "$(ls -A "$NVIM_CONFIG_DIR" 2>/dev/null)" ]; then
        echo -e "${CYAN}▶ LazyVim을 설치합니다...${RESET}"
        for dir in "$HOME/.config/nvim" "$HOME/.local/share/nvim" "$HOME/.local/state/nvim" "$HOME/.cache/nvim"; do
            if [ -d "$dir" ]; then
                echo "--> 기존 디렉토리 백업: $dir -> ${dir}.bak"
                mv "$dir" "${dir}.bak"
            fi
        done
        git clone https://github.com/LazyVim/starter "$NVIM_CONFIG_DIR"
        rm -rf "$NVIM_CONFIG_DIR/.git"
        echo -e "${GREEN}✓${RESET} LazyVim 설치 완료."
    else
        echo -e "${GREEN}✓${RESET} Neovim 설정 디렉토리가 이미 존재합니다. LazyVim 설치를 건너뜁니다."
    fi

    # LazyVim 커스텀 옵션 설정 (relativenumber: false)
    LAZYVIM_OPTIONS_FILE="$NVIM_CONFIG_DIR/lua/plugins/options.lua"
    mkdir -p "$(dirname "$LAZYVIM_OPTIONS_FILE")"
    if [ ! -f "$LAZYVIM_OPTIONS_FILE" ]; then
        echo -e "${CYAN}▶ LazyVim 커스텀 옵션 파일을 생성합니다...${RESET}"
        cat <<'LUAEOF' >"$LAZYVIM_OPTIONS_FILE"
-- LazyVim 커스텀 옵션 오버라이드
return {
  {
    "LazyVim/LazyVim",
    opts = function()
      vim.opt.relativenumber = false
    end,
  },
}
LUAEOF
        echo -e "${GREEN}✓${RESET} LazyVim 옵션 파일 생성 완료: $LAZYVIM_OPTIONS_FILE"
    else
        echo -e "${GREEN}✓${RESET} LazyVim 옵션 파일이 이미 존재합니다."
    fi
fi

# ──────────────────────────────────────────────
# 8. .zshrc 설정 파일 작성 (기존 파일 백업)
# ──────────────────────────────────────────────
echo ""
ZSHRC="$HOME/.zshrc"
if [ -f "$ZSHRC" ]; then
    echo -e "${CYAN}▶ 기존 .zshrc 파일을 .zshrc.bak으로 백업합니다.${RESET}"
    cp "$ZSHRC" "${ZSHRC}.bak"
fi

echo -e "${CYAN}▶ 요청하신 구성을 .zshrc에 반영합니다...${RESET}"
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

# jenv 설정
export PATH="$HOME/.jenv/bin:$PATH"
if command -v jenv &>/dev/null; then
  eval "$(jenv init -)"
fi
EOF

echo ""
echo -e "${BOLD}==========================================${RESET}"
echo -e "${GREEN}${BOLD}  모든 설치와 설정이 완료되었습니다!${RESET}"
echo -e "${BOLD}==========================================${RESET}"
echo -e "  새 터미널 창을 열거나 ${BOLD}exec zsh${RESET} 를 실행하세요."
echo -e "  처음 시작 시 Powerlevel10k 설정 화면이 나타납니다."
echo ""
