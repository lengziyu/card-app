# Web 前台到 Flutter 迁移矩阵

> 核对日期：2026-07-17  
> 参考项目：`card.lengziyu.cn`  
> 范围：用户前台，不包含 `/admin/**` 管理后台

| Web 路由 | Flutter 对应实现 | 页面状态 | 数据状态 |
| --- | --- | --- | --- |
| `/cards` | 首页卡片堆叠 | 已实现 | 本地数据 |
| `/market` | 市场列表、筛选、刷新状态 | 已实现 | 本地数据 |
| `/market/search` | 市场搜索 | 已实现 | 本地数据 |
| `/add` | 添加卡片 | 已实现 | 本地状态 |
| `/add/search` | 搜索添加 | 已实现 | 本地状态 |
| `/ranking` | 排行、趋势、指标、文章四标签 | 已实现 | 本地演示数据 |
| `/articles/:slug` | 文章详情、相关卡片、点赞收藏状态 | 已实现 | 本地演示内容 |
| `/card/:id` | 卡片详情与原生卡面动效 | 已实现 | 本地数据 |
| `/card/:id/correction` | 信息纠错表单 | 已实现 | UI-only，不提交 |
| `/login` | 登录表单 | 已实现 | UI-only，不认证 |
| `/register` | 注册表单 | 已实现 | UI-only，不认证 |
| `/profile` | 游客个人中心与完整菜单 | 已实现 | 本地状态 |
| `/profile/cards` | 我的卡片 | 已实现 | 本地状态 |
| `/profile/services` | 订阅与服务说明 | 已实现 | 静态说明 |
| `/profile/favorites` | 卡片/文章收藏标签 | 已实现 | 本地演示状态 |
| `/profile/history` | 浏览记录 | 已实现 | 本地演示状态 |
| `/profile/settings` | 卡片高度与账号状态设置 | 已实现 | 本地预览状态 |
| `/profile/language` | 中英语言选择 | 已实现 | UI 状态，英文文案待补齐 |
| `/profile/help` | 帮助中心 | 已实现 | 静态内容 |
| `/profile/about` | 关于与隐私定位 | 已实现 | 静态内容 |
| `/profile/recommend` | 推荐卡片表单 | 已实现 | UI-only，不提交 |
| `/profile/notifications` | 反馈/留言消息页 | 已实现 | UI-only，无远程消息 |
| `/profile/message` | 在线留言表单 | 已实现 | UI-only，不提交 |

## 尚未完成的生产能力

页面级迁移完成不代表 Web 功能与线上数据已经完整迁移。以下能力继续保持关闭：

- 真实注册、登录、Token 存储和跨设备同步；
- 线上卡片目录、排行、指标与文章 API；
- 推荐、纠错、留言和反馈消息提交；
- 完整英文文案及运行时语言切换；
- Web 管理后台。

正式启用前必须分别完成接口安全、隐私、错误状态、离线行为与数据来源审查。
