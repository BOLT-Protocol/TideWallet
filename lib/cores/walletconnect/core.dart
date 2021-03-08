import 'dart:convert';
import 'dart:async';
import 'dart:convert';
import 'dart:io';
// import 'package:socket_io_client/socket_io_client.dart';
import 'package:tidewallet3/helpers/logger.dart';
import 'package:web_socket_channel/io.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:uuid/uuid.dart';

import '../../helpers/cryptor.dart';

part 'error.dart';
part 'ctypto.dart';
part 'transport.dart';
part 'event_manager.dart';
part 'mode.dart';

class Connector {
  String protocol = 'wc';
  String _key;
  int version = 1;
  String _bridge = '';
  String _clientId;
  PeerMeta _clientMeta;
  bool _connected = false;
  // WCSession session;
  EventManager _eventManager;
  Transport _transport;
  String _handshakeTopic;
  int _handshakeId;
  String _peerId;
  PeerMeta _peerMeta;
  int _chainId = 0;
  int _networkId = 0;
  String _rpcUrl = '';
  List<String> _accounts = [];

  set bridge(String value) {
    this._bridge = value;
  }

  set key(String value) {
    this._key = value;
  }

  set clientId(String value) {
    this._clientId = value;
  }

  set handshakeId(int value) {
    this._handshakeId = value;
  }

  set handshakeTopic(String value) {
    this._handshakeTopic = value;
  }

  set peerId(String value) {
    this._peerId = value;
  }

  set peerMeta(PeerMeta value) {
    this._peerMeta = value;
  }

  set chainId(int value) {
    this._chainId = value;
  }

  set networkId(int value) {
    this._networkId = value;
  }

  set accounts(List<String> value) {
    this._accounts = value;
  }

  set clientMeta(PeerMeta value) {
    this._clientMeta = value;
  }

  set session(WCSession value) {
    this._connected = value.connected;
    this.accounts = value.accounts;
    this.chainId = value.chainId;
    this.bridge = value.bridge;
    this.key = value.key;
    this.clientId = value.clientId;
    this.clientMeta = value.clientMeta;
    this.peerId = value.peerId;
    this.handshakeId = value.handshakeId;
    this.handshakeTopic = value.handshakeTopic;
  }

  bool get connected => this._connected;

  String get bridge => this._bridge;

  String get key => this._key;

  String get clientId {
    if (this._clientId == null) this._clientId = Uuid().v4();
    return this._clientId;
  }

  PeerMeta get clientMeta => this._clientMeta;

  int get chainId => this._chainId;

  int get networkId => this._networkId;

  List<String> get accounts => this._accounts;

  Connector(ConnectorOpts opt) {
    this._eventManager = EventManager();
    this.bridge = opt.session.bridge;
    this._transport = Transport(url: this._bridge);

    this.session = opt.session ?? this._getStorageSession();

    this._transport.subscribe(opt.session.peerId);
    this._subscribeToInternalEvents();
    this._initTransport();
  }

  onEvt(String evt, Function callback) {
    final event = Event(evt, callback);

    this._eventManager.subscribe(event);
  }

  connect() {
    if (this.connected) {}
  }

  createSession() {
    if (this.connected) {
      throw (ERROR_SESSION.CONNECTED);
    }
  }

  approveSession(WCSession session) {
    this.chainId = session.chainId;
    this.networkId = session.networkId;
    this.accounts = session.accounts;

    print('approveSession');

    final req = {
      'id': this._handshakeId,
      'jsonrpc': '2.0',
      'result': {
        "approved": true,
        "chainId": this.chainId ?? 1,
        "networkId": this.networkId ?? 0,
        "accounts": this.accounts ?? [],
        "rpcUrl": "",
        'peerId': this.clientId,
        'peerMeta': this.clientMeta
      }
    };

    final iv = Crypto.genIV();
    final encrypt = json.encode(req);
        Log.debug(encrypt);
        Log.debug('KK ${this._key}');
        Log.debug('IV ${iv}');

    final data = Crypto.encrypt(encrypt, this._key, iv);

            Log.debug('data $data');

    final hmac = Crypto.hmac(data + iv, this._key);
                Log.debug('hmac $hmac');

    final payload = {'data': data, 'iv': iv, 'hmac': hmac};
    Log.debug(payload);

    this._sendResponse(json.encode(payload), this._peerId);
  }

  _initTransport() {
    this._transport.events.listen((event) {
      Log.info('T listen $event');
      switch (event.evt) {
        case T_EVT.MESSAGE:
          this._handleIncomingMessages(event.value);
          break;
        case T_EVT.OPEN:
          break;
        default:
          Log.error('UNKNOWN => ${event.evt}');
      }
    });
  }

  _handleIncomingMessages(WCMessage v) {
    Log.warning('Handle the MTF ${this._key}');
    final payload = WCPayload.fromJson(json.decode(v.payload));
    final verified = this.verifyHMAC(payload.data, payload.iv, payload.hmac);
    assert(verified == true);
    final d = Crypto.decrypto(payload.data, this._key, payload.iv);
    Log.debug(d);

    this._eventManager.trigger(WCRequest.fromJson(json.decode(d)));
  }

  _subscribeToInternalEvents() {
    this.onEvt('wc_sessionRequest', (WCRequest req) {
      this.handshakeId = req.id;
      this.peerId = req.params[0]['peerId'];

      // TODO:
      this.peerMeta = null;

      // TODO:
      // trigger "session_request" event
    });
  }

  _sendResponse(String msg, String topic) {
    this._transport.send(msg, topic);
  }

  WCSession _getStorageSession() {
    // TODO:
  }

  // _formatRequest(Map req) {}

  // _formatResponse() {}

  bool verifyHMAC(String message, String iv, String hmac) {
    final resource = message + iv;
    return Crypto.hmac(resource, this._key) == hmac;
  }

  // TODO:
  static ConnectionEl parseUri(String uri) {
    try {
      var tmp = uri.split('bridge=');
      final b = tmp[0].replaceAll('wc:', '').split('@');
      final topic = b[0];
      final version = b[1];
      final d = tmp[1];
      tmp = d.split('&key=');
      final url = tmp[0].replaceAll('https%3A%2F%2F', 'wss://');
      final key = tmp[1];

      return ConnectionEl(
          topic: topic, version: int.tryParse(version), bridge: url, key: key);
    } catch (e) {
      return null;
    }
  }
}
