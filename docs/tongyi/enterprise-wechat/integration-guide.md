# 在企业微信中添加AI助手

## 4\. 配置企业微信应用

有了 Webhook 地址后，接下来您可以在企业微信应用中配置接收消息来回答用户问题了。

### 4.1 配置API接收消息

1. 访问企业微信应用列表。找到刚刚创建的应用，点击应用名称进入详情页面。
2. 在应用详情页面，找到接收消息卡片，点击**设置API接收**。
3. 在**API接收消息**页面，您可以参考下图完成配置，然后点击**保存**。  
   * **URL**填入上一步复制的 **WebhookUrl**。  
   如果之前未保存WebhookUrl，可访问AppFlow连接流页面，在**操作**列点击**webhookUrl**进行查看。  
   * **Token** 和 **EncodingAESKey** 填入上一步复制的值。  
   如果之前未保存，可访问AppFlow连接凭证页面，在**公共连接器** \> **企业微信**中，找到刚刚配置的凭证，点击**操作**列的**编辑**从凭证中获取。  
> 如果域名主体校验未通过，请参考域名主体校验未通过怎么办？进行处理。

### **4.2 配置企业可信IP** 

1. 在应用详情页面，在页面下方开发者接口找到**企业可信IP**卡片，点击**配置**。
2. 在企业可信IP对话框，粘贴复制的 IP 地址，然后点击**确定**。

### 4.3 测试应用

你可以在企业微信中搜索应用并发送消息，查看效果。

1. 在企业微信顶部搜索框搜索应用名称，点击应用进入聊天。
2. 与应用对话，进行交流互动。

## 5\. 为大模型问答应用增加私有知识

### **5.1 配置知识库**

接下来，我们可以尝试让大模型在面对客户问题时参考这份文档，以产出一个更准确的回答和建议。

假设您在一家售卖智能手机的公司工作。您的企业微信用户会有很多涉及智能手机相关的问题，如支持双卡双待、屏幕、电池容量、内存等信息。不同机型的详细配置清单参考：百炼系列手机产品介绍.docx。

1. **上传文件：**在百炼控制台的数据管理中的**非结构化数据**页签中点击**导入数据**，根据引导上传我们虚构的百炼系列手机产品介绍。
2. **建立索引：**进入知识索引，根据引导创建一个新的知识库，并选择刚才上传的文件，其他参数保持默认即可。知识库将为上一步骤中准备的文档建立索引，以便后续大模型回答时检索参考。
3. **引用知识：**完成知识库的创建后，可以返回我的应用进入到刚才创建的应用设置界面，打开**知识检索增强**开关、选择目标知识库，测试验证符合预期后点击**发布**。Prompt 中会被自动添加一段信息，以便大模型在后续回答时参考检索出来的信息。

### **5.2 检验效果**

有了参考知识，AI 应用就能准确回答您关于百炼手机的问题了。
