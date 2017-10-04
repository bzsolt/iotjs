# Copyright 2015-present Samsung Electronics Co., Ltd. and other contributors
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

cmake_minimum_required(VERSION 2.8)

include(${ROOT_DIR}/cmake/JSONParser.cmake)

set(IOTJS_SOURCE_DIR ${ROOT_DIR}/src)

function(find_value RESULT VALUE VALUE_TRUE VALUE_FALSE)
  list(FIND ARGN ${VALUE} idx)
  if(${idx} GREATER -1)
    set(${RESULT} ${VALUE_TRUE} PARENT_SCOPE)
  else()
    set(${RESULT} ${VALUE_FALSE} PARENT_SCOPE)
  endif()
endfunction(find_value)

# System Configuration (not module)
string(TOLOWER ${CMAKE_SYSTEM_NAME} IOTJS_SYSTEM_OS)
set(PLATFORM_OS_DIR
    ${IOTJS_SOURCE_DIR}/platform/${IOTJS_SYSTEM_OS})
file(GLOB IOTJS_PLATFORM_SRC ${PLATFORM_OS_DIR}/iotjs_*.c)
file(GLOB PLATFORM_MODULE_SRC ${PLATFORM_OS_DIR}/iotjs_module_*.c)
if (IOTJS_PLATFORM_SRC AND PLATFORM_MODULE_SRC)
  list(REMOVE_ITEM IOTJS_PLATFORM_SRC ${PLATFORM_MODULE_SRC})
endif()

# Board Configuration (not module)
if(NOT "${TARGET_BOARD}" STREQUAL "None")
  set(PLATFORM_BOARD_DIR
      ${PLATFORM_OS_DIR}/${TARGET_BOARD})
  file(GLOB IOTJS_BOARD_SRC ${PLATFORM_BOARD_DIR}/iotjs_*.c)
  file(GLOB PLATFORM_MODULE_SRC ${PLATFORM_BOARD_DIR}/iotjs_module_*.c)
  if (IOTJS_BOARD_SRC AND PLATFORM_MODULE_SRC)
    list(REMOVE_ITEM IOTJS_BOARD_SRC ${PLATFORM_MODULE_SRC})
  endif()
  list(APPEND IOTJS_PLATFORM_SRC ${IOTJS_BOARD_SRC})
endif()

# Run js2c
set(JS2C_RUN_MODE "release")
if("${CMAKE_BUILD_TYPE}" STREQUAL "Debug")
  set(JS2C_RUN_MODE "debug")
endif()

if(ENABLE_SNAPSHOT)
  set(JS2C_SNAPSHOT_ARG --snapshot-generator=${JERRY_HOST})
  set(IOTJS_CFLAGS ${IOTJS_CFLAGS} -DENABLE_SNAPSHOT)
endif()












# ======================================================================

# Module Configuration - listup all possible native C modules
function(getListOfVarsStartingWith _prefix _varResult)
    set(_moduleNames)
    get_cmake_property(_vars VARIABLES)
    string(REPLACE "." "\\." _prefix ${_prefix})
    foreach(_var ${_vars})
      string(REGEX MATCH "(^|;)${_prefix}([A-Za-z0-9_]+)\\.[A-Za-z0-9_.]*" _matchedVar "${_var}")
      if(_matchedVar)
        list(APPEND _moduleNames ${CMAKE_MATCH_2})
      endif()
    endforeach()
    list(REMOVE_DUPLICATES _moduleNames)
    set(${_varResult} ${_moduleNames} PARENT_SCOPE)
endfunction()

if(NOT MODULE_DESCRIPTOR_FILE)
  set(MODULE_DESCRIPTOR_FILE "${ROOT_DIR}/src/modules/modules.json")
endif()

file(READ ${MODULE_DESCRIPTOR_FILE} IOTJS_MODULES_JSON_FILE)
sbeParseJson(IOTJS_MODULES_JSON IOTJS_MODULES_JSON_FILE)

getListOfVarsStartingWith("IOTJS_MODULES_JSON.modules." IOTJS_MODULES)

# Enable all possible module for the given platform
foreach(var ${IOTJS_MODULES_JSON.platforms.${IOTJS_SYSTEM_OS}})
  string(TOUPPER ${IOTJS_MODULES_JSON.platforms.${IOTJS_SYSTEM_OS}_${var}} MODULE)
  set(ENABLE_MODULE_${MODULE} ON CACHE BOOL "ON/OFF")
endforeach()

