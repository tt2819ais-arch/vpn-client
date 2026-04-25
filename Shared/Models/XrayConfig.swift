import Foundation

/// Builds an Xray-core JSON configuration for a given server profile.
/// The output is consumed by libXray inside the PacketTunnelProvider.
public enum XrayConfigBuilder {

    /// Russian whitelist used for `RoutingMode.bypassWhitelist`.
    /// Domains here go through the `direct` outbound; everything else flows through `proxy`.
    /// The list mirrors the user-provided reference config.
    public static let russianWhitelistDomains: [String] = [
        "domain:2gis.com", "domain:2gis.ru", "domain:47news.ru", "domain:alfabank.ru",
        "domain:akashi.vk-portal.net", "domain:api.browser.yandex.com",
        "domain:api.events.plus.yandex.net", "domain:api.photo.2gis.com",
        "domain:api.premier.one", "domain:api.okko.tv", "domain:api.reviews.2gis.com",
        "domain:api.s3.yandex.net", "domain:api.uxfeedback.yandex.net",
        "domain:auth-nsdi.ru", "domain:auth.okko.tv", "domain:auth.premier.one",
        "domain:auto.ru", "domain:avatars.mds.yandex.com", "domain:avatars.mds.yandex.net",
        "domain:avito.ru", "domain:avito.st", "domain:browser.yandex.com",
        "domain:cdn.okko.tv", "domain:cdn.premier.one", "domain:cdn-vk.ru",
        "domain:cdn.s3.yandex.net", "domain:cikrf.ru", "domain:cloud.cdn.yandex.com",
        "domain:cloud.cdn.yandex.net", "domain:cloud.vk.com",
        "domain:collections.yandex.com", "domain:csp.yandex.net",
        "domain:dr.yandex.net", "domain:dr2.yandex.net", "domain:dzen.ru",
        "domain:egress.yandex.net", "domain:eh.vk.com", "domain:favicon.yandex.com",
        "domain:favicon.yandex.net", "domain:gazeta.ru", "domain:gismeteo.com",
        "domain:gosuslugi.ru", "domain:gov.ru", "domain:government.ru",
        "domain:gu-st.ru", "domain:hh.ru", "domain:img.okko.tv", "domain:img.premier.one",
        "domain:izbirkom.ru", "domain:kiks.yandex.com", "domain:kinopoisk.ru",
        "domain:kp.ru", "domain:kremlin.ru", "domain:lemanapro.ru", "domain:lenta.ru",
        "domain:lmru.tech", "domain:login.vk.com", "domain:m.okko.tv", "domain:mail.ru",
        "domain:mail.yandex.com", "domain:max.ru", "domain:mc.yandex.com",
        "domain:mediafeeds.yandex.com", "domain:mradx.net", "domain:my.okko.tv",
        "domain:my.premier.one", "domain:ok.ru", "domain:okcdn.ru", "domain:okko.tv",
        "domain:oneme.ru", "domain:ozon.ru", "domain:ozone.ru", "domain:pochta.ru",
        "domain:premier.one", "domain:rambler.ru", "domain:rbc.ru",
        "domain:rutube.ru", "domain:rutubelist.ru", "domain:rzd.ru",
        "domain:s3.yandex.net", "domain:sba.yandex.com", "domain:sba.yandex.net",
        "domain:speller.yandex.net", "domain:static-mon.yandex.net",
        "domain:static.okko.tv", "domain:static.premier.one", "domain:stats.okko.tv",
        "domain:storage.ape.yandex.net", "domain:strm.yandex.net",
        "domain:supermarket.lenta.com", "domain:t2.ru", "domain:taximaxim.ru",
        "domain:travel.yastatic.net", "domain:tutu.ru", "domain:tv.okko.tv",
        "domain:userapi.com", "domain:vk.com", "domain:vk-portal.net", "domain:vk.ru",
        "domain:vtb.ru", "domain:wap.yandex.com", "domain:wb.ru",
        "domain:wildberries.ru", "domain:ya.ru", "domain:yandex.com",
        "domain:yandex.net", "domain:yandex.ru", "domain:yastatic.net",
        "domain:zen.yandex.com", "domain:zen.yandex.net"
    ]

