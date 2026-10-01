#include "music_browser.h"
#include <flutter/method_channel.h>
#include <flutter/standard_method_codec.h>
#include <WebView2.h>
#include <wrl.h>
#include <commctrl.h>
#include <filesystem>
#include <map>
#include <memory>
#include <string>
#include <regex>
#include <algorithm>
#include <cctype>
using Microsoft::WRL::ComPtr;
using Microsoft::WRL::Callback;
namespace {
struct Session;
std::map<std::string,std::shared_ptr<Session>> sessions;
std::map<std::wstring,ComPtr<ICoreWebView2Environment5>> cleanup_waiters;
std::string escaped(const std::string& value);
std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>> channel;
HWND window_handle=nullptr;
std::wstring wide(const std::string& text){if(text.empty())return {};int n=MultiByteToWideChar(CP_UTF8,0,text.data(),static_cast<int>(text.size()),nullptr,0);std::wstring s(n,L'\0');MultiByteToWideChar(CP_UTF8,0,text.data(),static_cast<int>(text.size()),s.data(),n);return s;}
std::string narrow(const wchar_t* s){if(!s)return {};int n=WideCharToMultiByte(CP_UTF8,0,s,-1,nullptr,0,nullptr,nullptr);std::string v(n,'\0');WideCharToMultiByte(CP_UTF8,0,s,-1,v.data(),n,nullptr,nullptr);if(!v.empty())v.pop_back();return v;}
std::string field(const flutter::EncodableMap& map,const char* key){auto i=map.find(flutter::EncodableValue(key));return i!=map.end() && std::holds_alternative<std::string>(i->second)?std::get<std::string>(i->second):"";}
struct Session {
  std::string id,script,url,html,capture;
  std::map<std::string,std::string> headers;
  ComPtr<ICoreWebView2Environment> environment;
  std::wstring folder;
  std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result;
  ComPtr<ICoreWebView2Controller> controller;
  ComPtr<ICoreWebView2> web;
  DWORD began=GetTickCount();bool finished=false,inflight=false;
  void finish(std::string value={},std::string error={}) {
    if(finished)return;auto keep=sessions[id];finished=true;KillTimer(window_handle,reinterpret_cast<UINT_PTR>(this));
    ComPtr<ICoreWebView2Environment5> environment5;if(environment)environment.As(&environment5);
    if(environment5){const auto pending_folder=folder;cleanup_waiters[pending_folder]=environment5;EventRegistrationToken exit_token;
      environment5->add_BrowserProcessExited(Callback<ICoreWebView2BrowserProcessExitedEventHandler>([pending_folder](ICoreWebView2Environment*,ICoreWebView2BrowserProcessExitedEventArgs*){
        std::error_code error;std::filesystem::remove_all(pending_folder,error);cleanup_waiters.erase(pending_folder);return S_OK;
      }).Get(),&exit_token);
    }
    if(controller)controller->Close();web.Reset();controller.Reset();environment.Reset();
    std::error_code cleanup_error;std::filesystem::remove_all(folder,cleanup_error);
    if(!error.empty())result->Error("browser",error);else if(value.empty())result->Success();else result->Success(flutter::EncodableValue(value));
    sessions.erase(id);
  }
  void tick(){
    if(finished)return;if(GetTickCount()-began>20000){finish({},"网页解析超时");return;}if(!web || inflight)return;
    inflight=true;const auto weak=std::weak_ptr<Session>(sessions[id]);
    web->ExecuteScript(wide(script).c_str(),Callback<ICoreWebView2ExecuteScriptCompletedHandler>([weak](HRESULT,LPCWSTR text){if(auto s=weak.lock()){
      s->inflight=false;if(s->finished)return;const auto json=narrow(text);
      if(json.size()>2 && json.front()=='"') {
        // WebView2 serializes the JS string. Let Dart unwrap this outer JSON.
        s->inflight=true;ComPtr<ICoreWebView2_2> web2;s->web.As(&web2);ComPtr<ICoreWebView2CookieManager> cookies;if(web2)web2->get_CookieManager(&cookies);
        if(!cookies){s->finish("{\"serialized\":"+json+"}");return S_OK;}
        LPWSTR source=nullptr;s->web->get_Source(&source);auto current=narrow(source);CoTaskMemFree(source);if(current.find("http")!=0)current=s->url;
        cookies->GetCookies(wide(current).c_str(),Callback<ICoreWebView2GetCookiesCompletedHandler>([weak,json](HRESULT,ICoreWebView2CookieList* list){auto s=weak.lock();if(!s || s->finished)return S_OK;
          std::string header;UINT count=0;if(list)list->get_Count(&count);for(UINT i=0;i<count;i++){ComPtr<ICoreWebView2Cookie> cookie;list->GetValueAtIndex(i,&cookie);if(!cookie)continue;LPWSTR name=nullptr,value=nullptr;cookie->get_Name(&name);cookie->get_Value(&value);if(!header.empty())header+="; ";header+=narrow(name)+"="+narrow(value);CoTaskMemFree(name);CoTaskMemFree(value);}
          s->finish("{\"serialized\":"+json+",\"nativeCookie\":\""+escaped(header)+"\"}");return S_OK;
        }).Get());
      }
    }return S_OK;}).Get());
  }
};
void CALLBACK timer(HWND,UINT,UINT_PTR id,DWORD){for(const auto& pair:sessions)if(reinterpret_cast<UINT_PTR>(pair.second.get())==id){auto s=pair.second;s->tick();return;}}
std::string escaped(const std::string& value){std::string out;for(char c:value){if(c=='\\' || c=='"')out+='\\';if(c=='\n'){out+="\\n";}else if(c=='\r'){out+="\\r";}else out+=c;}return out;}
}
void RegisterMusicBrowser(flutter::BinaryMessenger* messenger,HWND window){
  window_handle=window;
  channel=std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(messenger,"chloris/browser",&flutter::StandardMethodCodec::GetInstance());
  channel->SetMethodCallHandler([](const auto& call,auto result){
    if(!call.arguments() || !std::holds_alternative<flutter::EncodableMap>(*call.arguments())){result->Error("browser","解析参数无效");return;}
    const auto& args=std::get<flutter::EncodableMap>(*call.arguments());const auto id=field(args,"id");
    if(call.method_name()=="close"){auto it=sessions.find(id);if(it!=sessions.end())it->second->finish();result->Success();return;}
    if(call.method_name()!="run"){result->NotImplemented();return;}
    if(sessions.size()>=2){result->Error("browser_busy","动态解析队列已满");return;}
    auto s=std::make_shared<Session>();s->id=id;s->url=field(args,"url");s->html=field(args,"html");s->script=field(args,"script");s->capture=field(args,"capture");s->result=std::move(result);sessions[id]=s;
    auto raw=args.find(flutter::EncodableValue("headers"));if(raw!=args.end() && std::holds_alternative<flutter::EncodableMap>(raw->second)){for(const auto& pair:std::get<flutter::EncodableMap>(raw->second))if(std::holds_alternative<std::string>(pair.first) && std::holds_alternative<std::string>(pair.second))s->headers[std::get<std::string>(pair.first)]=std::get<std::string>(pair.second);}
    SetTimer(window_handle,reinterpret_cast<UINT_PTR>(s.get()),250,timer);

    const auto weak=std::weak_ptr<Session>(s);
    const auto folder=s->folder=(std::filesystem::temp_directory_path()/L"ChlorisBrowser"/wide(id)).wstring();
    const HRESULT started=CreateCoreWebView2EnvironmentWithOptions(nullptr,folder.c_str(),nullptr,
      Callback<ICoreWebView2CreateCoreWebView2EnvironmentCompletedHandler>([weak](HRESULT hr,ICoreWebView2Environment* environment){
        auto s=weak.lock();if(!s || s->finished)return S_OK;if(FAILED(hr)||!environment){s->finish({},"WebView2 Runtime 未安装");return S_OK;}
        s->environment=environment;environment->CreateCoreWebView2Controller(window_handle,Callback<ICoreWebView2CreateCoreWebView2ControllerCompletedHandler>([weak](HRESULT hr,ICoreWebView2Controller* controller){
          auto s=weak.lock();if(!s || s->finished){if(controller)controller->Close();return S_OK;}if(FAILED(hr)||!controller){s->finish({},"WebView2 创建失败");return S_OK;}
          s->controller=controller;controller->get_CoreWebView2(&s->web);controller->put_IsVisible(FALSE);RECT bounds{0,0,1,1};controller->put_Bounds(bounds);
          ComPtr<ICoreWebView2Settings> settings;s->web->get_Settings(&settings);ComPtr<ICoreWebView2Settings2> settings2;settings.As(&settings2);
          ComPtr<ICoreWebView2_2> web2;s->web.As(&web2);ComPtr<ICoreWebView2CookieManager> cookies;if(web2)web2->get_CookieManager(&cookies);
          std::smatch match;std::regex_search(s->url,match,std::regex(R"(^https?://([^/:]+))"));const auto domain=match.size()>1?match[1].str():"";
          for(const auto& pair:s->headers){std::string name=pair.first;std::transform(name.begin(),name.end(),name.begin(),[](unsigned char c){return static_cast<char>(std::tolower(c));});
            if(name=="user-agent" && settings2)settings2->put_UserAgent(wide(pair.second).c_str());
            if(name=="cookie" && cookies){size_t at=0;while(at<pair.second.size()){const auto end=pair.second.find(';',at);const auto part=pair.second.substr(at,end==std::string::npos?end:end-at);const auto split=part.find('=');if(split!=std::string::npos){const auto first=part.find_first_not_of(' ');ComPtr<ICoreWebView2Cookie> cookie;cookies->CreateCookie(wide(part.substr(first,split-first)).c_str(),wide(part.substr(split+1)).c_str(),wide(domain).c_str(),L"/",&cookie);if(cookie)cookies->AddOrUpdateCookie(cookie.Get());}if(end==std::string::npos)break;at=end+1;}}
          }
          EventRegistrationToken resources;
          s->web->AddWebResourceRequestedFilter(L"*",COREWEBVIEW2_WEB_RESOURCE_CONTEXT_ALL);
          s->web->add_WebResourceRequested(Callback<ICoreWebView2WebResourceRequestedEventHandler>([weak](ICoreWebView2*,ICoreWebView2WebResourceRequestedEventArgs* args){auto s=weak.lock();if(s && !s->finished){ComPtr<ICoreWebView2WebResourceRequest> req;args->get_Request(&req);LPWSTR raw=nullptr;req->get_Uri(&raw);
            const std::string js="window.__chlorisResources && window.__chlorisResources.push({url:\""+escaped(narrow(raw))+"\",options:{}})";CoTaskMemFree(raw);s->web->ExecuteScript(wide(js).c_str(),nullptr);}return S_OK;}).Get(),&resources);
          s->web->AddScriptToExecuteOnDocumentCreated(wide(s->capture).c_str(),Callback<ICoreWebView2AddScriptToExecuteOnDocumentCreatedCompletedHandler>([weak](HRESULT,LPCWSTR){auto s=weak.lock();if(s && !s->finished){
            if(s->html.empty()){
              ComPtr<ICoreWebView2_2> web2;s->web.As(&web2);ComPtr<ICoreWebView2Environment2> env2;s->environment.As(&env2);
              std::wstring headers;for(const auto& h:s->headers)headers+=wide(h.first+": "+h.second+"\r\n");
              ComPtr<ICoreWebView2WebResourceRequest> request;if(env2)env2->CreateWebResourceRequest(wide(s->url).c_str(),L"GET",nullptr,headers.c_str(),&request);
              if(web2 && request)web2->NavigateWithWebResourceRequest(request.Get());else s->web->Navigate(wide(s->url).c_str());
            }else {std::string base=s->url;size_t pos=0;while((pos=base.find('"',pos))!=std::string::npos){base.replace(pos,1,"&quot;");pos+=6;}s->web->NavigateToString(wide("<base href=\""+base+"\">"+s->html).c_str());}
          }return S_OK;}).Get());
          SetTimer(window_handle,reinterpret_cast<UINT_PTR>(s.get()),250,timer);return S_OK;
        }).Get());return S_OK;
      }).Get());
    if(FAILED(started))s->finish({},"WebView2 Runtime 未安装");
  });
}
void DisposeMusicBrowser(){while(!sessions.empty())sessions.begin()->second->finish();channel.reset();}