foreach(var ${IOTJS_MODULES})
  string(TOUPPER ${var} MODULE)
  set(ENABLE_MODULE_${MODULE} OFF CACHE BOOL "ON/OFF")
endforeach()

set(IOTJS_JS_MODULES)
set(IOTJS_MODULE_SRC)
set(IOTJS_MODULES_ENABLED)

message("IoT.js module configuration")
foreach(module ${IOTJS_MODULES})
  string(TOUPPER ${module} MODULE)
  if(${ENABLE_MODULE_${MODULE}})
    set(MODULE_JS_FILE ${IOTJS_MODULES_JSON.modules.${module}.js_file})
    if(NOT "${MODULE_JS_FILE}" STREQUAL "")
      if(EXISTS "${IOTJS_SOURCE_DIR}/js/${MODULE_JS_FILE}")
        list(APPEND IOTJS_JS_MODULES "${module}")
      endif()
    endif()

    if(NOT "${IOTJS_MODULES_JSON.modules.${module}.native_files}" STREQUAL "")
      list(APPEND IOTJS_MODULES_ENABLED "${MODULE}")
    endif()

    foreach(item ${IOTJS_MODULES_JSON.modules.${module}.native_files})
      set(MODULE_C_FILE ${IOTJS_MODULES_JSON.modules.${module}.native_files_${item}})
      set(MODULE_C_FILE "${IOTJS_SOURCE_DIR}/modules/${MODULE_C_FILE}")
      if(EXISTS "${MODULE_C_FILE}")
        list(APPEND IOTJS_MODULE_SRC ${MODULE_C_FILE})
      endif()
    endforeach()
  endif()
endforeach()

list(APPEND IOTJS_JS_MODULES "iotjs")
list(APPEND IOTJS_JS_MODULES "module")
list(LENGTH IOTJS_MODULES_ENABLED IOTJS_MODULE_COUNT)

