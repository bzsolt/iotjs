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

var net = require('net');
var util = require('util');

function Tls() {
}

Tls.Server = function(options) {
  return net.Server(options);
}

Tls.Server.prototype.addContext = function(hostname, context) {
  if (!util.isString(hostname)) {
    throw new TypeError('hostname must be a string');
  }

  if (!util.isObject(context)) {
    throw new TypeError('context must be an object');
  }
}

Tls.Server.prototype.address = function() {
}

Tls.Server.prototype.close = function(callback) {
  if (callback && !util.isFunction(callback)) {
    throw new TypeError('callback must be a function');
  }
}

Tls.Server.prototype.getTicketKeys = function() {
}

Tls.Server.prototype.listen = function() {
}

Tls.Server.prototype.setTicketKeys = function(keys) {
  if (!util.isBuffer(keys)) {
    throw new TypeError('keys must be a buffer');
  }
}


Tls.TLSSocket = function(socket, opts) {
  var _socket = socket;

  if (!_socket || !(socket instanceof net.Socket)) {
    _socket = new net.Socket();
  }

  this.encrypted = true;
  this.isServer = !!opts.isServer || false;
  this.requestCert = !!opts.requestCert || false;

  if (opts.NPNProtocols && !util.isBuffer(opts.NPNProtocols)) {
    throw new TypeError('TLSSocket - options.NPNProtocols should be a buffer.');
  }

  if (opts.ALPNProtocols && !util.isBuffer(opts.ALPNProtocols)) {
    throw new TypeError('TLSSocket - options.ALPNProtocols should be a buffer.');
  }

  if (opts.SNICallback && !util.isFunction(opts.SNICallback)) {
    throw new TypeError('TLSSocket - options.SNICallback should be a function.');
  }

  if (opts.session && !util.isBuffer(opts.session)) {
    throw new TypeError('TLSSocket - options.session should be a buffer.');
  }

  this.secureContext = opts.secureContext || createSecureContext(opts);

  return new native.TLSSocket(_socket);
}

Tls.TLSSocket.prototype.address = function() {
}

Tls.TLSSocket.prototype.disableRenegotiation = function() {
  this.disableRenegotiation = true;
}

Tls.TLSSocket.prototype.encrypted = function() {
  return this.encrypted;
}

Tls.TLSSocket.prototype.getCipher = function() {
}

Tls.TLSSocket.prototype.getEphemeralKeyInfo = function() {
}

Tls.TLSSocket.prototype.getPeerCertificate = function(detailed) {
}

Tls.TLSSocket.prototype.getProtocol = function() {
}

Tls.TLSSocket.prototype.getSession = function() {
}

Tls.TLSSocket.prototype.getTLSTicket = function() {
}

Tls.TLSSocket.prototype.renegotiate = function(options, callback) {
  if (!util.isObject(options)) {
    throw new TypeError('options should be an object');
  }

  if (callback && !util.isFunction(callback)) {
    throw new TypeError('callback should be a function');
  }
}

Tls.TLSSocket.prototype.setMaxSendFragment = function(size) {
  if (!util.isNumber(size)) {
    throw new TypeError('size should be a number');
  }
}

Tls.connect = function(options) {
  if (options.socket || options.path) {
    this._socket = options.socket || options.path;
  } else {
    this._socket = options.socket || new net.Socket;
    this.host = options.host || "localhost";
    this.port = options.port;

    // If no previous socket was defined we have to handle connecting
    // the socket to the host and port.
    //this._socket.connect(this.port, this.host);
    //this._socket.end('js socket end');
  }
  this.servername = options.servername || "default";
  this.session = options.session;
  this.minDHSize = options.minDHSize || 1024;
  // this.secureContext = options.secureContext || Tls.createSecureContext();


  var res = native.connect(this.port.toString(), this.host, this.servername);
  if (util.isString(res)) {
    throw new Error(res);
  }

  return this._socket;
}

Tls.createSecureContext = function(options) {
  this.pfx = options.pfx;
  this.key = options.key;
  this.passphrase = options.passphras;
  this.cert = options.cert;
  this.ca = options.ca;
  this.ciphers = options.ciphers;
  this.honorCipherOrder = false;
  this.ecdhCurve = options.ecdhCurve;
  this.clientCertEngine = options.clientCertEngine;
  this.crl = options.crl;
  if (options.dhparam && options.dhparam.length < 128) {
    throw new RangeError("Key length must be at least 1024 bits (128 characters)");
  }
  this.dhparam = options.dhparam;

}

Tls.checkServerIdentity = function(host, cert) {
  return undefined;
}

Tls.createServer = function(options, secureConnectionListener) {
  var server = new Server(options);

  if (secureConnectionListener && util.isFunction(secureConnectionListener)) {
    server.on('secureConnection', secureConnectionListener);
  }

  return server;
}

module.exports = Tls;
