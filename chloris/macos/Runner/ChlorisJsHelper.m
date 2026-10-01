#import <Foundation/Foundation.h>
#import <JavaScriptCore/JavaScriptCore.h>
#import <stdio.h>
#import <stdlib.h>

static JSContext *gContext;
static NSString *gEvaluationId;
static NSString *gException;

static void Emit(NSDictionary *message) {
  NSError *error = nil;
  NSData *data = [NSJSONSerialization dataWithJSONObject:message
                                                 options:NSJSONWritingFragmentsAllowed
                                                   error:&error];
  if (data == nil) return;
  fwrite(data.bytes, 1, data.length, stdout);
  fputc('\n', stdout);
  fflush(stdout);
}

static NSString *ReadLine(void) {
  char *line = NULL;
  size_t capacity = 0;
  ssize_t length = getline(&line, &capacity, stdin);
  if (length < 0) {
    free(line);
    return nil;
  }
  NSString *value = [[NSString alloc] initWithBytes:line
                                             length:(NSUInteger)length
                                           encoding:NSUTF8StringEncoding];
  free(line);
  return [value stringByTrimmingCharactersInSet:NSCharacterSet.newlineCharacterSet];
}

static NSDictionary *ReadMessage(void) {
  NSString *line = ReadLine();
  if (line == nil) return nil;
  NSData *data = [line dataUsingEncoding:NSUTF8StringEncoding];
  id value = [NSJSONSerialization JSONObjectWithData:data
                                              options:NSJSONReadingFragmentsAllowed
                                                error:nil];
  return [value isKindOfClass:NSDictionary.class] ? value : nil;
}

static void HandleEvaluation(NSDictionary *command) {
  NSString *identifier = command[@"id"];
  NSString *script = command[@"script"];
  if (![identifier isKindOfClass:NSString.class] ||
      ![script isKindOfClass:NSString.class]) {
    Emit(@{@"version": @1, @"type": @"protocolError", @"message": @"Invalid command"});
    return;
  }
  gEvaluationId = identifier;
  gException = nil;
  JSValue *value = [gContext evaluateScript:script
                              withSourceURL:[NSURL URLWithString:@"chloris://rule.js"]];
  if (gException != nil) {
    Emit(@{@"version": @1, @"type": @"result", @"id": identifier,
           @"ok": @NO, @"error": gException});
  } else {
    Emit(@{@"version": @1, @"type": @"result", @"id": identifier,
           @"ok": @YES, @"value": value.toString ?: @""});
  }
}

int main(void) {
  @autoreleasepool {
    gContext = [[JSContext alloc] init];
    if (gContext == nil) return 70;
    gContext.exceptionHandler = ^(JSContext *context, JSValue *exception) {
      gException = exception.toString ?: @"JavaScript exception";
    };
    gContext[@"sendMessage"] = ^NSString *(NSString *channel, NSString *payload) {
      Emit(@{@"version": @1, @"type": @"host", @"id": gEvaluationId ?: @"",
             @"payload": payload ?: @""});
      NSDictionary *reply = ReadMessage();
      if ([reply[@"version"] integerValue] != 1 ||
          ![reply[@"type"] isEqual:@"hostResult"] ||
          ![reply[@"id"] isEqual:gEvaluationId]) return @"";
      return [reply[@"value"] isKindOfClass:NSString.class] ? reply[@"value"] : @"";
    };

    NSDictionary *command;
    while ((command = ReadMessage()) != nil) {
      if ([command[@"version"] integerValue] != 1 ||
          ![command[@"action"] isEqual:@"evaluate"]) {
        Emit(@{@"version": @1, @"type": @"protocolError", @"message": @"Invalid command"});
        continue;
      }
      HandleEvaluation(command);
    }
  }
  return 0;
}
