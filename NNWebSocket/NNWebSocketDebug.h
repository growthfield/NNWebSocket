// Copyright 2013 growthfield.jp
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//        http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

#ifdef DEBUG
#define Log(level, format, ...) \
if (_verbose >= level) { \
NSLog(format, ##__VA_ARGS__); \
}
#else
#define Log(level, format, ...)
#endif
#define LogError(format, ...) Log(1, @"[ERROR] %s : " format, __func__, ##__VA_ARGS__)
#define LogWarn(format, ...) Log(2, @"[WARN ] %s : " format, __func__, ##__VA_ARGS__)
#define LogInfo(format, ...) Log(3, @"[INFO ] %s : " format, __func__, ##__VA_ARGS__)
#define LogDebug(format, ...) Log(4, @"[DEBUG] %s : " format, __func__, ##__VA_ARGS__)
#define LogTrace(format, ...) Log(5, @"[TRACE] %s : " format, __func__, ##__VA_ARGS__)
