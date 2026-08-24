import http from 'node:http';
import { URL } from 'node:url';

const fixture = {
  user: 'fixture-user',
  noTwoFaUser: 'fixture-no-2fa-user',
  password: 'fixture-password',
  code: '123456',
  token: 'fixture-token',
  cookie: 'fixture-cookie-value',
  generatedToken: 'fixture-generated-token',
  inboundUser: 'fixture-inbound-secret-user',
  inboundSecret: 'fixture-inbound-out-json-secret',
  clientConfigSecret: 'fixture-client-config-secret',
  clientLinkSecret: 'fixture-client-link-secret',
  clientDescriptionSecret: 'fixture-client-description-secret',
  clientRemarkSecret: 'fixture-client-remark-secret',
  realityPublicKey: 'fixture-reality-public-key',
  realityOverridePublicKey: 'fixture-reality-override-public-key',
  realityShortId: 'a1b2c3d4',
  realityPrivateTrap: 'fixture-reality-private-key-trap',
  hysteriaPassword: 'fixture-hysteria2-client-password',
  hysteriaObfsPassword: 'fixture-hysteria2-obfs-password',
  hysteriaBasePin: 'fixture-hysteria2-base-spki-pin',
  hysteriaOverridePin: 'fixture-hysteria2-override-spki-pin',
  hysteriaTlsPrivateTrap: 'fixture-hysteria2-tls-private-key-trap',
  hysteriaClientLinkTrap: 'fixture-hysteria2-client-link-trap',
  hysteriaDescriptionTrap: 'fixture-hysteria2-description-trap',
};

const e2e = {
  enabled: Boolean(process.env.MYMIHOMO_E2E_VLESS_PORT),
  vlessPort: Number(process.env.MYMIHOMO_E2E_VLESS_PORT ?? 0),
  realityPublicKey: process.env.MYMIHOMO_E2E_REALITY_PUBLIC_KEY ?? '',
  realityShortId: process.env.MYMIHOMO_E2E_REALITY_SHORT_ID ?? '',
  serverName: process.env.MYMIHOMO_E2E_SERVER_NAME ?? '',
  nonce: process.env.MYMIHOMO_E2E_NONCE ?? '',
};
const listenPort = Number(process.env.MYMIHOMO_MOCK_PORT ?? 0);
if (!Number.isInteger(listenPort) || listenPort < 0 || listenPort > 65535) {
  throw new Error('Invalid MYMIHOMO_MOCK_PORT.');
}
if (
  e2e.enabled
  && (
    !Number.isInteger(e2e.vlessPort)
    || e2e.vlessPort < 1
    || e2e.vlessPort > 65535
    || !e2e.realityPublicKey
    || !e2e.realityShortId
    || !e2e.serverName
    || !e2e.nonce
  )
) {
  throw new Error('Incomplete E2E fixture environment.');
}

const tokens = [];
let nextTokenId = 1;
const createdClients = [];
let nextClientId = 100;
let clientsSeq = 42;

function toClientListView(client) {
  return {
    id: client.id,
    enable: client.enable,
    name: client.name,
    inbounds: client.inbounds,
    volume: client.volume,
    expiry: client.expiry,
    down: client.down ?? 0,
    up: client.up ?? 0,
    desc: client.desc ?? '',
    group: client.group ?? '',
    remark: client.remark ?? '',
    limitIp: client.limitIp ?? 0,
    createdAt: client.createdAt ?? 0,
    onlineAt: client.onlineAt ?? 0,
  };
}


function sendJson(response, body, headers = {}) {
  response.writeHead(200, {
    'Content-Type': 'application/json; charset=utf-8',
    ...headers,
  });

  response.end(JSON.stringify(body));
}

function readForm(request, callback) {
  let body = '';
  request.setEncoding('utf8');
  request.on('data', chunk => {
    body += chunk;
  });
  request.on('end', () => callback(new URLSearchParams(body)));
}