set(IOTJS_MODULE_INL_H
"#define MODULE_COUNT ${IOTJS_MODULE_COUNT}
static iotjs_module_t modules[MODULE_COUNT];
")

foreach(module ${IOTJS_MODULES_ENABLED})
  string(TOLOWER ${module} lowercase_module)
  set(IOTJS_MODULE_INL_H
  "${IOTJS_MODULE_INL_H}
iotjs_jval_t ${IOTJS_MODULES_JSON.modules.${lowercase_module}.init}();")
endforeach()

set(IOTJS_MODULE_INL_H
"${IOTJS_MODULE_INL_H}

void iotjs_module_list_init() {")

set(index 0)
foreach(module ${IOTJS_MODULES_ENABLED})
  string(TOLOWER ${module} lowercase_module)
  set(IOTJS_MODULE_INL_H
  "${IOTJS_MODULE_INL_H}
  modules[${index}].name = \"${lowercase_module}\";
  modules[${index}].jmodule = *iotjs_jval_get_undefined();
  modules[${index}].fn_register = ${IOTJS_MODULES_JSON.modules.${lowercase_module}.init};")
  math(EXPR index "${index} + 1")
endforeach()

set(IOTJS_MODULE_INL_H
"${IOTJS_MODULE_INL_H}
}")

file(WRITE ${IOTJS_SOURCE_DIR}/iotjs_module_inl.h "${IOTJS_MODULE_INL_H}")

sbeClearJson(IOTJS_MODULES_JSON)

# ======================================================================

add_custom_command(
  OUTPUT ${IOTJS_SOURCE_DIR}/iotjs_js.c ${IOTJS_SOURCE_DIR}/iotjs_js.h
  COMMAND python ${ROOT_DIR}/tools/js2c.py
  ARGS --buildtype=${JS2C_RUN_MODE}
       --modules '${IOTJS_JS_MODULES}'
       ${JS2C_SNAPSHOT_ARG}
  DEPENDS ${ROOT_DIR}/tools/js2c.py
          jerry
          ${IOTJS_SOURCE_DIR}/js/*.js
)

# Print out some configs
message("IoT.js configured with:")
message(STATUS "CMAKE_BUILD_TYPE         ${CMAKE_BUILD_TYPE}")
message(STATUS "CMAKE_C_FLAGS            ${CMAKE_C_FLAGS}")
message(STATUS "PLATFORM_DESCRIPTOR      ${PLATFORM_DESCRIPTOR}")
message(STATUS "TARGET_OS                ${TARGET_OS}")
message(STATUS "TARGET_SYSTEMROOT        ${TARGET_SYSTEMROOT}")
message(STATUS "TARGET_BOARD             ${TARGET_BOARD}")
message(STATUS "BUILD_LIB_ONLY           ${BUILD_LIB_ONLY}")
message(STATUS "ENABLE_LTO               ${ENABLE_LTO}")
message(STATUS "ENABLE_SNAPSHOT          ${ENABLE_SNAPSHOT}")
message(STATUS "ENABLE_MINIMAL           ${ENABLE_MINIMAL}")
message(STATUS "IOTJS_INCLUDE_MODULE     ${IOTJS_INCLUDE_MODULE}")
message(STATUS "IOTJS_EXCLUDE_MODULE     ${IOTJS_EXCLUDE_MODULE}")
message(STATUS "IOTJS_C_FLAGS            ${IOTJS_C_FLAGS}")
message(STATUS "IOTJS_LINK_FLAGS         ${IOTJS_LINK_FLAGS}")

# Collect all sources into LIB_IOTJS_SRC
file(GLOB LIB_IOTJS_SRC ${IOTJS_SOURCE_DIR}/*.c)
list(APPEND LIB_IOTJS_SRC
  ${IOTJS_SOURCE_DIR}/iotjs_js.c
  ${IOTJS_SOURCE_DIR}/iotjs_js.h
  ${IOTJS_MODULE_SRC}
  ${IOTJS_PLATFORM_SRC}
)

separate_arguments(EXTERNAL_INCLUDE_DIR)
separate_arguments(EXTERNAL_STATIC_LIB)
separate_arguments(EXTERNAL_SHARED_LIB)

set(IOTJS_INCLUDE_DIRS
  ${EXTERNAL_INCLUDE_DIR}
  ${ROOT_DIR}/include
  ${IOTJS_SOURCE_DIR}
  ${JERRY_PORT_DIR}/include
  ${JERRY_INCLUDE_DIR}
  ${HTTPPARSER_INCLUDE_DIR}
  ${TUV_INCLUDE_DIR}
)

set(IOTJS_CFLAGS ${IOTJS_CFLAGS} ${CFLAGS_COMMON})

# Configure the libiotjs.a
set(TARGET_LIB_IOTJS libiotjs)
add_library(${TARGET_LIB_IOTJS} STATIC ${LIB_IOTJS_SRC})
set_target_properties(${TARGET_LIB_IOTJS} PROPERTIES
  COMPILE_OPTIONS "${IOTJS_CFLAGS}"
  OUTPUT_NAME iotjs
  ARCHIVE_OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}/lib"
)
target_include_directories(${TARGET_LIB_IOTJS} PRIVATE ${IOTJS_INCLUDE_DIRS})
target_link_libraries(${TARGET_LIB_IOTJS}
  ${JERRY_LIBS}
  ${TUV_LIBS}
  libhttp-parser
  ${EXTERNAL_STATIC_LIB}
  ${EXTERNAL_SHARED_LIB}
)

if("${LIB_INSTALL_DIR}" STREQUAL "")
  set(LIB_INSTALL_DIR "lib")
endif()

if("${BIN_INSTALL_DIR}" STREQUAL "")
  set(BIN_INSTALL_DIR "bin")
endif()

install(TARGETS ${TARGET_LIB_IOTJS} DESTINATION ${LIB_INSTALL_DIR})

if(NOT BUILD_LIB_ONLY)

  if("${CMAKE_SYSTEM_NAME}" STREQUAL "Darwin")
    set(IOTJS_LINK_FLAGS "-Xlinker -map -Xlinker iotjs.map")
  else()
    set(IOTJS_LINK_FLAGS "-Xlinker -Map -Xlinker iotjs.map")
  endif()

  # Configure the iotjs executable
  set(TARGET_IOTJS iotjs)
  add_executable(${TARGET_IOTJS} ${ROOT_DIR}/iotjs_linux.c)
  set_target_properties(${TARGET_IOTJS} PROPERTIES
    COMPILE_OPTIONS "${IOTJS_CFLAGS}"
    LINK_FLAGS "${CMAKE_EXE_LINKER_FLAGS} ${IOTJS_LINK_FLAGS}"
    RUNTIME_OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}/bin"
  )
  target_include_directories(${TARGET_IOTJS} PRIVATE ${IOTJS_INCLUDE_DIRS})
  target_link_libraries(${TARGET_IOTJS} ${TARGET_LIB_IOTJS})
  install(TARGETS ${TARGET_IOTJS} DESTINATION ${BIN_INSTALL_DIR})
endif()
