export PATH="$HOME/.local/bin:$PATH"

[ -f ~/.fzf.zsh ] && source ~/.fzf.zsh
source $HOMEBREW_PREFIX/opt/zinit/zinit.zsh
zinit load sunlei/zsh-ssh
