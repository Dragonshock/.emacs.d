// tld-lookup — query The Little Dict via Dictionary Services.
//
// Build:
//   clang -O2 -fobjc-arc \
//     -framework Foundation -framework AppKit \
//     -framework CoreServices -framework Carbon \
//     -o tld-lookup scripts/tld-lookup.m
//
// Usage:
//   tld-lookup --text [--] WORD
//   tld-lookup --popup [--offset N] [--x N] [--y N] [--max-seconds N] [--] TEXT
//   tld-lookup --list
//   tld-lookup --self-check
//
// Runtime bundle is ~/Library/Dictionaries/TLD.dictionary (not the
// ~/Desktop/The Little Dict source repo). Never walk Resources; one-term
// Dictionary Services lookup only. RLIMIT_DATA + alarm() so a stuck helper
// cannot hang Emacs.

#import <AppKit/AppKit.h>
#import <Carbon/Carbon.h>
#import <CoreServices/CoreServices.h>
#import <Foundation/Foundation.h>

#include <signal.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/resource.h>
#include <unistd.h>

#define TLD_ID "com.thelittledict.dictionary.TLD"
#define TLD_NAME "The Little Dict"
#define TLD_NATIVE_NAME "袖珍英汉词典"
#define TLD_PATH "~/Library/Dictionaries/TLD.dictionary"
#define TEXT_LIMIT 262144
#define AS_LIMIT (768ull * 1024ull * 1024ull)

extern CFArrayRef DCSCopyAvailableDictionaries(void);
extern CFStringRef DCSDictionaryGetName(DCSDictionaryRef dictionary);
extern CFStringRef DCSDictionaryGetShortName(DCSDictionaryRef dictionary);
extern CFStringRef DCSDictionaryGetIdentifier(DCSDictionaryRef dictionary);
extern CFURLRef DCSDictionaryGetURL(DCSDictionaryRef dictionary);
extern DCSDictionaryRef DCSDictionaryCreate(CFURLRef url);
extern DCSDictionaryRef DCSDictionaryCreateWithIdentifier(CFStringRef identifier);
extern CFArrayRef DCSCopyRecordsForSearchString(DCSDictionaryRef dictionary,
                                                CFStringRef string,
                                                void *,
                                                void *);
extern CFStringRef DCSRecordCopyData(CFTypeRef record, long version);

static void die_on_alarm(int sig) {
  (void)sig;
  _exit(0);
}

static void install_limits(int max_seconds) {
  struct rlimit rl;
  rl.rlim_cur = AS_LIMIT;
  rl.rlim_max = AS_LIMIT;
  (void)setrlimit(RLIMIT_DATA, &rl);

  if (max_seconds > 0) {
    signal(SIGALRM, die_on_alarm);
    alarm((unsigned)max_seconds);
  }
}

static NSString *dict_name(DCSDictionaryRef d) {
  CFStringRef s = DCSDictionaryGetName(d);
  return s ? (__bridge NSString *)s : @"";
}

static NSString *dict_ident(DCSDictionaryRef d) {
  CFStringRef s = DCSDictionaryGetIdentifier(d);
  return s ? (__bridge NSString *)s : @"";
}

static NSString *dict_url(DCSDictionaryRef d) {
  CFURLRef u = DCSDictionaryGetURL(d);
  if (!u)
    return @"";
  NSURL *ns = (__bridge NSURL *)u;
  return ns.path ?: ns.absoluteString ?: @"";
}

static BOOL is_tld(DCSDictionaryRef d) {
  NSString *ident = dict_ident(d);
  NSString *name = dict_name(d);
  NSString *url = dict_url(d);
  if ([ident isEqualToString:@TLD_ID])
    return YES;
  if ([name isEqualToString:@TLD_NAME])
    return YES;
  if ([name isEqualToString:@TLD_NATIVE_NAME])
    return YES;
  if ([url containsString:@"TLD.dictionary"])
    return YES;
  return NO;
}

static NSArray *available_dictionaries(void) {
  CFTypeRef obj = DCSCopyAvailableDictionaries();
  if (!obj)
    return nil;
  CFTypeID tid = CFGetTypeID(obj);
  if (tid == CFArrayGetTypeID())
    return CFBridgingRelease(obj);
  if (tid == CFSetGetTypeID())
    return [(__bridge_transfer NSSet *)obj allObjects];
  CFRelease(obj);
  return nil;
}

