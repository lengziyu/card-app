# 个人中心 · 实用工具

U 卡对比与 H5、PC 共用独立后台 `https://card-admin.lengziyu.cn/u-card-opening-requirements` 的已发布配置。新增、编辑、下架和默认顺序由同一公开接口返回，费率与支付支持来自关联卡片。App 不保存独立对比列表；每次进入 U 卡对比、下拉刷新或从后台恢复时重新读取，不用旧记录补回空列表。邀请相关字段仍遵守本文件与 App 开发规范的展示边界。

Flutter 原生页面：`lib/features/tools`。入口无需登录，不读写用户的个人资料。
页面支持 H5 的同一组公开数据、后台开关、搜索筛选、资料详情及来源外链。

| 工具 | H5 数据来源 |
| --- | --- |
| 卡 BIN 查询 | `/api/runtime/admin-cards`（公开运行时内容）、`/api/bin-lookup/{6–8位前缀}` |
| U 卡对比 | `/api/u-card-opening-requirements` |
| 无需 KYC 卡 | `/api/no-kyc-cards`、`/api/no-kyc-cards/meta` |
| 地址证明 | `/api/address-proofs`、`/api/address-proofs/{slug}` |
| 境外手机卡 | `/api/international-sims`、`/api/international-sims/meta`、`/api/international-sims/{id}` |
| 接码平台 | `/api/sms-platforms`、`/api/sms-platforms/meta`、`/api/sms-platforms/{id}` |

使用现有 `ApiClient` 的站点配置，默认 `https://card.lengziyu.cn`。不调用管理接口。
免 KYC 卡、境外手机卡、接码平台依据 H5 的 meta 开关和数量显示；meta 失败显示重试，不伪装成空数据。
列表、详情失败均可重试；下拉刷新获取后台新数据。

## H5 展示结构

- BIN 默认选中 Bybit（无该卡时使用第一张），搜索下拉切换卡片，同页展示全部卡段；卡段资料使用双列排版，支持复制 6–8 位公开前缀及来源外链。
- U 卡使用开卡条件与支付支持矩阵，仅保留分类筛选，不显示搜索框；点击卡片展开核验资料或费用、支付说明，未知与有条件状态保持原始语义。
- 开卡条件遵循 H5 的单行五列矩阵，顶部筛选旁展示图例：绿色实心勾代表需要、灰色空心横线代表不需要、黄色问号代表待确认。卡片使用紧凑标题区、独立底栏及细分隔线；大字体或长译文横向滚动条件行，保持五列结构。
- 境外手机卡展示国家图片、产品和申请状态；接码平台展示品牌、域名、服务类型；地址证明展示封面、费用类型和适用地区数量，使用 H5 的图文网格结构。
- 支付标志来自 H5 `public/payment-icons` 与 `PaymentNetworkIcon.vue`；短信品牌图片路径来自 H5 `src/data/smsPlatformLogos.json`，只读取源文件。
- 目录网格在窄屏或大字体下自动减少列数；开卡条件始终保留五列。展示仍为 Flutter 原生组件。

## BIN 静态资料

H5 本身对未配置 BIN 的卡片使用 `src/data/cardBinRanges.ts`。App 的
`assets/tools/h5-card-bin-ranges.json` 来自该文件，不是另造的样例数据。
公开运行时接口返回的 `binRanges` 优先，包括运营明确配置的空数组。
该静态资源是同步时的快照，H5 文件变更后运行 `node tool/sync_h5_bin_ranges.cjs`
重新同步；脚本只读取相邻 H5 仓库，不改动 H5 文件。

## 内容与交互边界

- BIN 输入和请求限于前 6–8 位，不持久化或打印输入。
- 地址证明指南以原生 Markdown 展示，境外手机卡步骤以原生组件展示；不使用 WebView。
- 教程链接只允许 HTTP/HTTPS。工具接口未提供 App 邀请审核开关，不展示邀请码、邀请奖励或推广追踪参数。
- 外链由系统浏览器打开，App 不收集第三方申请资料，不代办或提交申请。
- 详情保留核验状态、来源及时间；来源暂不可用时显示 H5 已保存资料的提示。
- 顶部返回、Android 返回和边缘返回会先关闭选择器或展开资料，再退回列表、工具首页、个人中心。
