# Grafana: 如何在 UI 中使用 CSS 隱藏 Y-axis 單位標籤

## 方法 1: 使用 HTML Panel 添加自定義 CSS（推薦）

### 步驟 1: 在 Dashboard 中添加 HTML Panel

1. 進入 Dashboard 編輯模式
2. 點擊右上角的 **"Add panel"** → **"Add visualization"**
3. 選擇 **"HTML"** 或 **"Text"** panel 類型

### 步驟 2: 添加自定義 CSS

在 HTML panel 中添加以下 CSS 代碼：

```html
<style>
/* Hide y-axis unit labels in Network Traffic panel (Panel ID: 12) */
#panel-12 .uplot .u-legend,
#panel-12 .axis-label .u-value {
  display: none !important;
}

/* Alternative: Hide all unit labels in y-axis for specific panel */
[data-panel-id="12"] .uplot .u-legend .u-value,
[data-panel-id="12"] .axis-y .u-value {
  display: none !important;
}

/* Hide y-axis unit text specifically */
#panel-12 .uplot-wrap .u-axis-y .u-value,
#panel-12 .uplot-wrap .axis-label span[data-unit] {
  display: none !important;
}

/* Most targeted: Hide only the unit suffix in y-axis ticks */
#panel-12 .uplot .u-axis-y .u-value:after {
  content: "" !important;
  display: none !important;
}
</style>

<div style="display: none;">
  <!-- This panel is only for CSS injection -->
</div>
```

### 步驟 3: 配置 Panel

1. 設置 Panel 大小為最小（例如 1x1 grid）
2. 將 Panel 放置在角落或隱藏位置
3. 在 Panel options 中設置標題為空或 "CSS Injection"
4. 可以設置 Panel 為透明，使其不可見

## 方法 2: 通過 Dashboard 設置添加全局 CSS

### 步驟 1: 進入 Dashboard Settings

1. 點擊 Dashboard 右上角的 **齒輪圖標** (Settings)
2. 選擇 **"Variables"** 或查看是否有 **"JSON Model"** 選項

### 步驟 2: 添加 Dashboard Link（帶有 CSS）

在 Dashboard JSON 中添加一個 `links` 條目，但這不是標準方法。

## 方法 3: 使用 Text Panel 注入 CSS（最簡單）

### 步驟 1: 添加 Text Panel

1. 在 Dashboard 中添加一個新的 **Text** panel
2. 設置為最小大小（如 1x1）

### 步驟 2: 添加 CSS 代碼

在 Text panel 的內容中選擇 **"HTML"** 模式，然後添加：

```html
<style>
/* Hide y-axis unit labels for Network Traffic panel */
.panel-container[data-panel-id="12"] .uplot .u-axis-y .u-value {
  font-size: 0 !important;
  visibility: hidden !important;
}

/* Hide unit suffixes in y-axis ticks */
.panel-container[data-panel-id="12"] .uplot .u-axis-y text {
  display: none !important;
}

/* More specific targeting */
[data-panel-id="12"] .axisLabel,
[data-panel-id="12"] .u-axis-y .u-value,
[data-panel-id="12"] .uplot .u-axis-y .u-value {
  display: none !important;
}
</style>
```

### 步驟 3: 隱藏 Panel 本身

1. 在 Panel options 中設置背景為透明
2. 設置邊框為無
3. 調整 Panel 大小到最小

## 方法 4: 直接在 Browser Console 中測試 CSS

### 步驟 1: 打開 Browser Developer Tools

1. 按 `F12` 或右鍵選擇 **"Inspect"**
2. 切換到 **Console** 標籤

### 步驟 2: 測試 CSS Selector

在 Console 中輸入以下代碼來測試和應用 CSS：

```javascript
// 測試找到 y-axis 單位標籤的選擇器
document.querySelectorAll('[data-panel-id="12"] .uplot .u-axis-y text').forEach(el => {
  console.log(el.textContent, el);
});

// 臨時隱藏單位標籤（用於測試）
const style = document.createElement('style');
style.textContent = `
  [data-panel-id="12"] .uplot .u-axis-y text:not(.u-title) {
    display: none !important;
  }
`;
document.head.appendChild(style);
```

### 步驟 3: 確認正確的 CSS Selector

根據測試結果，調整 CSS 選擇器，然後將其添加到 HTML Panel 中。

## 方法 5: 通過 Grafana Provisioning 添加自定義 CSS 文件

### 步驟 1: 創建自定義 CSS 文件

創建文件：`grafana/public/css/custom-dashboard.css`

```css
/* Hide y-axis unit labels for Network Traffic panel */
.panel-container[data-panel-id="12"] .uplot .u-axis-y .u-value,
.panel-container[data-panel-id="12"] .uplot .u-axis-y text {
  display: none !important;
}

/* Alternative selectors */
[data-panel-id="12"] .axisLabel,
[data-panel-id="12"] .u-axis-y text:after {
  content: "" !important;
  display: none !important;
}
```

### 步驟 2: 在 Grafana 配置中引用 CSS

在 `grafana.ini` 或通過 Docker volume 掛載的方式引入 CSS。

## 推薦方案：已在 Dashboard JSON 中添加 CSS Injection Panel

**已在 `overview.json` 中添加了一個隱藏的 Text panel (ID: 999) 用於注入 CSS。**

### 已實現的配置：

在 Dashboard JSON 中，Network Traffic panel (ID: 12) 之後添加了一個 Text panel，包含：
- **Panel ID**: 999
- **大小**: 1x1（最小，幾乎不可見）
- **位置**: x=23, y=8（在 Network Traffic panel 旁邊，不影響其他 panels）
- **透明**: true
- **內容**: CSS 代碼用於隱藏 Network Traffic panel 的 y-axis 單位標籤

### CSS 選擇器說明：

```css
/* 隱藏 y-axis 上的單位標籤，但不影響數字 */
[data-panel-id="12"] .uplot .u-axis-y text
```

**注意**：這個 CSS 可能會隱藏 y-axis 上的所有文字（包括數字和單位）。如果需要只隱藏單位而保留數字，可能需要使用更複雜的 JavaScript 或調整 CSS 選擇器。

### 如需調整：

如果 CSS 選擇器過於廣泛（隱藏了數字），可以在 Grafana UI 中編輯這個 Text panel：
1. 找到 Panel ID 999 的 Text panel
2. 進入編輯模式
3. 調整 CSS 選擇器以更精確地只隱藏單位部分

## 注意事項

1. **Panel ID**: 需要確認 Network Traffic panel 的實際 ID（當前是 12）
2. **選擇器穩定性**: Grafana 版本更新可能會改變 DOM 結構，CSS 選擇器可能需要調整
3. **測試**: 建議在測試環境中先驗證效果
4. **維護**: 如果 Panel ID 改變，需要同步更新 CSS 選擇器

## 驗證步驟

1. 應用 CSS 後，刷新 Dashboard
2. 檢查 y-axis 是否只顯示數字（如 "7" 而不是 "7 Mb/s"）
3. 確認數據格式化仍然正確（數值應該正確轉換，例如 Mb/s 級別的數據應該顯示正確的數值）
4. 確認圖表 layout 沒有改變

