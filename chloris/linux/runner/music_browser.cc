#include "music_browser.h"
#include <webkit2/webkit2.h>
#include <map>
#include <memory>
#include <string>
#include <vector>
#include <cstring>
namespace {
struct Session;
std::map<std::string,std::shared_ptr<Session>> sessions;
std::string string_arg(FlValue* args,const char* name) {auto* v=fl_value_lookup_string(args,name);return v && fl_value_get_type(v)==FL_VALUE_TYPE_STRING?fl_value_get_string(v):"";}
struct Session {
  std::string id,url,script,html;
  std::vector<std::pair<std::string,std::string>> headers;
  int pending_cookies=0;
  void load(){
    if(finished)return;
    if(!html.empty()){webkit_web_view_load_html(view,html.c_str(),url.c_str());return;}
    auto* request=webkit_uri_request_new(url.c_str());auto* outgoing=webkit_uri_request_get_http_headers(request);
    for(const auto& h:headers)soup_message_headers_replace(outgoing,h.first.c_str(),h.second.c_str());
    webkit_web_view_load_request(view,request);g_object_unref(request);
  }
  FlMethodCall* call=nullptr;
  WebKitWebView* view=nullptr;
  GtkWidget* window=nullptr;
  guint poll=0,timeout=0;
  bool finished=false,inflight=false;
  ~Session(){if(call)g_object_unref(call);}
  void finish(const char* value,const char* error=nullptr){
    if(finished)return;auto keep=sessions[id];finished=true;
    if(poll){g_source_remove(poll);poll=0;}if(timeout){g_source_remove(timeout);timeout=0;}
    g_autoptr(FlMethodResponse) response=error?FL_METHOD_RESPONSE(fl_method_error_response_new("browser",error,nullptr)):
      FL_METHOD_RESPONSE(fl_method_success_response_new(value?fl_value_new_string(value):nullptr));
    fl_method_call_respond(call,response,nullptr);
    webkit_web_view_stop_loading(view);gtk_widget_destroy(window);sessions.erase(id);
  }
};
gboolean evaluate(gpointer data){
  auto* s=static_cast<Session*>(data);if(s->finished || s->inflight)return G_SOURCE_CONTINUE;s->inflight=true;
  auto* holder=new std::shared_ptr<Session>(sessions[s->id]);
  webkit_web_view_evaluate_javascript(s->view,s->script.c_str(),-1,nullptr,nullptr,nullptr,
    [](GObject* object,GAsyncResult* result,gpointer user){std::unique_ptr<std::shared_ptr<Session>> hold(static_cast<std::shared_ptr<Session>*>(user));auto s=*hold;if(s->finished)return;s->inflight=false;
      g_autoptr(GError) error=nullptr;g_autoptr(JSCValue) value=webkit_web_view_evaluate_javascript_finish(WEBKIT_WEB_VIEW(object),result,&error);
      if(value && jsc_value_is_string(value)){g_autofree gchar* text=jsc_value_to_string(value);if(text && *text){
        s->inflight=true;
        auto* cookie_holder=new std::pair<std::shared_ptr<Session>,std::string>(s,text);
        auto* context=webkit_web_view_get_context(s->view);auto* manager=webkit_web_context_get_cookie_manager(context);
        webkit_cookie_manager_get_cookies(manager,s->url.c_str(),nullptr,[](GObject* object,GAsyncResult* result,gpointer user){
          std::unique_ptr<std::pair<std::shared_ptr<Session>,std::string>> hold(static_cast<std::pair<std::shared_ptr<Session>,std::string>*>(user));auto s=hold->first;if(s->finished)return;
          g_autoptr(GError) error=nullptr;auto* cookies=webkit_cookie_manager_get_cookies_finish(WEBKIT_COOKIE_MANAGER(object),result,&error);std::string header;
          for(auto* item=cookies;item;item=item->next){auto* cookie=static_cast<SoupCookie*>(item->data);if(!header.empty())header+="; ";header+=std::string(soup_cookie_get_name(cookie))+"="+soup_cookie_get_value(cookie);}
          g_list_free_full(cookies,reinterpret_cast<GDestroyNotify>(soup_cookie_free));
          g_autoptr(JSCContext) js=jsc_context_new();g_autoptr(JSCValue) payload=jsc_value_new_from_json(js,hold->second.c_str());
          if(payload && jsc_value_is_object(payload)){g_autoptr(JSCValue) cookie=jsc_value_new_string(js,header.c_str());jsc_value_object_set_property(payload,"cookie",cookie);g_autofree gchar* body=jsc_value_to_json(payload,0);s->finish(body);}else s->finish(hold->second.c_str());
        },cookie_holder);
      }}},holder);
  return G_SOURCE_CONTINUE;
}
void handler(FlMethodChannel*,FlMethodCall* call,gpointer){
  auto* args=fl_method_call_get_args(call);if(!args || fl_value_get_type(args)!=FL_VALUE_TYPE_MAP){fl_method_call_respond_error(call,"browser","解析参数无效",nullptr,nullptr);return;}
  const std::string id=string_arg(args,"id"),method=fl_method_call_get_name(call);
  if(method=="close"){auto it=sessions.find(id);if(it!=sessions.end())it->second->finish(nullptr);fl_method_call_respond_success(call,nullptr,nullptr);return;}
  if(method!="run"){fl_method_call_respond_not_implemented(call,nullptr);return;}
  if(sessions.size()>=2){fl_method_call_respond_error(call,"browser_busy","动态解析队列已满",nullptr,nullptr);return;}
  auto s=std::make_shared<Session>();s->id=id;s->url=string_arg(args,"url");s->script=string_arg(args,"script");s->call=FL_METHOD_CALL(g_object_ref(call));sessions[id]=s;
  auto* manager=webkit_user_content_manager_new();
  auto* capture=webkit_user_script_new(string_arg(args,"capture").c_str(),WEBKIT_USER_CONTENT_INJECT_ALL_FRAMES,WEBKIT_USER_SCRIPT_INJECT_AT_DOCUMENT_START,nullptr,nullptr);
  webkit_user_content_manager_add_script(manager,capture);webkit_user_script_unref(capture);
  auto* context=webkit_web_context_new_ephemeral();
  s->view=WEBKIT_WEB_VIEW(g_object_new(WEBKIT_TYPE_WEB_VIEW,"web-context",context,"user-content-manager",manager,nullptr));g_object_unref(context);g_object_unref(manager);
  s->window=gtk_offscreen_window_new();gtk_container_add(GTK_CONTAINER(s->window),GTK_WIDGET(s->view));gtk_widget_show_all(s->window);
  g_signal_connect(s->view,"resource-load-started",G_CALLBACK(+[](WebKitWebView* view,WebKitWebResource*,WebKitURIRequest* req,gpointer){
    const char* uri=webkit_uri_request_get_uri(req);g_autofree gchar* escaped=g_strescape(uri,nullptr);
    std::string js="window.__chlorisResources && window.__chlorisResources.push({url:\""+std::string(escaped)+"\",options:{}})";
    webkit_web_view_evaluate_javascript(view,js.c_str(),-1,nullptr,nullptr,nullptr,nullptr,nullptr);
  }),nullptr);
  g_signal_connect(s->view,"web-process-terminated",G_CALLBACK(+[](WebKitWebView*,WebKitWebProcessTerminationReason,gpointer user){static_cast<Session*>(user)->finish(nullptr,"网页解析进程退出");}),s.get());
  s->html=string_arg(args,"html");auto* extra=fl_value_lookup_string(args,"headers");std::string cookie_header;
  if(extra && fl_value_get_type(extra)==FL_VALUE_TYPE_MAP)for(size_t i=0;i<fl_value_get_length(extra);i++) {auto* k=fl_value_get_map_key(extra,i);auto* v=fl_value_get_map_value(extra,i);if(fl_value_get_type(k)==FL_VALUE_TYPE_STRING && fl_value_get_type(v)==FL_VALUE_TYPE_STRING){
    const std::string key=fl_value_get_string(k),value=fl_value_get_string(v);s->headers.emplace_back(key,value);
    if(g_ascii_strcasecmp(key.c_str(),"User-Agent")==0)webkit_settings_set_user_agent(webkit_web_view_get_settings(s->view),value.c_str());
    if(g_ascii_strcasecmp(key.c_str(),"Cookie")==0)cookie_header=value;
  }}
  g_autoptr(GUri) uri=g_uri_parse(s->url.c_str(),G_URI_FLAGS_NONE,nullptr);const char* domain=uri?g_uri_get_host(uri):nullptr;
  if(domain && !cookie_header.empty()){
    const auto parts=g_strsplit(cookie_header.c_str(),";",-1);
    for(int i=0;parts[i];i++){gchar* text=g_strstrip(parts[i]);const auto split=strchr(text,'=');if(!split)continue;const std::string name(text,static_cast<size_t>(split-text));auto* cookie=soup_cookie_new(name.c_str(),split+1,domain,"/",-1);if(!cookie)continue;
      s->pending_cookies++;auto* holder=new std::shared_ptr<Session>(s);
      webkit_cookie_manager_add_cookie(webkit_web_context_get_cookie_manager(webkit_web_view_get_context(s->view)),cookie,nullptr,[](GObject* object,GAsyncResult* result,gpointer user){std::unique_ptr<std::shared_ptr<Session>> hold(static_cast<std::shared_ptr<Session>*>(user));auto s=*hold;g_autoptr(GError) error=nullptr;webkit_cookie_manager_add_cookie_finish(WEBKIT_COOKIE_MANAGER(object),result,&error);if(!s->finished && --s->pending_cookies==0)s->load();},holder);soup_cookie_free(cookie);
    }g_strfreev(parts);
  }
  if(s->pending_cookies==0)s->load();
  s->poll=g_timeout_add(250,evaluate,s.get());s->timeout=g_timeout_add(20000,[](gpointer user)->gboolean{static_cast<Session*>(user)->finish(nullptr,"网页解析超时");return G_SOURCE_REMOVE;},s.get());
}
}
void RegisterMusicBrowser(FlBinaryMessenger* messenger){
  g_autoptr(FlStandardMethodCodec) codec=fl_standard_method_codec_new();
  g_autoptr(FlMethodChannel) channel=fl_method_channel_new(messenger,"chloris/browser",FL_METHOD_CODEC(codec));
  fl_method_channel_set_method_call_handler(channel,handler,nullptr,nullptr);
}
