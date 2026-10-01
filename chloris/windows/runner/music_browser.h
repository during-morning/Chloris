#pragma once
#include <flutter/binary_messenger.h>
#include <windows.h>
void RegisterMusicBrowser(flutter::BinaryMessenger* messenger, HWND window);
void DisposeMusicBrowser();
