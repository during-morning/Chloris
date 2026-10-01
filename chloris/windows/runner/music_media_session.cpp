#include "music_media_session.h"
#include <flutter/method_channel.h>
#include <flutter/standard_method_codec.h>
#include <winrt/Windows.Media.h>
#include <winrt/Windows.Foundation.h>
#include <systemmediatransportcontrolsinterop.h>
#include <memory>
#include <commctrl.h>
using namespace winrt;
using namespace Windows::Media;
namespace {
std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>> channel;
SystemMediaTransportControls controls{nullptr};
event_token buttons{}, seek{};
HWND target_window=nullptr;
const UINT WM_MUSIC_COMMAND=WM_APP+91;
LRESULT CALLBACK MusicWindowProc(HWND h,UINT msg,WPARAM w,LPARAM l,UINT_PTR,DWORD_PTR) {
  if(msg==WM_MUSIC_COMMAND && channel) {
    const char* method=nullptr;
    switch(static_cast<SystemMediaTransportControlsButton>(w)) {
      case SystemMediaTransportControlsButton::Play:method="play";break;
      case SystemMediaTransportControlsButton::Pause:method="pause";break;
      case SystemMediaTransportControlsButton::Stop:method="stop";break;
      case SystemMediaTransportControlsButton::Next:method="next";break;
      case SystemMediaTransportControlsButton::Previous:method="previous";break;
      default:break;
    }
    if(method)channel->InvokeMethod(method,nullptr);return 0;
  }
  if(msg==WM_MUSIC_COMMAND+1 && channel) {
    std::unique_ptr<int64_t> position(reinterpret_cast<int64_t*>(l));
    channel->InvokeMethod("seek",std::make_unique<flutter::EncodableValue>(*position));return 0;
  }
  return DefSubclassProc(h,msg,w,l);
}
std::string text(const flutter::EncodableMap& m,const char* key) {
  auto it=m.find(flutter::EncodableValue(key));return it!=m.end() && std::holds_alternative<std::string>(it->second)?std::get<std::string>(it->second):"";
}
bool boolean(const flutter::EncodableMap& m,const char* key) {auto it=m.find(flutter::EncodableValue(key));return it!=m.end() && std::holds_alternative<bool>(it->second) && std::get<bool>(it->second);}
int64_t number(const flutter::EncodableMap& m,const char* key) {auto it=m.find(flutter::EncodableValue(key));if(it==m.end())return 0;if(auto v=std::get_if<int64_t>(&it->second))return *v;if(auto v=std::get_if<int32_t>(&it->second))return *v;return 0;}
}
void RegisterMusicMediaSession(flutter::BinaryMessenger* messenger,HWND window) {
  target_window=window;
  SetWindowSubclass(window,MusicWindowProc,91,0);
  channel=std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(messenger,"chloris/media_session",&flutter::StandardMethodCodec::GetInstance());
  channel->SetMethodCallHandler([window](const auto& call,auto result){try {
    if(call.method_name()=="initialize") {
      if(!controls) {
        auto interop=get_activation_factory<SystemMediaTransportControls,ISystemMediaTransportControlsInterop>();
        check_hresult(interop->GetForWindow(window,guid_of<SystemMediaTransportControls>(),put_abi(controls)));
        controls.IsEnabled(true);controls.IsPlayEnabled(true);controls.IsPauseEnabled(true);controls.IsStopEnabled(true);
        buttons=controls.ButtonPressed([window](auto const&,auto const& e){PostMessage(window,WM_MUSIC_COMMAND,static_cast<WPARAM>(e.Button()),0);});
        seek=controls.PlaybackPositionChangeRequested([window](auto const&,auto const& e){auto p=new int64_t(e.RequestedPlaybackPosition().count()/10000);if(!PostMessage(window,WM_MUSIC_COMMAND+1,0,reinterpret_cast<LPARAM>(p)))delete p;});
      }
      result->Success();return;
    }
    if(call.method_name()=="update" && controls && call.arguments()) {
      const auto& m=std::get<flutter::EncodableMap>(*call.arguments());
      controls.IsNextEnabled(boolean(m,"hasNext"));controls.IsPreviousEnabled(boolean(m,"hasPrevious"));
      controls.PlaybackStatus(boolean(m,"playing")?MediaPlaybackStatus::Playing:MediaPlaybackStatus::Paused);
      const auto updater=controls.DisplayUpdater();updater.Type(MediaPlaybackType::Music);
      updater.MusicProperties().Title(to_hstring(text(m,"title")));updater.MusicProperties().Artist(to_hstring(text(m,"artist")));updater.MusicProperties().AlbumTitle(to_hstring(text(m,"album")));updater.Update();
      SystemMediaTransportControlsTimelineProperties timeline;
      timeline.StartTime(Windows::Foundation::TimeSpan(0));timeline.MinSeekTime(Windows::Foundation::TimeSpan(0));
      timeline.Position(Windows::Foundation::TimeSpan(number(m,"position")*10000));
      timeline.EndTime(Windows::Foundation::TimeSpan(number(m,"duration")*10000));timeline.MaxSeekTime(timeline.EndTime());controls.UpdateTimelineProperties(timeline);
      result->Success();return;
    }
    result->NotImplemented();
  }catch(const hresult_error& e){result->Error("media_session",to_string(e.message()));}catch(...){result->Error("media_session","Invalid media session data");}});
}
void DisposeMusicMediaSession(){if(controls){controls.ButtonPressed(buttons);controls.PlaybackPositionChangeRequested(seek);controls.IsEnabled(false);controls=nullptr;}if(target_window)RemoveWindowSubclass(target_window,MusicWindowProc,91);channel.reset();target_window=nullptr;}