const server = http.createServer((request, response) => {
  const url = new URL(request.url, 'http://127.0.0.1');
  if (e2e.enabled && request.method === 'GET' && url.pathname === '/e2e-target') {
    sendJson(response, { ok: true, nonce: e2e.nonce });
    return;
  }

  if (request.method === 'GET' && url.pathname === '/app/login') {
    response.writeHead(200, { 'Content-Type': 'text/html; charset=utf-8' });
    response.end('<!doctype html><title>2S-UI fixture</title>');
    return;
  }

  if (request.method === 'GET' && url.pathname === '/app/apiv2/status') {
    if (request.headers.token === fixture.token || tokens.some(item => item.token === request.headers.token)) {
      sendJson(response, { success: true, msg: '', obj: { sys: { uptime: 1 } } });
    } else {
      sendJson(response, { success: false, msg: 'invalid token', obj: null });
    }
    return;
  }
  if (request.method === 'GET' && url.pathname === '/app/apiv2/inbounds') {
    if (request.headers.token === fixture.token || tokens.some(item => item.token === request.headers.token)) {
      if (e2e.enabled && (!url.searchParams.get('id') || url.searchParams.get('id') === '7')) {
        sendJson(response, {
          success: true,
          msg: '',
          obj: {
            inbounds: [{
              id: 7,
              type: 'vless',
              tag: 'clashxy-e2e-vless',
              listen: '127.0.0.1',
              listen_port: e2e.vlessPort,
              tls_id: 1,
              users: [],
              addrs: [],
              out_json: {
                type: 'vless',
                tag: 'clashxy-e2e-vless',
                server: '127.0.0.1',
                server_port: e2e.vlessPort,
                transport: { type: 'tcp' },
                tls: {
                  enabled: true,
                  server_name: e2e.serverName,
                  insecure: false,
                  utls: { enabled: true, fingerprint: 'chrome' },
                  reality: {
                    enabled: true,
                    public_key: e2e.realityPublicKey,
                    short_id: e2e.realityShortId,
                  },
                },
              },
            }],
          },
        });
        return;
      }
      if (url.searchParams.get('id') === '8') {
        sendJson(response, {
          success: true,
          msg: '',
          obj: {
            inbounds: [{
              id: 8,
              type: 'hysteria2',
              tag: 'fixture-hysteria2',
              listen: '::',
              listen_port: 443,
              tls_id: 4,
              users: [],
              tcp_fast_open: true,
              addrs: [
                { server: 'hy2-one.example.test', server_port: 443, remark: 'hy2-one' },
                {
                  server: 'hy2-two.example.test',
                  server_port: 8443,
                  remark: 'hy2-two',
                  tls: {
                    enabled: true,
                    server_name: 'alt-hy2-sni.example.test',
                    insecure: true,
                    alpn: ['h3'],
                    utls: { enabled: true, fingerprint: 'firefox' },
                    certificate_public_key_sha256: [fixture.hysteriaOverridePin],
                  },
                },
              ],
              out_json: {
                type: 'hysteria2',
                tag: 'fixture-hysteria2',
                server: 'hy2-default.example.test',
                server_port: 443,
                up_mbps: 200,
                down_mbps: 100,
                server_ports: ['20000:20100', '30000'],
                obfs: {
                  type: 'salamander',
                  password: fixture.hysteriaObfsPassword,
                },
                tls: {
                  enabled: true,
                  server_name: 'hy2-sni.example.test',
                  insecure: false,
                  alpn: ['h3'],
                  utls: { enabled: true, fingerprint: 'chrome' },
                  certificate_public_key_sha256: [fixture.hysteriaBasePin],
                  key: fixture.hysteriaTlsPrivateTrap,
                },
              },
            }],
          },
        });
        return;
      }
      sendJson(response, {
        success: true,
        msg: '',
        obj: {
          inbounds: [{
            id: 7,
            type: 'vless',
            tag: 'fixture-vless',
            listen: '::',
            listen_port: 443,
            tls_id: 3,
            users: [fixture.inboundUser],
            addrs: [
              { server: 'edge-one.example.test', server_port: 443, remark: 'edge-one' },
              {
                server: 'edge-two.example.test',
                server_port: 8443,
                remark: 'edge-two',
                tls: {
                  enabled: true,
                  server_name: 'alt-sni.example.test',
                  alpn: ['h2'],
                  utls: { enabled: true, fingerprint: 'firefox' },
                  reality: {
                    enabled: true,
                    public_key: fixture.realityOverridePublicKey,
                    short_id: 'd4c3b2a1',
                  },
                },
              },
            ],
            out_json: {
              type: 'vless',
              tag: 'fixture-vless',
              server: 'default.example.test',
              server_port: 443,
              transport: {
                type: 'ws',
                path: '/fixture-ws',
                headers: { Host: 'cdn.example.test' },
                max_early_data: 2048,
                early_data_header_name: 'Sec-WebSocket-Protocol',
              },
              tls: {
                enabled: true,
                server_name: 'reality.example.test',
                alpn: ['h2', 'http/1.1'],
                utls: { enabled: true, fingerprint: 'chrome' },
                reality: {
                  enabled: true,
                  public_key: fixture.realityPublicKey,
                  short_id: fixture.realityShortId,
                },
              },
              ignored_private_key: fixture.realityPrivateTrap,
              password: fixture.inboundSecret,
            },
          }],
        },
      });
    } else {
      sendJson(response, { success: false, msg: 'invalid token', obj: null });
    }
    return;
  }
  if (request.method === 'GET' && url.pathname === '/app/apiv2/clients') {
    if (request.headers.token === fixture.token || tokens.some(item => item.token === request.headers.token)) {
      const requestedClientId = Number(url.searchParams.get('id') ?? 0);
      if (requestedClientId > 0) {
        const createdClient = createdClients.find(item => item.id === requestedClientId);
        if (createdClient) {
          sendJson(response, {
            success: true,
            msg: '',
            obj: { clients: [createdClient] },
          });
          return;
        }
      }
      if (url.searchParams.get('id') === '12') {
        sendJson(response, {
          success: true,
          msg: '',
          obj: {
            clientsSeq,
            clients: [{
              id: 12,
              enable: true,
              name: 'fixture-hysteria2-client',
              config: {
                hysteria2: {
                  name: 'fixture-hysteria2-user',
                  password: fixture.hysteriaPassword,
                },
              },
              inbounds: [8],
              links: [{ type: 'local', uri: fixture.hysteriaClientLinkTrap }],
              volume: 0,
              expiry: 0,
              down: 0,
              up: 0,
              desc: fixture.hysteriaDescriptionTrap,
              group: 'fixture-hysteria2-group',
              remark: '',
              limitIp: 0,
            }],
          },
        });
        return;
      }
      sendJson(response, {
        success: true,
        msg: '',
        obj: {
          clientsSeq,
          clients: [{
            id: 11,
            enable: true,
            name: 'fixture-client',
            config: { vless: { uuid: fixture.clientConfigSecret, flow: 'xtls-rprx-vision' } },
            inbounds: [7, 9],
            links: [{ type: 'local', uri: fixture.clientLinkSecret }],
            volume: 1000,
            expiry: 2000,
            down: 22,
            up: 11,
            desc: fixture.clientDescriptionSecret,
            group: 'fixture-group',
            remark: fixture.clientRemarkSecret,
            limitIp: 2,
          }, ...createdClients.map(toClientListView)],
        },
      });
    } else {
      sendJson(response, { success: false, msg: 'invalid token', obj: null });
    }
    return;
  }
  if (request.method === 'POST' && url.pathname === '/app/apiv2/save') {
    if (request.headers.token !== fixture.token && !tokens.some(item => item.token === request.headers.token)) {
      sendJson(response, { success: false, msg: 'invalid token', obj: null });
      return;
    }
    readForm(request, form => {
      try {
        if (form.get('object') !== 'clients') {
          sendJson(response, { success: false, msg: 'unsupported fixture save object', obj: null });
          return;
        }
        const action = form.get('action');
        if (action === 'del') {
          const id = JSON.parse(form.get('data') ?? 'null');
          const index = createdClients.findIndex(item => item.id === id);
          if (index < 0) {
            sendJson(response, { success: false, msg: 'client not found', obj: null });
            return;
          }
          createdClients.splice(index, 1);
          clientsSeq += 1;
          sendJson(response, {
            success: true,
            msg: '',
            obj: {
              clientsSeq,
              clients: createdClients.map(toClientListView),
            },
          });
          return;
        }
        if (action !== 'new') {
          sendJson(response, { success: false, msg: 'unsupported fixture save action', obj: null });
          return;
        }
        const client = JSON.parse(form.get('data') ?? '{}');
        const protocols = [
          'mixed', 'socks', 'http', 'shadowsocks', 'shadowsocks16', 'shadowtls',
          'vmess', 'vless', 'anytls', 'trojan', 'naive', 'hysteria', 'tuic', 'hysteria2',
        ];
        const configKeys = client.config ? Object.keys(client.config) : [];
        const validConfig = client.config
          && (configKeys.length === 0 || protocols.every(key => typeof client.config[key] === 'object'));
        if (
          typeof client.name !== 'string'
          || !client.name.startsWith('clashxy-lab-')
          || !Array.isArray(client.inbounds)
          || !Array.isArray(client.links)
          || !validConfig
        ) {
          sendJson(response, { success: false, msg: 'invalid client schema', obj: null });
          return;
        }
        client.id = nextClientId++;
        client.createdAt = 1234;
        client.up = 0;
        client.down = 0;
        createdClients.push(client);
        clientsSeq += 1;
        sendJson(response, {
          success: true,
          msg: '',
          obj: {
            clientsSeq,
            clients: [toClientListView(client)],
          },
        });
      } catch {
        sendJson(response, { success: false, msg: 'invalid client JSON', obj: null });
      }
    });
    return;
  }




  if (request.method === 'GET' && url.pathname === '/app/api/tokens') {
    const cookie = request.headers.cookie ?? '';
    if (!cookie.includes('s-ui=')) {
      sendJson(response, { success: false, msg: 'Invalid login', obj: null });
      return;
    }
    sendJson(response, {
      success: true,
      msg: '',
      obj: tokens.map(item => ({ id: item.id, desc: item.desc, token: '****', expiry: item.expiry })),
    });
    return;
  }

  if (request.method === 'POST' && url.pathname === '/app/api/addToken') {
    const cookie = request.headers.cookie ?? '';
    if (!cookie.includes('s-ui=')) {
      sendJson(response, { success: false, msg: 'Invalid login', obj: null });
      return;
    }
    readForm(request, form => {
      const record = {
        id: String(nextTokenId++),
        desc: form.get('desc') ?? '',
        expiry: Number(form.get('expiry') ?? 0),
        token: fixture.generatedToken,
      };
      tokens.push(record);
      sendJson(response, { success: true, msg: '', obj: record.token });
    });
    return;
  }

  if (request.method === 'POST' && url.pathname === '/app/api/deleteToken') {
    const cookie = request.headers.cookie ?? '';
    if (!cookie.includes('s-ui=')) {
      sendJson(response, { success: false, msg: 'Invalid login', obj: null });
      return;
    }
    readForm(request, form => {
      const index = tokens.findIndex(item => item.id === form.get('id'));
      if (index >= 0) tokens.splice(index, 1);
      sendJson(response, { success: true, msg: '', obj: null });
    });
    return;
  }

  if (request.method === 'GET' && url.pathname === '/app/api/logout') {
    sendJson(
      response,
      { success: true, msg: '', obj: null },
      { 'Set-Cookie': 's-ui=; Path=/; Max-Age=0; HttpOnly; SameSite=Lax' },
    );
    return;
  }

  if (request.method === 'POST' && url.pathname === '/app/api/login') {
    let body = '';
    request.setEncoding('utf8');
    request.on('data', chunk => {
      body += chunk;
    });
    request.on('end', () => {
      const form = new URLSearchParams(body);
      const user = form.get('user');
      if (![fixture.user, fixture.noTwoFaUser].includes(user) || form.get('pass') !== fixture.password) {
        sendJson(response, { success: false, msg: 'invalid username or password', obj: null });
        return;
      }
      if (user === fixture.noTwoFaUser) {
        sendJson(
          response,
          { success: true, msg: '', obj: null },
          { 'Set-Cookie': `s-ui=${fixture.cookie}; Path=/; HttpOnly; SameSite=Lax` },
        );
        return;
      }
      if (!form.get('code')) {
        sendJson(response, { success: false, msg: '', obj: { twoFa: true } });
        return;
      }
      if (form.get('code') !== fixture.code) {
        sendJson(response, { success: false, msg: 'invalid two-factor code', obj: null });
        return;
      }
      sendJson(
        response,
        { success: true, msg: '', obj: null },
        { 'Set-Cookie': `s-ui=${fixture.cookie}; Path=/; HttpOnly; SameSite=Lax` },
      );
    });
    return;
  }

  response.writeHead(404, { 'Content-Type': 'text/plain; charset=utf-8' });
  response.end('not found');
});

server.listen(listenPort, '127.0.0.1', () => {
  const address = server.address();
  process.stdout.write(JSON.stringify({ port: address.port }) + '\n');
});

for (const signal of ['SIGINT', 'SIGTERM']) {
  process.on(signal, () => {
    server.close(() => process.exit(0));
  });
}
