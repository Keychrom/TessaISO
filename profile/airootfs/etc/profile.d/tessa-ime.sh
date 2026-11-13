# SPDX-License-Identifier: GPL-3.0-or-later
# Leave GTK_IM_MODULE unset so GTK picks Wayland text-input or XIM.
QT_IM_MODULE=fcitx
XMODIFIERS=@im=fcitx
SDL_IM_MODULE=fcitx
export QT_IM_MODULE XMODIFIERS SDL_IM_MODULE