    public static func build(for server: Server, dataDir: URL) -> [String: Any] {
        let logDir = dataDir.appendingPathComponent("logs", isDirectory: true)
        try? FileManager.default.createDirectory(at: logDir, withIntermediateDirectories: true)

        var routingRules: [[String: Any]] = [
            [
                "type": "field",
                "ip": ["geoip:private"],
                "outboundTag": "block"
            ],
            [
                "type": "field",
                "protocol": ["bittorrent"],
                "outboundTag": "block"
            ]
        ]

        if server.routing == .bypassWhitelist {
            routingRules.insert(
                [
                    "type": "field",
                    "domain": Self.russianWhitelistDomains,
                    "outboundTag": "direct"
                ],
                at: 0
            )
        }

        let outbound: [String: Any] = [
            "protocol": "vless",
            "tag": "proxy",
            "settings": [
                "vnext": [[
                    "address": server.address,
                    "port": server.port,
                    "users": [[
                        "id": server.uuid,
                        "encryption": "none",
                        "flow": server.flow
                    ]]
                ]]
            ],
            "streamSettings": [
                "network": "tcp",
                "security": "reality",
                "realitySettings": [
                    "fingerprint": server.fingerprint,
                    "publicKey": server.publicKey,
                    "serverName": server.serverName,
                    "shortId": server.shortId,
                    "spiderX": server.spiderX ?? ""
                ],
                "tcpSettings": [:]
            ]
        ]

        return [
            "log": [
                "loglevel": "warning",
                "access": logDir.appendingPathComponent("access.log").path,
                "error":  logDir.appendingPathComponent("error.log").path,
                "dnsLog": false
            ],
            "dns": [
                "queryStrategy": "UseIPv4",
                "servers": [
                    "https://1.1.1.1/dns-query",
                    "https://dns.google/dns-query"
                ]
            ],
            "stats": [:],
            "policy": [
                "levels": [
                    "0": [
                        "statsUserUplink": true,
                        "statsUserDownlink": true
                    ]
                ],
                "system": [
                    "statsInboundUplink": true,
                    "statsInboundDownlink": true,
                    "statsOutboundUplink": true,
                    "statsOutboundDownlink": true
                ]
            ],
            "inbounds": [
                [
                    "tag": "socks",
                    "listen": "127.0.0.1",
                    "port": 10808,
                    "protocol": "socks",
                    "settings": [
                        "auth": "noauth",
                        "udp": true
                    ],
                    "sniffing": [
                        "enabled": true,
                        "destOverride": ["http", "tls", "quic"]
                    ]
                ],
                [
                    "tag": "http",
                    "listen": "127.0.0.1",
                    "port": 10809,
                    "protocol": "http",
                    "settings": ["allowTransparent": false],
                    "sniffing": [
                        "enabled": true,
                        "destOverride": ["http", "tls", "quic"]
                    ]
                ]
            ],
            "outbounds": [
                outbound,
                ["protocol": "freedom", "tag": "direct"],
                ["protocol": "blackhole", "tag": "block"]
            ],
            "routing": [
                "domainStrategy": "IPIfNonMatch",
                "rules": routingRules
            ],
            "remarks": server.name
        ]
    }

    public static func jsonString(for server: Server, dataDir: URL) throws -> String {
        let dict = build(for: server, dataDir: dataDir)
        let data = try JSONSerialization.data(withJSONObject: dict, options: [.prettyPrinted, .sortedKeys])
        guard let string = String(data: data, encoding: .utf8) else {
            throw NSError(domain: "XrayConfigBuilder", code: 1)
        }
        return string
    }
}
