// Define main function (script entry)

//function main(config, profileName) {
// return config;}
// Define the `main` function

// local DNS servers
const domesticNameservers = [
 "https://public.dns.iij.jp/dns-query",
 "https://101.101.101.101/dns-query" // TWNIC
  // "https://doh.apad.pro/dns-query", //DNS Intergated 
  // "https://dns.alidns.com/dns-query", // 阿里云公共DNS
  // "https://doh.pub/dns-query", // 腾讯DNSPod
  // "https://dns.twnic.tw/dns-query" //TWNIC
  // "https://doh.360.cn/dns-query", // 360安全DNS

];
// remote DNS servers
const foreignNameservers = [
  "https://1.0.0.1/dns-query", // Cloudflare(main)
  "https://security.cloudflare-dns.com/dns-query",// Cloudflare(Security)
   // IIJ JP Public DNS
  "https://dns.google/dns-query"//Google DNS
  // "https://doh.dns.sb/dns-query", //DNS.SB
  // "https://194.242.2.2/dns-query", // Mullvad(main)
  // "https://194.242.2.3/dns-query" // Mullvad(back)   
  // "https://208.67.222.222/dns-query", // OpenDNS(main)
  // "https://208.67.220.220/dns-query", // OpenDNS(back)
  // "https://unfiltered.adguard-dns.com/dns-query", //Adguard DNS
  // "https://dns.adguard-dns.com/dns-query", //Adguard DNS
];
// DNS config
const dnsConfig = {
  dns: true,
  listen: 1053,
  ipv6: true,
  "use-hosts": true,
  "cache-algorithm": "arc",
  "enhanced-mode": "fake-ip",
  "fake-ip-range": "198.18.0.1/16",
  "fake-ip-filter": [
    "+.lan",
    "+.local",
    "+.msftconnecttest.com",
    "+.msftncsi.com",
  ],
  "default-nameserver": ["168.95.1.1", "103.2.57.5", "223.5.5.5", "119.29.29.29"],//
  nameserver: [...domesticNameservers, ...foreignNameservers],
  "proxy-server-nameserver": [...foreignNameservers],
  "nameserver-policy": {
    "geosite:private,cn,geolocation-cn": domesticNameservers,
    "geosite:google,youtube,telegram,gfw,geolocation-!cn": foreignNameservers,
  },
};
// 规则集通用配置
const ruleProviderCommon = {
  type: "http",
  format: "yaml",
  interval: 86400,
};
// 规则集配置
const ruleProviders = {
   aesincidr: {
    ...ruleProviderCommon,
    behavior: "ipcidr",
    url: "https://rawhub.pages.dev/main/self/ipcidr.list?token=visa",
    path: "./rulesets/eslco/ipcidr.yaml",
  },
    aesindomain: {
    ...ruleProviderCommon,
    behavior: "domain",
    url: "https://rawhub.pages.dev/main/self/domain.list?token=visa",
    path: "./rulesets/esloc/domain.yaml",
  },
    wotb: {
    ...ruleProviderCommon,
    behavior: "domain",
    url: "https://raw.githubusercontent.com/eslco/base/main/rule/Clash/Wotb.list",
    path: "./rulesets/254c/Wotb.yaml",
  },
  reject: {
    ...ruleProviderCommon,
    behavior: "domain",
    url: "https://fastly.jsdelivr.net/gh/Loyalsoldier/clash-rules@release/reject.txt",
    path: "./rulesets/loyalsoldier/reject.yaml",
  },
  icloud: {
    ...ruleProviderCommon,
    behavior: "domain",
    url: "https://fastly.jsdelivr.net/gh/Loyalsoldier/clash-rules@release/icloud.txt",
    path: "./rulesets/loyalsoldier/icloud.yaml",
  },
  apple: {
    ...ruleProviderCommon,
    behavior: "domain",
    url: "https://fastly.jsdelivr.net/gh/Loyalsoldier/clash-rules@release/apple.txt",
    path: "./rulesets/loyalsoldier/apple.yaml",
  },
  google: {
    ...ruleProviderCommon,
    behavior: "domain",
    url: "https://fastly.jsdelivr.net/gh/Loyalsoldier/clash-rules@release/google.txt",
    path: "./rulesets/loyalsoldier/google.yaml",
  },
  proxy: {
    ...ruleProviderCommon,
    behavior: "domain",
    url: "https://fastly.jsdelivr.net/gh/Loyalsoldier/clash-rules@release/proxy.txt",
    path: "./rulesets/loyalsoldier/proxy.yaml",
  },
  direct: {
    ...ruleProviderCommon,
    behavior: "domain",
    url: "https://fastly.jsdelivr.net/gh/Loyalsoldier/clash-rules@release/direct.txt",
    path: "./rulesets/loyalsoldier/direct.yaml",
  },
  private: {
    ...ruleProviderCommon,
    behavior: "domain",
    url: "https://fastly.jsdelivr.net/gh/Loyalsoldier/clash-rules@release/private.txt",
    path: "./rulesets/loyalsoldier/private.yaml",
  },
  gfw: {
    ...ruleProviderCommon,
    behavior: "domain",
    url: "https://fastly.jsdelivr.net/gh/Loyalsoldier/clash-rules@release/gfw.txt",
    path: "./rulesets/loyalsoldier/gfw.yaml",
  },
  "tld-not-cn": {
    ...ruleProviderCommon,
    behavior: "domain",
    url: "https://fastly.jsdelivr.net/gh/Loyalsoldier/clash-rules@release/tld-not-cn.txt",
    path: "./rulesets/loyalsoldier/tld-not-cn.yaml",
  },
  telegramcidr: {
    ...ruleProviderCommon,
    behavior: "ipcidr",
    url: "https://fastly.jsdelivr.net/gh/Loyalsoldier/clash-rules@release/telegramcidr.txt",
    path: "./rulesets/loyalsoldier/telegramcidr.yaml",
  },
  cncidr: {
    ...ruleProviderCommon,
    behavior: "ipcidr",
    url: "https://fastly.jsdelivr.net/gh/Loyalsoldier/clash-rules@release/cncidr.txt",
    path: "./rulesets/loyalsoldier/cncidr.yaml",
  },
  lancidr: {
    ...ruleProviderCommon,
    behavior: "ipcidr",
    url: "https://fastly.jsdelivr.net/gh/Loyalsoldier/clash-rules@release/lancidr.txt",
    path: "./rulesets/loyalsoldier/lancidr.yaml",
  },
  applications: {
    ...ruleProviderCommon,
    behavior: "classical",
    url: "https://fastly.jsdelivr.net/gh/Loyalsoldier/clash-rules@release/applications.txt",
    path: "./rulesets/loyalsoldier/applications.yaml",
  },
};
// 规则
const rules = [
  //254c Rule
  "RULE-SET,aesindomain,Proxy", //Domain
  "RULE-SET,aesincidr,Proxy,no-resolve",// IPCIDR
  "RULE-SET,wotb,Gaming", //Wotb Wargaming.net
  "DOMAIN-SUFFIX,ipip.net,Proxy",
  "DOMAIN-SUFFIX,en.ipip.net,Proxy",
  //
  "DOMAIN-SUFFIX,ip138.com,DirectO",
  "DOMAIN-SUFFIX,ipv4dns.com,DirectO",
  "DOMAIN-SUFFIX,alicdn.com,DirectO",
  "DOMAIN-SUFFIX,ipchaxun.com,DirectO",
  "DOMAIN-SUFFIX,speedtest.cn,DirectO",
  //
  "DOMAIN-SUFFIX,ip.sb,Proxy",
  "DOMAIN-SUFFIX,ip-api.com,Proxy",
  "DOMAIN-SUFFIX,ip.skk.moe,Proxy",
  "DOMAIN-SUFFIX,ipinfo.io,Proxy",
  "DOMAIN-SUFFIX,api.myip.com,Proxy",
  //  

  "DOMAIN-SUFFIX,en.ipip.net,Proxy",
  // 自定义规则
  "DOMAIN-SUFFIX,googleapis.cn,Proxy", // Google服务
  "DOMAIN-SUFFIX,gstatic.com,Proxy", // Google静态资源
  "DOMAIN-SUFFIX,xn--ngstr-lra8j.com,Proxy", // Google Play下载服务
  "DOMAIN-SUFFIX,github.io,Proxy", // Github Pages
  "DOMAIN,v2rayse.com,Proxy", // V2rayse节点工具
  // Loyalsoldier 规则集
  "RULE-SET,reject,BanAD",
  "RULE-SET,icloud,Microsoft",
  "RULE-SET,apple,Apple",
  "RULE-SET,google,Google",
  "RULE-SET,proxy,Proxy",
  "RULE-SET,gfw,Proxy",
  "RULE-SET,tld-not-cn,Proxy",
  "RULE-SET,applications,DirectO",
  "RULE-SET,telegramcidr,Telegram,no-resolve",
  "RULE-SET,direct,DirectO",
  "RULE-SET,cncidr,DirectO",
  // 其他规则
  "RULE-SET,lancidr,DIRECT,no-resolve",
  "RULE-SET,private,DIRECT,no-resolve",
  "GEOIP,LAN,DIRECT,no-resolve",
  "GEOIP,CN,DirectO",
  "MATCH,Final",
];
// 代理组通用配置
const groupBaseOption = {
  interval: 300,
  timeout: 3000,
  url: "https://www.apple.com/library/test/success.html",
  lazy: true,
  "max-failed-times": 3,
  hidden: false,
};