static DCSDictionaryRef copy_tld(NSString **err) {
  NSString *path = [@TLD_PATH stringByExpandingTildeInPath];
  NSFileManager *fm = [NSFileManager defaultManager];
  if ([fm fileExistsAtPath:path]) {
    NSURL *url = [NSURL fileURLWithPath:path isDirectory:YES];
    DCSDictionaryRef created = DCSDictionaryCreate((__bridge CFURLRef)url);
    if (created)
      return created;
  }

  DCSDictionaryRef by_id = DCSDictionaryCreateWithIdentifier(CFSTR(TLD_ID));
  if (by_id)
    return by_id;

  for (id obj in available_dictionaries()) {
    DCSDictionaryRef d = (__bridge DCSDictionaryRef)obj;
    if (d && is_tld(d)) {
      CFRetain(d);
      return d;
    }
  }

  if (err) {
    *err = [NSString stringWithFormat:
                         @"The Little Dict not found. Install TLD.dictionary to %@ "
                         @"(see ~/Desktop/The Little Dict/README.md).",
                         path];
  }
  return NULL;
}

static NSString *strip_markup(NSString *html) {
  if (html.length == 0)
    return html;
  NSError *err = nil;
  NSRegularExpression *re =
      [NSRegularExpression regularExpressionWithPattern:@"<[^>]+>"
                                                options:0
                                                  error:&err];
  NSString *s = html;
  if (re)
    s = [re stringByReplacingMatchesInString:s
                                     options:0
                                       range:NSMakeRange(0, s.length)
                                withTemplate:@""];
  s = [s stringByReplacingOccurrencesOfString:@"&nbsp;" withString:@" "];
  s = [s stringByReplacingOccurrencesOfString:@"&amp;" withString:@"&"];
  s = [s stringByReplacingOccurrencesOfString:@"&lt;" withString:@"<"];
  s = [s stringByReplacingOccurrencesOfString:@"&gt;" withString:@">"];
  s = [s stringByReplacingOccurrencesOfString:@"&quot;" withString:@"\""];
  return s;
}

static NSString *capped(NSString *s) {
  if (s.length <= TEXT_LIMIT)
    return s;
  return [[s substringToIndex:TEXT_LIMIT] stringByAppendingString:@"\n…"];
}

