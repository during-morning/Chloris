#pragma once
#include <flutter/binary_messenger.h>
#include <windows.h>
void RegisterMusicMediaSession(flutter::BinaryMessenger* messenger, HWND window);
void DisposeMusicMediaSession();