// 程序入口
function main(config) {
  const proxyCount = config?.proxies?.length ?? 0;
  const proxyProviderCount =
    typeof config?.["proxy-providers"] === "object"
      ? Object.keys(config["proxy-providers"]).length
      : 0;
  if (proxyCount === 0 && proxyProviderCount === 0) {
    throw new Error("no proxies found in config of this profile 配置文件中未找到任何代理");
  }

  // 覆盖原配置中DNS配置
  config["dns"] = dnsConfig;

  // 覆盖原配置中的代理组
  config["proxy-groups"] = [
    {
      ...groupBaseOption,
      name: "Proxy",
      type: "select",
      proxies: ["URLTest", "FallBack", "LB-Hashing", "LB-Robin", "DIRECT"],
      "include-all": true,
      icon: "https://fastly.jsdelivr.net/gh/clash-verge-rev/clash-verge-rev.github.io@main/docs/assets/icons/adjust.svg",
    },
    {
      ...groupBaseOption,
      name: "DirectO",
      type: "select",
      proxies: [
        "DIRECT",
        "Proxy",
        "Final"
      ],
      "include-all": false,
      icon: "https://fastly.jsdelivr.net/gh/clash-verge-rev/clash-verge-rev.github.io@main/docs/assets/icons/adjust.svg",
    }, 
    {
      ...groupBaseOption,
      name: "URLTest",
      type: "url-test",
      tolerance: 100,
      "include-all": true,
      icon: "https://fastly.jsdelivr.net/gh/clash-verge-rev/clash-verge-rev.github.io@main/docs/assets/icons/speed.svg",
    },
    {
      ...groupBaseOption,
      name: "FallBack",
      type: "fallback",
      "include-all": true,
      icon: "https://fastly.jsdelivr.net/gh/clash-verge-rev/clash-verge-rev.github.io@main/docs/assets/icons/ambulance.svg",
    },
    {
      ...groupBaseOption,
      name: "LB-Hashing",
      type: "load-balance",
      strategy: "consistent-hashing",
      "include-all": true,
      icon: "https://fastly.jsdelivr.net/gh/clash-verge-rev/clash-verge-rev.github.io@main/docs/assets/icons/merry_go.svg",
    },
    {
      ...groupBaseOption,
      name: "LB-Robin",
      type: "load-balance",
      strategy: "round-robin",
      "include-all": true,
      icon: "https://fastly.jsdelivr.net/gh/clash-verge-rev/clash-verge-rev.github.io@main/docs/assets/icons/balance.svg",
    },
    
    {
      ...groupBaseOption,
      name: "Gaming",
      type: "select",
      proxies: ["Proxy","FallBack", "LB-Hashing", "LB-Robin"],
      "include-all": true,
      icon: "https://fastly.jsdelivr.net/gh/Koolson/Qure@master/IconSet/Color/Game.png",
    },
    {
      ...groupBaseOption,
      name: "Google",
      type: "select",
      proxies: [
        "Proxy",
        "URLTest",
        "FallBack",
        "LB-Hashing",
        "LB-Robin",
        "DirectO",
      ],
      "include-all": true,
      icon: "https://fastly.jsdelivr.net/gh/clash-verge-rev/clash-verge-rev.github.io@main/docs/assets/icons/google.svg",
    },
    {
      ...groupBaseOption,
      name: "ProxyMedia",
      type: "select",
      proxies: [
        "Proxy",
        "URLTest",
        "FallBack",
        "LB-Hashing",
        "LB-Robin",
        "DirectO",
      ],
      "include-all": true,
      icon: "https://fastly.jsdelivr.net/gh/clash-verge-rev/clash-verge-rev.github.io@main/docs/assets/icons/youtube.svg",
    },
    {
      ...groupBaseOption,
      name: "Telegram",
      type: "select",
      proxies: [
        "Proxy",
        "URLTest",
        "FallBack",
        "LB-Hashing",
        "LB-Robin",
        "DirectO",
      ],
      "include-all": true,
      icon: "https://fastly.jsdelivr.net/gh/clash-verge-rev/clash-verge-rev.github.io@main/docs/assets/icons/telegram.svg",
    },
    {
      ...groupBaseOption,
      name: "Microsoft",
      type: "select",
      proxies: [
        "DirectO",
        "Proxy",
        "URLTest",
        "FallBack",
        "LB-Hashing",
        "LB-Robin",
      ],
      "include-all": true,
      icon: "https://fastly.jsdelivr.net/gh/clash-verge-rev/clash-verge-rev.github.io@main/docs/assets/icons/microsoft.svg",
    },
    {
      ...groupBaseOption,
      name: "Apple",
      type: "select",
      proxies: [
        "Proxy",
        "URLTest",
        "FallBack",
        "LB-Hashing",
        "LB-Robin",
        "DirectO",
      ],
      "include-all": true,
      icon: "https://fastly.jsdelivr.net/gh/clash-verge-rev/clash-verge-rev.github.io@main/docs/assets/icons/apple.svg",
    },
    {
      ...groupBaseOption,
      name: "BanAD",
      type: "select",
      proxies: ["REJECT", "DIRECT"],
      icon: "https://fastly.jsdelivr.net/gh/clash-verge-rev/clash-verge-rev.github.io@main/docs/assets/icons/bug.svg",
    },
    
    {
      ...groupBaseOption,
      name: "Block",
      type: "select",
      proxies: ["REJECT", "DIRECT"],
      icon: "https://fastly.jsdelivr.net/gh/clash-verge-rev/clash-verge-rev.github.io@main/docs/assets/icons/block.svg",
    },
    {
      ...groupBaseOption,
      name: "Final",
      type: "select",
      proxies: [
        "Proxy",
        "DIRECT",
        "REJECT"
      ],
      "include-all": true,
      icon: "https://fastly.jsdelivr.net/gh/clash-verge-rev/clash-verge-rev.github.io@main/docs/assets/icons/fish.svg",
    },
  ];

  // 覆盖原配置中的规则
  config["rule-providers"] = ruleProviders;
  config["rules"] = rules;

  // 返回修改后的配置
  return config;
}