static NSString *first_group(NSString *html, NSString *pattern) {
  if (html.length == 0)
    return nil;
  NSError *err = nil;
  NSRegularExpression *re =
      [NSRegularExpression regularExpressionWithPattern:pattern
                                                options:NSRegularExpressionDotMatchesLineSeparators
                                                  error:&err];
  if (!re)
    return nil;
  NSTextCheckingResult *m =
      [re firstMatchInString:html options:0 range:NSMakeRange(0, html.length)];
  if (!m || m.numberOfRanges < 2)
    return nil;
  NSRange r = [m rangeAtIndex:1];
  if (r.location == NSNotFound || r.length == 0)
    return nil;
  NSString *raw = [html substringWithRange:r];
  NSString *plain = [strip_markup(raw)
      stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
  return plain.length ? plain : nil;
}

static NSArray<NSString *> *all_raw_groups(NSString *html, NSString *pattern) {
  NSMutableArray<NSString *> *out = [NSMutableArray array];
  if (html.length == 0)
    return out;
  NSError *err = nil;
  NSRegularExpression *re =
      [NSRegularExpression regularExpressionWithPattern:pattern
                                                options:NSRegularExpressionDotMatchesLineSeparators
                                                  error:&err];
  if (!re)
    return out;
  NSArray<NSTextCheckingResult *> *ms =
      [re matchesInString:html options:0 range:NSMakeRange(0, html.length)];
  for (NSTextCheckingResult *m in ms) {
    if (m.numberOfRanges < 2)
      continue;
    NSRange r = [m rangeAtIndex:1];
    if (r.location == NSNotFound || r.length == 0)
      continue;
    [out addObject:[html substringWithRange:r]];
  }
  return out;
}

static NSArray<NSString *> *all_groups(NSString *html, NSString *pattern) {
  NSMutableArray<NSString *> *out = [NSMutableArray array];
  for (NSString *raw in all_raw_groups(html, pattern)) {
    NSString *plain = [strip_markup(raw)
        stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if (plain.length)
      [out addObject:plain];
  }
  return out;
}

static BOOL html_is_exact_word(NSString *html, NSString *word) {
  for (NSString *pat in @[ @"d:title=\"([^\"]+)\"", @"\\sid=\"([^\"]+)\"",
                           @"class=\"hwd\">([^<]+)" ]) {
    NSString *got = first_group(html, pat);
    if (got && [got caseInsensitiveCompare:word] == NSOrderedSame)
      return YES;
  }
  return NO;
}

static NSString *format_tld_html(NSString *html, NSString *word) {
  NSString *hwd = first_group(html, @"class=\"hwd\">([^<]+)");
  if (!hwd.length)
    hwd = word;
  NSString *ipa = first_group(html, @"class=\"pron\"[^>]*>(.*?)</span>");
  NSString *infl = first_group(html, @"class=\"inflections\">([^<]+)");
  NSArray<NSString *> *labels = all_groups(html, @"class=\"exam-label\">([^<]+)");
  NSString *ratio = first_group(html, @"class=\"ratio\"[^>]*>(.*?)</div>");
  NSArray<NSString *> *senses = all_raw_groups(html, @"class=\"sense\"[^>]*>(.*?)</div>");

  NSMutableArray<NSString *> *lines = [NSMutableArray array];
  if (ipa.length) {
    if (![ipa hasPrefix:@"/"])
      ipa = [NSString stringWithFormat:@"/%@/", ipa];
    [lines addObject:[NSString stringWithFormat:@"%@ %@", hwd, ipa]];
  } else {
    [lines addObject:hwd];
  }
  if (infl.length)
    [lines addObject:infl];
  if (labels.count)
    [lines addObject:[labels componentsJoinedByString:@" / "]];
  if (ratio.length)
    [lines addObject:ratio];
  for (NSString *sense in senses) {
    NSString *p = first_group(sense, @"class=\"pos\"[^>]*>(.*?)</span>");
    NSString *cn = first_group(sense, @"class=\"text-cn[^\"]*\"[^>]*>(.*?)</span>");
    if (p.length && cn.length)
      [lines addObject:[NSString stringWithFormat:@"%@ %@", p, cn]];
    else if (cn.length)
      [lines addObject:cn];
    else if (p.length)
      [lines addObject:p];
  }
  return lines.count ? [lines componentsJoinedByString:@"\n"] : nil;
}

static NSString *best_record_html(DCSDictionaryRef dict, NSString *word) {
  CFArrayRef recs = DCSCopyRecordsForSearchString(dict, (__bridge CFStringRef)word, NULL, NULL);
  if (!recs)
    return nil;
  NSString *exact = nil;
  NSString *with_ratio = nil;
  NSString *first = nil;
  CFIndex n = CFArrayGetCount(recs);
  if (n > 8)
    n = 8;
  for (CFIndex i = 0; i < n; i++) {
    CFStringRef data = DCSRecordCopyData(CFArrayGetValueAtIndex(recs, i), 0);
    if (!data)
      continue;
    NSString *html = CFBridgingRelease(data);
    if (html.length == 0)
      continue;
    if (!first)
      first = html;
    if (!exact && html_is_exact_word(html, word))
      exact = html;
    if (!with_ratio && [html containsString:@"class=\"ratio\""])
      with_ratio = html;
  }
  CFRelease(recs);
  return exact ?: with_ratio ?: first;
}

static NSString *definition_text(DCSDictionaryRef dict, NSString *word) {
  if (word.length == 0)
    return nil;
  word = [word stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
  if (word.length == 0)
    return nil;

  NSString *html = best_record_html(dict, word);
  if (html) {
    NSString *formatted = format_tld_html(html, word);
    if (formatted.length)
      return capped(formatted);
  }

  CFStringRef cfword = (__bridge CFStringRef)word;
  CFRange range = DCSGetTermRangeInString(dict, cfword, 0);
  if (range.location == kCFNotFound)
    range = CFRangeMake(0, (CFIndex)word.length);
  CFStringRef def = DCSCopyTextDefinition(dict, cfword, range);
  if (!def)
    return nil;
  NSString *plain = CFBridgingRelease(def);
  return plain.length ? capped(plain) : nil;
}

static int cmd_list(void) {
  NSArray *arr = available_dictionaries();
  if (!arr) {
    fprintf(stderr, "DCSCopyAvailableDictionaries returned NULL\n");
    return 1;
  }
  for (id obj in arr) {
    DCSDictionaryRef d = (__bridge DCSDictionaryRef)obj;
    const char *mark = is_tld(d) ? "*" : " ";
    printf("%s %s\t%s\t%s\n", mark, dict_name(d).UTF8String ?: "",
           dict_ident(d).UTF8String ?: "", dict_url(d).UTF8String ?: "");
  }
  return 0;
}

static int cmd_text(NSString *word) {
  NSString *err = nil;
  DCSDictionaryRef dict = copy_tld(&err);
  if (!dict) {
    fprintf(stderr, "%s\n", err.UTF8String ?: "The Little Dict missing");
    return 2;
  }
  NSString *def = definition_text(dict, word);
  CFRelease(dict);
  if (!def) {
    fprintf(stderr, "No The Little Dict definition for: %s\n", word.UTF8String ?: "");
    return 3;
  }
  fputs(def.UTF8String ?: "", stdout);
  if (![def hasSuffix:@"\n"])
    fputc('\n', stdout);
  return 0;
}

static int cmd_popup(NSString *text, CFIndex offset, CGFloat x, CGFloat y,
                     CGFloat w, CGFloat h, int max_seconds) {
  NSString *err = nil;
  DCSDictionaryRef dict = copy_tld(&err);
  if (!dict) {
    fprintf(stderr, "%s\n", err.UTF8String ?: "The Little Dict missing");
    return 2;
  }

  if (text.length == 0) {
    CFRelease(dict);
    fprintf(stderr, "Empty lookup text\n");
    return 3;
  }
  if (offset < 0)
    offset = 0;
  if (offset >= (CFIndex)text.length)
    offset = (CFIndex)text.length - 1;

  [NSApplication sharedApplication];
  [NSApp setActivationPolicy:NSApplicationActivationPolicyAccessory];
  [NSApp activateIgnoringOtherApps:YES];

  CFStringRef cftext = (__bridge CFStringRef)text;
  CFRange range = DCSGetTermRangeInString(dict, cftext, offset);
  if (range.location == kCFNotFound)
    range = DCSGetTermRangeInString(NULL, cftext, offset);
  if (range.location == kCFNotFound)
    range = CFRangeMake(0, (CFIndex)text.length);

  if (w < 4)
    w = 8;
  if (h < 4)
    h = 16;

  // Emacs display pixels are top-left. Cocoa windows are bottom-left.
  NSRect vg = NSZeroRect;
  for (NSScreen *s in [NSScreen screens])
    vg = NSUnionRect(vg, s.frame);
  CGFloat cocoaY = NSMaxY(vg) - (y + h);
  NSWindow *anchor = [[NSWindow alloc]
      initWithContentRect:NSMakeRect(x, cocoaY, w, h)
                styleMask:NSWindowStyleMaskBorderless
                  backing:NSBackingStoreBuffered
                    defer:NO];
  [anchor setOpaque:NO];
  [anchor setBackgroundColor:[NSColor clearColor]];
  [anchor setLevel:NSFloatingWindowLevel];
  [anchor setIgnoresMouseEvents:YES];
  [anchor orderFrontRegardless];

  NSRange nsrange = NSMakeRange((NSUInteger)range.location, (NSUInteger)range.length);
  NSAttributedString *attr = [[NSAttributedString alloc] initWithString:text];
  CGFloat baseX = w / 2.0;
  [anchor.contentView
      showDefinitionForAttributedString:attr
                                  range:nsrange
                                options:@{
                                  NSDefinitionPresentationTypeKey :
                                      NSDefinitionPresentationTypeOverlay
                                }
                 baselineOriginProvider:^NSPoint(NSRange _) {
                   return NSMakePoint(baseX, 0);
                 }];

  // Escape / Ctrl-G in the helper (it is key after activateIgnoringOtherApps).
  __block BOOL done = NO;
  [NSEvent addLocalMonitorForEventsMatchingMask:NSEventMaskKeyDown
                                        handler:^NSEvent *(NSEvent *ev) {
                                          NSEventModifierFlags mods =
                                              ev.modifierFlags & NSEventModifierFlagDeviceIndependentFlagsMask;
                                          BOOL esc = ev.keyCode == 53;
                                          NSString *ch = ev.charactersIgnoringModifiers.lowercaseString;
                                          BOOL ctrlG = (mods & NSEventModifierFlagControl) &&
                                                       [ch isEqualToString:@"g"];
                                          if (esc || ctrlG) {
                                            done = YES;
                                            return nil;
                                          }
                                          return ev;
                                        }];

  // Panel is owned by this process. Keep the runloop for the full budget.
  // Do not [NSApp run] forever; Emacs start-process + alarm is the backstop.
  NSTimeInterval budget = max_seconds > 0 ? (NSTimeInterval)max_seconds : 8.0;
  NSDate *until = [NSDate dateWithTimeIntervalSinceNow:budget];
  while (!done && [until timeIntervalSinceNow] > 0) {
    [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode
                             beforeDate:[NSDate dateWithTimeIntervalSinceNow:0.05]];
  }

  CFRelease(dict);
  return 0;
}

static int cmd_self_check(void) {
  NSString *err = nil;
  DCSDictionaryRef dict = copy_tld(&err);
  if (!dict) {
    fprintf(stderr, "FAIL find: %s\n", err.UTF8String ?: "missing");
    return 2;
  }
  printf("ok dict name=%s id=%s url=%s\n", dict_name(dict).UTF8String ?: "",
         dict_ident(dict).UTF8String ?: "", dict_url(dict).UTF8String ?: "");

  NSString *def = definition_text(dict, @"play");
  CFRelease(dict);
  if (!def) {
    fprintf(stderr, "FAIL definition: empty for play\n");
    return 3;
  }
  BOOL has_cjk = ([def rangeOfCharacterFromSet:
                           [NSCharacterSet characterSetWithRange:NSMakeRange(0x4E00, 0x9FFF)]]
                      .location != NSNotFound);
  BOOL looks_oxford = [def containsString:@"plā"] || [def containsString:@"| verb"];
  BOOL has_ratio = [def containsString:@"玩(37%)"] && [def containsString:@"游戏(15%)"];
  BOOL one_line_head = [def hasPrefix:@"play /"];
  printf("ok play chars=%lu cjk=%s oxford_shape=%s ratio=%s head=%s\n",
         (unsigned long)def.length, has_cjk ? "yes" : "no",
         looks_oxford ? "yes" : "no", has_ratio ? "yes" : "no",
         one_line_head ? "play /ipa" : "other");
  if (!has_cjk || looks_oxford) {
    fprintf(stderr, "FAIL expected The Little Dict Chinese gloss, not Oxford prose\n");
    return 4;
  }
  if (!has_ratio || !one_line_head) {
    fprintf(stderr, "FAIL expected play /ipa and play sense-ratio line\n");
    return 5;
  }
  fputs("ok self-check\n", stdout);
  return 0;
}

static void usage(void) {
  fprintf(stderr,
          "Usage:\n"
          "  tld-lookup --text [--] WORD\n"
          "  tld-lookup --popup [--offset N] [--x N] [--y N] [--w N] [--h N] [--max-seconds N] [--] TEXT\n"
          "  tld-lookup --list\n"
          "  tld-lookup --self-check\n");
}

int main(int argc, const char *argv[]) {
  @autoreleasepool {
    if (argc < 2) {
      usage();
      return 1;
    }

    NSString *mode = [NSString stringWithUTF8String:argv[1]];
    NSString *text = nil;
    CFIndex offset = 0;
    CGFloat x = 80, y = 80, w = 8, h = 16;
    int max_seconds = 8;
    BOOL saw_ddash = NO;

    if ([mode isEqualToString:@"--list"]) {
      install_limits(8);
      return cmd_list();
    }
    if ([mode isEqualToString:@"--self-check"]) {
      install_limits(8);
      return cmd_self_check();
    }

    if (![mode isEqualToString:@"--text"] && ![mode isEqualToString:@"--popup"]) {
      usage();
      return 1;
    }

    if ([mode isEqualToString:@"--popup"])
      max_seconds = 8;

    for (int i = 2; i < argc; i++) {
      const char *a = argv[i];
      if (!saw_ddash && strcmp(a, "--") == 0) {
        saw_ddash = YES;
        continue;
      }
      if (!saw_ddash && strcmp(a, "--offset") == 0 && i + 1 < argc) {
        offset = (CFIndex)atoi(argv[++i]);
        continue;
      }
      if (!saw_ddash && strcmp(a, "--x") == 0 && i + 1 < argc) {
        x = atof(argv[++i]);
        continue;
      }
      if (!saw_ddash && strcmp(a, "--y") == 0 && i + 1 < argc) {
        y = atof(argv[++i]);
        continue;
      }
      if (!saw_ddash && strcmp(a, "--w") == 0 && i + 1 < argc) {
        w = atof(argv[++i]);
        continue;
      }
      if (!saw_ddash && strcmp(a, "--h") == 0 && i + 1 < argc) {
        h = atof(argv[++i]);
        continue;
      }
      if (!saw_ddash && strcmp(a, "--max-seconds") == 0 && i + 1 < argc) {
        max_seconds = atoi(argv[++i]);
        if (max_seconds < 1)
          max_seconds = 1;
        if (max_seconds > 90)
          max_seconds = 90;
        continue;
      }
      text = [NSString stringWithUTF8String:a];
    }

    if (text.length == 0) {
      usage();
      return 1;
    }
    if (text.length > 2000)
      text = [text substringToIndex:2000];

    install_limits(max_seconds);

    if ([mode isEqualToString:@"--text"])
      return cmd_text(text);
    return cmd_popup(text, offset, x, y, w, h, max_seconds);
  }
}
