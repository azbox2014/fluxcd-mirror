#!/usr/bin/with-contenv bash

CONFIG_DIR="/config"
ZSHRC="${CONFIG_DIR}/.zshrc"

if [ ! -f "$ZSHRC" ]; then
  echo ">>> First run: initializing zsh config..."

  cat <<'EOF' > "$ZSHRC"
export ZSH=/opt/oh-my-zsh

ZSH_THEME="powerlevel10k/powerlevel10k"

plugins=(
  git
  ssh
  timer
  qrcode
  zsh-autosuggestions
  z
)

source $ZSH/oh-my-zsh.sh

# p10k（如果存在）
[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh
EOF
  # 权限修复
  chown abc:abc "$ZSHRC"
  chown abc:abc $CONFIG_DIR

  echo ">>> Zsh initialized."
else
  echo ">>> Zsh already configured, skipping."
fi