/* Copyright 2018-present Samsung Electronics Co., Ltd. and other contributors
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
#include "iotjs_module_tls.h"

#include "stdarg.h"

IOTJS_DEFINE_NATIVE_HANDLE_INFO_THIS_MODULE(tls);

static void iotjs_tls_destroy(iotjs_tls_t* tls_data) {
  mbedtls_net_free(&tls_data->server_fd);
  mbedtls_x509_crt_free(&tls_data->cacert);
  mbedtls_ssl_free(&tls_data->ssl);
  mbedtls_ssl_config_free(&tls_data->conf);
  mbedtls_ctr_drbg_free(&tls_data->ctr_drbg);
  mbedtls_entropy_free(&tls_data->entropy);

  IOTJS_RELEASE(tls_data);
}

static iotjs_tls_t* tls_create(const jerry_value_t jobject) {
  iotjs_tls_t* tls_data = IOTJS_ALLOC(iotjs_tls_t);

  tls_data->jobject = jobject;
  jerry_set_object_native_pointer(jobject, tls_data, &this_module_native_info);

  mbedtls_net_init(&tls_data->server_fd);
  mbedtls_ssl_init(&tls_data->ssl);
  mbedtls_ssl_config_init(&tls_data->conf);
  mbedtls_x509_crt_init(&tls_data->cacert);
  mbedtls_ctr_drbg_init(&tls_data->ctr_drbg);
  mbedtls_entropy_init(&tls_data->entropy);

  return tls_data;
}

static jerry_value_t create_error_message(const char* format, ...) {
  va_list args;
  va_start(args, format);
  char buff[256];
  uint16_t err_len = vsprintf(buff, format, args);

  return jerry_create_string_sz((const jerry_char_t*)buff, err_len);
}

/*
JS_FUNCTION(Write) {
  DJS_CHECK_ARGS(1, string);
  iotjs_string_t str = JS_GET_ARG(0, string);

  unsigned char buf_orig[] = "GET /tls_test.js HTTP/1.1\r\nHost:
localhost\r\n\r\n";
  unsigned char buf[1024];
  int len = sprintf((char *) buf, (char *) buf_orig);
  int ret = 0;
  while ((ret = mbedtls_ssl_write(&tls_data->ssl, buf, (size_t) len)) <= 0) {
    if (ret != MBEDTLS_ERR_SSL_WANT_READ && ret != MBEDTLS_ERR_SSL_WANT_WRITE) {
      return create_error_message("write error, error code: %d", ret);
    }
  }
}*/

JS_FUNCTION(Connect) {
  DJS_CHECK_ARGS(3, string, string, string);
  iotjs_string_t port = JS_GET_ARG(0, string);
  iotjs_string_t host = JS_GET_ARG(1, string);
  iotjs_string_t hostname = JS_GET_ARG(2, string);

  JS_DECLARE_THIS_PTR(tls, tls_data);

  int ret = 0;
  if ((ret = mbedtls_ctr_drbg_seed(&tls_data->ctr_drbg, mbedtls_entropy_func,
                                   &tls_data->entropy, NULL, 0)) != 0) {
    return create_error_message("drbg seeding failed, error code: %d", ret);
  }

  ret = mbedtls_net_connect(&tls_data->server_fd,
                            (const char*)iotjs_string_data(&host),
                            (const char*)iotjs_string_data(&port),
                            MBEDTLS_NET_PROTO_TCP);
  if (ret) {
    return create_error_message("failed to connect to %s:%s, error code: %d",
                                iotjs_string_data(&host),
                                iotjs_string_data(&port), ret);
  }

  ret = mbedtls_ssl_config_defaults(&tls_data->conf, MBEDTLS_SSL_IS_CLIENT,
                                    MBEDTLS_SSL_TRANSPORT_STREAM,
                                    MBEDTLS_SSL_PRESET_DEFAULT);
  if (ret) {
    return create_error_message("ssl config failed, error code: %d", ret);
  }

  mbedtls_ssl_conf_authmode(&tls_data->conf, MBEDTLS_SSL_VERIFY_OPTIONAL);
  mbedtls_ssl_conf_ca_chain(&tls_data->conf, &tls_data->cacert, NULL);
  mbedtls_ssl_conf_rng(&tls_data->conf, mbedtls_ctr_drbg_random,
                       &tls_data->ctr_drbg);

  ret = mbedtls_ssl_setup(&tls_data->ssl, &tls_data->conf);

  if (ret) {
    return create_error_message("ssl setup failed, error code: %d", ret);
  }

  ret = mbedtls_ssl_set_hostname(&tls_data->ssl, iotjs_string_data(&hostname));
  if (ret) {
    return create_error_message("ssl hostname setup failed, error code: %d",
                                ret);
  }

  mbedtls_ssl_set_bio(&tls_data->ssl, &tls_data->server_fd, mbedtls_net_send,
                      mbedtls_net_recv, NULL);

  while ((ret = mbedtls_ssl_handshake(&tls_data->ssl))) {
    if (ret != MBEDTLS_ERR_SSL_WANT_READ && ret != MBEDTLS_ERR_SSL_WANT_WRITE) {
      return create_error_message("handshake failed, error code: -0x%x", -ret);
    }
  }

  return jerry_create_boolean(true);
}

JS_FUNCTION(TLSSocketCons) {
  DJS_CHECK_THIS();
  DJS_CHECK_ARGS(1, object);

  jerry_value_t netsocket = JS_GET_ARG(0, object);
  IOTJS_UNUSED(netsocket); // TODO

  jerry_value_t jtls = JS_GET_THIS();
  iotjs_tls_t* tls_data = tls_create(jtls);

  jerry_value_t jis_server =
      iotjs_jval_get_property(jtls, IOTJS_MAGIC_STRING_ISSERVER);

  const bool isServer = iotjs_jval_as_boolean(jis_server);
  jerry_release_value(jis_server);

  int ret = -1;

  /* Set up seed and entropy. */
  if ((ret = mbedtls_ctr_drbg_seed(&tls_data->ctr_drbg, mbedtls_entropy_func,
                                   &tls_data->entropy, NULL, 0)) != 0) {
    printf("TLSSocket - initial seeding failed with %d\n", ret);
    goto exit;
  }

  /* Load default SSL configuration values. */
  if ((ret = mbedtls_ssl_config_defaults(&tls_data->conf, isServer,
                                         MBEDTLS_SSL_TRANSPORT_STREAM,
                                         MBEDTLS_SSL_PRESET_DEFAULT)) != 0) {
    printf("TLSSocket - SSL config failed with %d\n", ret);
    goto exit;
  }

  /* Set the random number generator callback. */
  mbedtls_ssl_conf_rng(&tls_data->conf, mbedtls_ctr_drbg_random,
                       &tls_data->ctr_drbg);

  /* Set up an SSL context. */
  if ((ret = mbedtls_ssl_setup(&tls_data->ssl, &tls_data->conf)) != 0) {
    printf("TLSSocket - SSL setup failed with %d\n", ret);
    goto exit;
  }

exit:

  return jerry_create_undefined();
}

jerry_value_t InitTls() {
  jerry_value_t jtls = jerry_create_object();

  iotjs_jval_set_method(jtls, IOTJS_MAGIC_STRING_CONNECT, Connect);
  iotjs_jval_set_method(jtls, IOTJS_MAGIC_STRING_TLSSOCKET, TLSSocketCons);

  return jtls;
}
