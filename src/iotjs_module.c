/* Copyright 2015-present Samsung Electronics Co., Ltd. and other contributors
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

#include "iotjs_def.h"
#include "iotjs_module.h"
#include "iotjs_module_inl.h"

void iotjs_module_list_cleanup() {
  for (int i = 0; i < MODULE_COUNT; i++) {
    if (!iotjs_jval_is_undefined(modules[i].jmodule)) {
      jerry_release_value(modules[i].jmodule);
    }
  }
}

iotjs_jval_t iotjs_module_get(const char* name)
{
  for (int i = 0; i < MODULE_COUNT; i++) {
    if (!strcmp(name, modules[i].name)) {
      if (iotjs_jval_is_undefined(modules[i].jmodule)) {
        modules[i].jmodule = modules[i].fn_register();
      }

      return modules[i].jmodule;
    }
  }

  return *iotjs_jval_get_undefined();
}
